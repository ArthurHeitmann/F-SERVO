// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../../../fileTypeUtils/dat/datExtractor.dart';
import '../../../fileTypeUtils/mcd/defaultFontKerningMap.dart';
import '../../../fileTypeUtils/mcd/fontAtlasGeneratorTypes.dart';
import '../../../fileTypeUtils/mcd/mcdIO.dart';
import '../../../fileTypeUtils/wta/wtaReader.dart';
import '../../../utils/Disposable.dart';
import '../../../utils/assetDirFinder.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../changesExporter.dart';
import '../../events/statusInfo.dart';
import '../../hasUuid.dart';
import '../../listNotifier.dart';
import '../../openFiles/openFilesManager.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class McdFileData extends OpenFileData {
  McdData? mcdData;

  McdFileData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.mcd, icon: Icons.subtitles);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    mcdData?.dispose();
    mcdData = await McdData.fromMcdFile(uuid, path);

    await super.load();
  }

  @override
  Future<void> save() async {
    await mcdData?.save();
    var datDir = dirname(path);
    changedDatFiles.add(datDir);
    await super.save();
  }

  @override
  void dispose() {
    mcdData?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = McdFileData(name.value, path);
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.mcdData = mcdData?.takeSnapshot() as McdData?;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as McdFileData;
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
    if (content.mcdData != null)
      mcdData?.restoreWith(content.mcdData as Undoable);
  }
}

abstract class _McdFilePart with HasUuid, Undoable implements Disposable {
  OpenFileId file;

  _McdFilePart(this.file);

  void onDataChanged() {
    var file = areasManager.fromId(this.file);
    file?.contentNotifier.notifyListeners();
    file?.setHasUnsavedChanges(true);
  }

  @override
  void dispose() {
  }
}

class McdFontSymbol {
  final int code;
  final String char;
  final int x;
  final int y;
  final int width;
  final int height;
  final int fontId;

  McdFontSymbol(this.code, this.char, this.x, this.y, this.width, this.height, this.fontId);
}

class UsedFontSymbol {
  final int code;
  final String char;
  final int fontId;

  UsedFontSymbol(this.code, this.char, this.fontId);

  UsedFontSymbol.withFont(UsedFontSymbol other, this.fontId) :
        code = other.code,
        char = other.char;

  @override
  bool operator ==(Object other) =>
      other is UsedFontSymbol &&
          code == other.code &&
          fontId == other.fontId;

  @override
  int get hashCode => Object.hash(code, fontId);

  @override
  String toString() => 'Sym($char, fontId: $fontId)';
}

class McdFont {
  late final int fontId;
  late final int fontWidth;
  late final int fontHeight;
  late final int fontBelow;
  late final Map<int, McdFontSymbol> supportedSymbols;

  McdFont(this.fontId, this.fontWidth, this.fontHeight, this.fontBelow, this.supportedSymbols);
}

class McdGlobalFont extends McdFont {
  final String atlasInfoPath;
  final String atlasTexturePath;

  McdGlobalFont(this.atlasInfoPath, this.atlasTexturePath, super.fontId, super.fontWidth, super.fontHeight, super.fontBelow, super.supportedSymbols);

  static Future<McdGlobalFont> fromInfoFile(String atlasInfoPath, String atlasTexturePath) async {
    var infoJson = jsonDecode(await File(atlasInfoPath).readAsString());
    var fontId = infoJson["id"];
    var fontWidth = infoJson["fontWidth"];
    var fontHeight = infoJson["fontHeight"];
    var fontBelow = infoJson["fontBelow"];
    var supportedSymbols = (infoJson["symbols"] as List)
        .map((e) => McdFontSymbol(
        e["code"], e["char"],
        e["x"].toInt(), e["y"].toInt(),
        e["width"], e["height"],
        fontId
    ))
        .map((e) => MapEntry(e.code, e));
    var supportedSymbolsMap = Map<int, McdFontSymbol>.fromEntries(supportedSymbols);
    return McdGlobalFont(atlasInfoPath, atlasTexturePath, fontId, fontWidth, fontHeight, fontBelow, supportedSymbolsMap);
  }
}

class McdLocalFont extends McdFont {
  McdLocalFont(super.fontId, super.fontWidth, super.fontHeight, super.fontBelow, super.supportedSymbols);

  static Future<McdLocalFont> fromMcdFile(McdFile mcd, int fontId) async {
    McdFileFont font = mcd.fonts.firstWhere((f) => f.id == fontId);
    List<McdFileSymbol> symbols = mcd.symbols.where((s) => s.fontId == fontId).toList();
    List<McdFileGlyph> glyphs = symbols.map((s) => mcd.glyphs[s.glyphId]).toList();
    int textWidth = 0;
    int textHeight = 0;
    if (symbols.isNotEmpty) {
      var firstGlyph = glyphs[0];
      var uvWidth = firstGlyph.u2 - firstGlyph.u1;
      var uvHeight = firstGlyph.v2 - firstGlyph.v1;
      var pixWidth = firstGlyph.width;
      var pixHeight = firstGlyph.height;
      textWidth = (pixWidth / uvWidth).round();
      textHeight = (pixHeight / uvHeight).round();
    }
    var supportedSymbolsList = List.generate(symbols.length, (i) => McdFontSymbol(
        symbols[i].charCode,
        symbols[i].char,
        (glyphs[i].u1 * textWidth).round(),
        (glyphs[i].v1 * textHeight).round(),
        glyphs[i].width.toInt(),
        glyphs[i].height.toInt(),
        fontId
    ));
    var supportedSymbols = Map<int, McdFontSymbol>
        .fromEntries(supportedSymbolsList.map((e) => MapEntry(e.code, e)));
    return McdLocalFont(fontId, font.width.toInt(), font.height.toInt(), font.below.toInt(), supportedSymbols);
  }

  McdLocalFont.zero() : super(0, 0, 4, -6, {});
}

class McdFontOverride with HasUuid implements Disposable {
  final ValueListNotifier<int> fontIds;
  final NumberProp heightScale;
  final StringProp fontPath;
  final NumberProp scale;
  final NumberProp letXPadding;
  final NumberProp letYPadding;
  final NumberProp xOffset;
  final NumberProp yOffset;
  final BoolProp isFallbackOnly;

  McdFontOverride(int firstFontId) :
    fontIds = ValueListNotifier([firstFontId], fileId: null),
    heightScale = NumberProp(1.0, false, fileId: null),
    fontPath = StringProp("", fileId: null),
    scale = NumberProp(1.0, false, fileId: null),
    letXPadding = NumberProp(0.0, true, fileId: null),
    letYPadding = NumberProp(0.0, true, fileId: null),
    xOffset = NumberProp(0.0, false, fileId: null),
    yOffset = NumberProp(0.0, false, fileId: null),
    isFallbackOnly = BoolProp(false, fileId: null);

  @override
  void dispose() {
    fontIds.dispose();
    scale.dispose();
    yOffset.dispose();
    fontPath.dispose();
    letXPadding.dispose();
    letYPadding.dispose();
    xOffset.dispose();
    heightScale.dispose();
    isFallbackOnly.dispose();
  }
}

class McdLine extends _McdFilePart {
  StringProp text;

  McdLine(super.file, this.text) {
    text.addListener(onDataChanged);
  }

  McdLine.fromMcd(super.file, McdFileLine mcdLine)
      : text = StringProp(mcdLine.toString(), fileId: file) {
    text.addListener(onDataChanged);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Set<UsedFontSymbol> getUsedSymbolCodes() {
    var charMatcher = RegExp(r"<[^>]+>|[^ ≡]");
    var symbols = charMatcher.allMatches(text.value)
        .map((m) => m.group(0)!)
        .where((s) => s.length == 1)
        .map((c) {
      var code = c != "…" ? c.codeUnitAt(0) : 0x80;
      return UsedFontSymbol(code, c, -1);
    })
        .toSet();
    return symbols;
  }

  List<McdFileLetter> toLetters(int fontId, List<McdFileSymbol> symbols, bool isFontOverriden) {
    var str = text.value;
    List<McdFileLetter> letters = [];
    for (var i = 0; i < str.length; i++) {
      int kerning = 0;
      var char = str[i];
      if (i > 0 && !isFontOverriden) {
        var prevChar = str[i - 1];
        var searchKey = (prevChar, char);
        var kerningLookup = defaultFontKerningMap[fontId]?[searchKey];
        if (kerningLookup != null)
          kerning = kerningLookup;
      }
      if (char == " ")
        letters.add(McdFileLetter(0x8001, kerning, const []));
      else if (char == "…")
        letters.add(McdFileLetter(0x80, 0, const []));
      else if (char == "≡")
        letters.add(McdFileLetter(0x8020, 9, const []));
      else if (char == "<" && i + 5 <= str.length && str.substring(i, i + 5) == "<Alt>") {
        letters.add(McdFileLetter(0x8020, 121, const []));
        i += 4;
      } else if (char == "<" && i + 11 <= str.length && str.substring(i, i + 11) == "<Special_0x")
        throw Exception("Special symbols are not supported");
      else {
        var charCode = char.codeUnitAt(0);
        final symbolIndex = symbols.indexWhere((s) => s.charCode == charCode && s.fontId == fontId);
        if (symbolIndex == -1)
          throw Exception("Unknown char: $char");
        letters.add(McdFileLetter(symbolIndex, kerning, symbols));
      }
    }
    return letters;
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = McdLine(file, text.takeSnapshot() as StringProp);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var line = snapshot as McdLine;
    text.restoreWith(line.text);
  }
}

class McdParagraph extends _McdFilePart {
  NumberProp fontId;
  ValueListNotifier<McdLine> lines;

  McdParagraph(super.file, this.fontId, this.lines) {
    fontId.addListener(onDataChanged);
    lines.addListener(onDataChanged);
  }

  McdParagraph.fromMcd(super.file, McdFileParagraph paragraph, List<McdLocalFont> fonts) :
    fontId = NumberProp(paragraph.fontId, true, fileId: file),
    lines = ValueListNotifier(
      paragraph.lines
        .map((l) => McdLine.fromMcd(file, l))
        .toList(),
      fileId: file
    ) {
    fontId.addListener(onDataChanged);
    lines.addListener(onDataChanged);
  }

  void addLine() {
    lines.add(McdLine(file, StringProp("", fileId: file)));
    areasManager.onFileIdUndoEvent(file);
  }

  void removeLine(int index) {
    lines.removeAt(index)
        .dispose();
    areasManager.onFileIdUndoEvent(file);
  }

  @override
  void dispose() {
    fontId.dispose();
    lines.dispose();
    super.dispose();
  }

  Set<UsedFontSymbol> getUsedSymbols() {
    Set<UsedFontSymbol> symbols = {};
    for (var line in lines) {
      var lineSymbols = line
          .getUsedSymbolCodes()
          .map((c) => UsedFontSymbol.withFont(c, fontId.value.toInt()));
      symbols.addAll(lineSymbols);
    }
    return symbols;
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = McdParagraph(
        file,
        fontId.takeSnapshot() as NumberProp,
        lines.takeSnapshot() as ValueListNotifier<McdLine>
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var paragraph = snapshot as McdParagraph;
    fontId.restoreWith(paragraph.fontId);
    lines.restoreWith(paragraph.lines);
  }
}

class McdEvent extends _McdFilePart {
  StringProp name;
  ValueListNotifier<McdParagraph> paragraphs;

  McdEvent(super.file, this.name, this.paragraphs) {
    name.addListener(onDataChanged);
    paragraphs.addListener(onDataChanged);
  }

  McdEvent.fromMcd(super.file, McdFileEvent event, List<McdLocalFont> fonts) :
    name = StringProp(event.name, fileId: file),
    paragraphs = ValueListNotifier(
      event.message.paragraphs
        .map((p) => McdParagraph.fromMcd(file, p, fonts))
        .toList(),
      fileId: file
    ) {
    name.addListener(onDataChanged);
    paragraphs.addListener(onDataChanged);
  }

  void addParagraph(int fontId) {
    paragraphs.add(McdParagraph(
      file,
      NumberProp(fontId, true, fileId: file),
      ValueListNotifier([], fileId: file)
    ));
    areasManager.onFileIdUndoEvent(file);
  }

  void removeParagraph(int index) {
    paragraphs.removeAt(index)
        .dispose();
    areasManager.onFileIdUndoEvent(file);
  }

  @override
  void dispose() {
    name.dispose();
    paragraphs.dispose();
    super.dispose();
  }

  Set<UsedFontSymbol> getUsedSymbols() {
    Set<UsedFontSymbol> symbols = {};
    for (var paragraph in paragraphs)
      symbols.addAll(paragraph.getUsedSymbols());
    return symbols;
  }

  int calcNameHash() {
    return crc32(name.value.toLowerCase()) & 0x7FFFFFFF;
  }

  @override
  Undoable takeSnapshot() {
    var snapshot =  McdEvent(
        file,
        name.takeSnapshot() as StringProp,
        paragraphs.takeSnapshot() as ValueListNotifier<McdParagraph>
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var event = snapshot as McdEvent;
    name.restoreWith(event.name);
    paragraphs.restoreWith(event.paragraphs);
  }
}

class McdData extends _McdFilePart {
  static Map<int, McdGlobalFont> availableFonts = {};
  static ValueListNotifier<McdFontOverride> fontOverrides = ValueListNotifier([], fileId: null);
  static NumberProp fontAtlasLetterSpacing = NumberProp(0, true, fileId: null);
  static ChangeNotifier fontChanges = ChangeNotifier();

  final StringProp? textureWtaPath;
  final StringProp? textureWtpPath;
  final int firstMsgSeqNum;
  ValueListNotifier<McdEvent> events;
  Map<int, McdLocalFont> usedFonts;

  McdData(super.file, this.textureWtaPath, this.textureWtpPath, this.usedFonts, this.firstMsgSeqNum, this.events) {
    events.addListener(onDataChanged);
  }

  static Future<String?> searchForTexFile(String initDir, String mcdName, String ext) async {
    String? texPath = join(initDir, mcdName + ext);

    if (initDir.endsWith(".dat") && ext == ".wtp") {
      var dttDir = "${initDir.substring(0, initDir.length - 4)}.dtt";
      texPath = join(dttDir, mcdName + ext);
      if (await File(texPath).exists())
        return texPath;
      var dttPath = join(dirname(dirname(dttDir)), basename(dttDir));
      if (!await File(dttPath).exists()) {
        showToast("Couldn't find DTT file");
        return null;
      }
      await extractDatFiles(dttPath);
      if (await File(texPath).exists())
        return texPath;
      return null;
    }

    if (await File(texPath).exists())
      return texPath;

    return null;
  }

  static Future<McdData> fromMcdFile(OpenFileId file, String mcdPath) async {
    var datDir = dirname(mcdPath);
    var mcdName = basenameWithoutExtension(mcdPath);
    String? wtpPath = await searchForTexFile(datDir, mcdName, ".wtp");
    String? wtaPath = await searchForTexFile(datDir, mcdName, ".wta");

    var mcd = await McdFile.fromFile(mcdPath);
    mcd.events.sort((a, b) => a.msgId - b.msgId);

    var usedFonts = await Future.wait(
        mcd.fonts.map((f) => McdLocalFont.fromMcdFile(mcd, f.id))
    );

    var events = mcd.events.map((e) => McdEvent.fromMcd(file, e, usedFonts)).toList();

    if (availableFonts.isEmpty)
      await loadAvailableFonts();

    return McdData(
        file,
        wtaPath != null ? StringProp(wtaPath, fileId: file) : null,
        wtpPath != null ? StringProp(wtpPath, fileId: file) : null,
        {for (var f in usedFonts) f.fontId: f},
        mcd.messages.first.seqNumber,
        ValueListNotifier<McdEvent>(events, fileId: file)
    );
  }

  @override
  void dispose() {
    textureWtaPath?.dispose();
    textureWtpPath?.dispose();
    events.dispose();
    super.dispose();
  }

  static Future<void> loadAvailableFonts() async {
    if (!await hasMcdFonts()) {
      showToast("No MCD font assets found");
      return;
    }
    var fontsAssetsDir = join(assetsDir!, "mcdFonts");
    for (var fontId in fontIds) {
      var fontDir = join(fontsAssetsDir, fontId);
      var atlasInfoPath = join(fontDir, "_atlas.json");
      var atlasTexturePath = join(fontDir, "_atlas.png");
      var font = await McdGlobalFont.fromInfoFile(
          atlasInfoPath,
          atlasTexturePath
      );
      availableFonts[font.fontId] = font;
    }
  }

  void addEvent([String suffix = ""]) {
    events.add(McdEvent(
        file,
        StringProp("NEW_EVENT_NAME${suffix.isNotEmpty ? "_$suffix" : ""}", fileId: file),
        ValueListNotifier([], fileId: file)
    ));
    areasManager.onFileIdUndoEvent(file);
  }

  void removeEvent(int index) {
    events.removeAt(index)
        .dispose();
    areasManager.onFileIdUndoEvent(file);
  }

  static void addFontOverride() {
    var overriddenFontIds = fontOverrides
        .expand((fo) => fo.fontIds)
        .toSet();
    var nextFontId = availableFonts.keys
        .firstWhere((fId) =>
    !overriddenFontIds.contains(fId), orElse: () => -1);
    if (nextFontId == -1) {
      showToast("No more fonts to override");
      return;
    }
    fontOverrides.add(McdFontOverride(nextFontId,));
  }

  static void removeFontOverride(int index) {
    fontOverrides.removeAt(index)
        .dispose();
  }

  Future<void> save() async {
    if (availableFonts.isEmpty) {
      await loadAvailableFonts();
      if (availableFonts.isEmpty) {
        showToast("No MCD font assets found");
        return;
      }
    }
    if (textureWtaPath == null || textureWtpPath == null) {
      showToast("No wta or wtp files found");
      return;
    }
    // potentially update font texture
    if (getLocalFontUnsupportedSymbols().isNotEmpty) {
      if (getGlobalFontUnsupportedSymbols().length > 1) {
        showToast("Some fonts have unsupported symbols");
        print("Unsupported symbols: ${getGlobalFontUnsupportedSymbols()}");
        return;
      }
      if (!await hasMagickBins()) {
        showToast("No ImageMagick binaries found");
        return;
      }
      await updateFontsTexture();
    }
    else if (fontOverrides.isNotEmpty) {
      await updateFontsTexture();
    }

    var usedSymbols = getUsedSymbols().toList();
    usedSymbols.sort((a, b) {
      var fontCmp = a.fontId.compareTo(b.fontId);
      if (fontCmp != 0)
        return fontCmp;
      return a.code.compareTo(b.code);
    });

    // get export fonts
    List<int> usedFontIds = [0];
    for (var sym in usedSymbols) {
      if (!usedFontIds.contains(sym.fontId))
        usedFontIds.add(sym.fontId);
    }
    var exportFonts = usedFontIds
        .map((id) {
      if (id == 0)
        return McdLocalFont.zero();
      return usedFonts[id]!;
    })
        .map((f) {
      var fontOverrideRes = fontOverrides.where((fo) => fo.fontIds.contains(f.fontId));
      double heightScale = 1.0;
      if (fontOverrideRes.isNotEmpty) {
        var fontOverride = fontOverrideRes.first;
        heightScale = fontOverride.heightScale.value.toDouble();
      }
      return McdFileFont(
          f.fontId,
          f.fontWidth.toDouble(), f.fontHeight * heightScale,
          f.fontBelow.toDouble(), 0
      );
    })
        .toList();
    var exportFontMap = { for (var f in exportFonts) f.id: f };

    // glyphs
    var wta = await WtaFile.readFromFile(textureWtaPath!.value);
    var texId = wta.textureIdx!.first;
    var texSize = await getDdsFileSize(textureWtpPath!.value);
    var exportGlyphs = usedSymbols.map((usedSym) {
      var sym = usedFonts[usedSym.fontId]!.supportedSymbols[usedSym.code]!;
      return McdFileGlyph(
          texId,
          sym.x / texSize.width, sym.y / texSize.height,
          (sym.x + sym.width) / texSize.width, (sym.y + sym.height) / texSize.height,
          sym.width.toDouble(), sym.height.toDouble(),
          0, exportFontMap[sym.fontId]!.below, 0
      );
    }).toList();

    // symbols
    var exportSymbols = List.generate(usedSymbols.length, (i) {
      var sym = usedSymbols[i];
      return McdFileSymbol(sym.fontId, sym.code, i);
    });

    List<McdFileEvent> exportEvents = [];
    List<McdFileMessage> exportMessages = [];
    List<McdFileParagraph> exportParagraphs = [];
    List<McdFileLine> exportLines = [];
    List<McdFileLetterBase> exportLetters = [];

    // messages and events
    for (int i = 0; i < events.length; i++) {
      var event = events[i];
      var eventMsg = McdFileMessage(
        -1, event.paragraphs.length,
        firstMsgSeqNum + i, event.calcNameHash(),
        [],
      );
      exportMessages.add(eventMsg);

      var exportEvent = McdFileEvent(
          event.calcNameHash(), i,
          event.name.value,
          eventMsg
      );
      exportEvents.add(exportEvent);
    }

    // paragraphs, lines, letters
    for (int msgI = 0; msgI < exportMessages.length; msgI++) {
      for (int parI = 0; parI < events[msgI].paragraphs.length; parI++) {
        var paragraph = events[msgI].paragraphs[parI];
        List<McdFileLine> paragraphLines = [];
        var font = exportFontMap[paragraph.fontId.value.toInt()]!;
        var isFontOverriden = fontOverrides.any((fo) => fo.fontIds.contains(font.id) && !fo.isFallbackOnly.value);
        for (var line in paragraph.lines) {
          var lineLetters = line.toLetters(paragraph.fontId.value.toInt(), exportSymbols, isFontOverriden);
          exportLetters.addAll(lineLetters);
          var parLine = McdFileLine(
              -1, 0, lineLetters.length * 2 + 1, lineLetters.length * 2 + 1,
              font.below.toDouble(), 0, lineLetters,
              0x8000
          );
          exportLetters.add(McdFileLetterTerminator());
          exportLines.add(parLine);
          paragraphLines.add(parLine);
        }

        var par = McdFileParagraph(
            -1, paragraphLines.length,
            parI, 0,
            font.id,
            paragraphLines
        );
        exportParagraphs.add(par);
        exportMessages[msgI].paragraphs.add(par);
      }
    }

    var lettersStart = 0x28;
    var lettersEnd = lettersStart + exportLetters.fold<int>(0, (sum, let) => sum + let.byteSize);
    var afterLetterPadding = lettersEnd % 4 == 0 ? 4 : 2;
    var msgStart = lettersEnd + afterLetterPadding;
    var msgEnd = msgStart + exportMessages.length * 0x10;
    var parStart = msgEnd + 4;
    var parEnd = parStart + exportParagraphs.length * 0x14;
    var lineStart = parEnd + 4;
    var lineEnd = lineStart + exportLines.length * 0x18;
    var symStart = lineEnd + 4;
    var symEnd = symStart + exportSymbols.length * 0x8;
    var glyphStart = symEnd + 4;
    var glyphEnd = glyphStart + exportGlyphs.length * 0x28;
    var fontStart = glyphEnd + 4;
    var fontEnd = fontStart + exportFonts.length * 0x14;
    var eventsStart = fontEnd + 4;
    // var eventsEnd = eventsStart + exportEvents.length * 0x28;

    // update all offsets
    var curLetterOffset = lettersStart;
    var curParOffset = parStart;
    var curLineOffset = lineStart;
    for (var line in exportLines) {
      line.lettersOffset = curLetterOffset;
      var actualLetterCount = (line.lettersCount - 1) ~/ 2;
      curLetterOffset += actualLetterCount * 0x4 + 2;
    }
    for (var msg in exportMessages) {
      msg.paragraphsOffset = curParOffset;
      curParOffset += msg.paragraphsCount * 0x14;
    }
    for (var par in exportParagraphs) {
      par.linesOffset = curLineOffset;
      curLineOffset += par.linesCount * 0x18;
    }
    var header = McdFileHeader(
        msgStart, exportMessages.length,
        symStart, exportSymbols.length,
        glyphStart, exportGlyphs.length,
        fontStart, exportFonts.length,
        eventsStart, exportEvents.length
    );

    exportEvents.sort((a, b) => a.id.compareTo(b.id));

    var mcdFile = McdFile.fromParts(header, exportMessages, exportSymbols, exportGlyphs, exportFonts, exportEvents);
    var openFile = areasManager.fromId(file)!;
    await mcdFile.writeToFile(openFile.path);

    print("Saved MCD file");
    messageLog.add("Saved MCD file ${basename(openFile.path)}");
  }

  Future<void> updateFontsTexture() async {
    var newFonts = await makeFontsForSymbols(getUsedSymbols().toList());
    usedFonts.clear();
    usedFonts.addAll(newFonts);
    for (var event in events) {
      for (var paragraph in event.paragraphs) {
        paragraph.fontId.value = paragraph.fontId.value;
      }
    }
    fontChanges.notifyListeners();
  }

  Future<Map<int, McdLocalFont>> makeFontsForSymbols(List<UsedFontSymbol> symbols) async {
    if (!await hasMagickBins()) {
      showToast("No ImageMagick binaries found");
      throw Exception("No ImageMagick binaries found");
    }
    if (!await hasPython()) {
      showToast("No Python found");
      throw Exception("No Python found");
    }
    if (!await hasPipDeps()) {
      showToast("Couldn't install Python dependencies");
      throw Exception("Couldn't install Python dependencies");
    }

    var fontOverridesMap = {
      for (var fontOverride in fontOverrides)
        for (var fontId in fontOverride.fontIds)
          fontId: fontOverride
    };
    var allValidPaths = await Future.wait(
        fontOverrides.map((f) => File(f.fontPath.value).exists()));
    if (allValidPaths.any((valid) => !valid)) {
      showToast("One or more font paths are invalid");
      throw Exception("Some font override paths are invalid");
    }
    if (fontOverridesMap.keys.any((id) => !availableFonts.containsKey(id))) {
      showToast("One or more font overrides use an invalid font ID");
      throw Exception("One or more font overrides use an invalid font ID");
    }

    // generate cli json args
    List<String> srcTexPaths = [];
    Map<int, CliFontOptions> fonts = {};
    List<CliImgOperation> imgOperations = [];
    for (int i = 0; i < symbols.length; i++) {
      var symbol = symbols[i];
      if (fontOverridesMap.containsKey(symbol.fontId)) {
        if (!fonts.containsKey(symbol.fontId)) {
          var fontHeight = (availableFonts[symbol.fontId]!.fontHeight * fontOverridesMap[symbol.fontId]!.heightScale.value).toInt();
          var scaleFact = 44 / fontHeight;
          fonts[symbol.fontId] = CliFontOptions(
            fontOverridesMap[symbol.fontId]!.fontPath.value,
            fontHeight,
            fontOverridesMap[symbol.fontId]!.scale.value.toDouble(),
            (fontOverridesMap[symbol.fontId]!.letXPadding.value * scaleFact).toInt(),
            (fontOverridesMap[symbol.fontId]!.letYPadding.value * scaleFact).toInt(),
            fontOverridesMap[symbol.fontId]!.xOffset.value * scaleFact,
            fontOverridesMap[symbol.fontId]!.yOffset.value * scaleFact,
          );
        }
        CliImgOperationDrawFromTexture? drawTextureOperation;
        var fontSymbol = availableFonts[symbol.fontId]?.supportedSymbols[symbol.code];
        if (fontSymbol != null) {
          var globalTex = availableFonts[symbol.fontId]!;
          int texId = srcTexPaths.indexOf(globalTex.atlasTexturePath);
          if (texId == -1) {
            srcTexPaths.add(globalTex.atlasTexturePath);
            texId = srcTexPaths.length - 1;
          }
          drawTextureOperation = CliImgOperationDrawFromTexture(
            i, texId,
            fontSymbol.x, fontSymbol.y,
            fontSymbol.width, fontSymbol.height,
          );
        }
        var fontOverride = fontOverridesMap[symbol.fontId]!;
        if (fontOverride.isFallbackOnly.value && drawTextureOperation != null) {
          imgOperations.add(drawTextureOperation);
        } else {
          imgOperations.add(CliImgOperationDrawFromFont(
              i, symbol.char, symbol.fontId, drawTextureOperation
          ));
        }
      } else {
        var globalTex = availableFonts[symbol.fontId]!;
        int texId = srcTexPaths.indexOf(globalTex.atlasTexturePath);
        if (texId == -1) {
          srcTexPaths.add(globalTex.atlasTexturePath);
          texId = srcTexPaths.length - 1;
        }
        var fontSymbol = availableFonts[symbol.fontId]!.supportedSymbols[symbol.code]!;
        imgOperations.add(
            CliImgOperationDrawFromTexture(
              i, texId,
              fontSymbol.x, fontSymbol.y,
              fontSymbol.width, fontSymbol.height,
            )
        );
      }
    }

    var texPngPath = join(dirname(textureWtpPath!.value), "${basename(textureWtpPath!.value)}.png");
    var cliArgs = FontAtlasGenCliOptions(
        texPngPath, srcTexPaths,
        McdData.fontAtlasLetterSpacing.value.toInt(),
        256,
        fonts, imgOperations
    );
    var cliJson = jsonEncode(cliArgs.toJson());
    cliJson = base64Encode(utf8.encode(cliJson));

    // run cli tool
    var cliToolPath = join(assetsDir!, "FontAtlasGenerator", "__init__.py");
    var cliToolProcess = await Process.start(pythonCmd!, [cliToolPath]);
    cliToolProcess.stdin.writeln(cliJson);
    cliToolProcess.stdin.close();
    var stdout = cliToolProcess.stdout.transform(utf8.decoder).join();
    var stderr = cliToolProcess.stderr.transform(utf8.decoder).join();
    if (await cliToolProcess.exitCode != 0) {
      showToast("Font atlas generator failed");
      print(await stdout);
      print(await stderr);
      throw Exception("Font atlas generator failed for file $texPngPath");
    }
    // parse cli output
    FontAtlasGenResult atlasInfo;
    try {
      var atlasInfoJson = jsonDecode(await stdout);
      atlasInfo = FontAtlasGenResult.fromJson(atlasInfoJson);
    } catch (e) {
      showToast("Font atlas generator failed");
      print(e);
      print(await stdout);
      print(await stderr);
      throw Exception("Font atlas generator failed");
    }

    // generate fonts
    Map<int, List<Tuple2<UsedFontSymbol, FontAtlasGenSymbol>>> generatedSymbols = {};
    for (var genSym in atlasInfo.symbols.entries) {
      var usedSym = symbols[genSym.key];
      if (!generatedSymbols.containsKey(usedSym.fontId))
        generatedSymbols[usedSym.fontId] = [];
      generatedSymbols[usedSym.fontId]!.add(Tuple2(usedSym, genSym.value));
    }
    Map<int, McdLocalFont> exportFonts = {};
    for (var fontId in generatedSymbols.keys) {
      var font = availableFonts[fontId]!;
      var heightScale = fontOverridesMap[fontId]?.heightScale.value ?? 1.0;
      var fontHeight = (font.fontHeight * heightScale).toInt();
      Map<int, McdFontSymbol> exportSymbols = {};
      for (var genSym in generatedSymbols[fontId]!) {
        var usedSym = genSym.item1;
        var genSymInfo = genSym.item2;
        exportSymbols[usedSym.code] = McdFontSymbol(
            usedSym.code, usedSym.char,
            genSymInfo.x, genSymInfo.y,
            genSymInfo.width, genSymInfo.height,
            fontId
        );
      }
      var fontBelow = atlasInfo.fonts.containsKey(fontId)
          ? atlasInfo.fonts[fontId]!.baseline - fontHeight
          : font.fontBelow;
      fontBelow = min(fontBelow, 0);
      exportFonts[fontId] = McdLocalFont(
          fontId, font.fontWidth, fontHeight,
          fontBelow , exportSymbols
      );
    }

    // save texture
    var texDdsPath = "${texPngPath.substring(0, texPngPath.length - 3)}dds";
    var result = await Process.run(
        magickBinPath!,
        [texPngPath, "-define", "dds:mipmaps=0", texDdsPath]
    );
    if (result.exitCode != 0)
      throw Exception("Failed to convert texture to DDS: ${result.stderr}");
    await File(texDdsPath).rename(textureWtpPath!.value);
    var texFileSize = await File(textureWtpPath!.value).length();

    // update size in wta file
    var wta = await WtaFile.readFromFile(textureWtaPath!.value);
    wta.textureSizes[0] = texFileSize;
    await wta.writeToFile(textureWtaPath!.value);

    // export dtt
    var dttPath = dirname(textureWtpPath!.value);
    await exportDat(dttPath);

    print("Generated font texture with ${symbols.length} symbols");

    return exportFonts;
  }

  Set<UsedFontSymbol> getUsedSymbols() {
    Set<UsedFontSymbol> symbols = {};
    for (var event in events)
      symbols.addAll(event.getUsedSymbols());
    return symbols;
  }

  Set<UsedFontSymbol> getLocalFontUnsupportedSymbols() {
    var usedSymbols = getUsedSymbols();
    return usedSymbols
        .where((usedSym) => !usedFonts.containsKey(usedSym.fontId) || !usedFonts[usedSym.fontId]!
        .supportedSymbols
        .values
        .any((supSym) => supSym.code == usedSym.code))
        .toSet();
  }

  Set<UsedFontSymbol> getGlobalFontUnsupportedSymbols() {
    var usedSymbols = getUsedSymbols();
    return usedSymbols
        .where((usedSym) {
      var isValidFontId = !availableFonts.containsKey(usedSym.fontId);
      if (!isValidFontId)
        return false;
      var fontOverrideExists = fontOverrides.any((fo) => fo.fontIds.contains(usedSym.fontId));
      if (fontOverrideExists)
        return true;
      var isSupportedByAvailableFonts = availableFonts[usedSym.fontId]!
          .supportedSymbols
          .values
          .any((supSym) => supSym.code == usedSym.code);
      return !isSupportedByAvailableFonts;
    })
        .toSet();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = McdData(
      file,
      textureWtaPath?.takeSnapshot() as StringProp?,
      textureWtpPath?.takeSnapshot() as StringProp?,
      usedFonts.map((id, font) => MapEntry(id, font)),
      firstMsgSeqNum,
      events.takeSnapshot() as ValueListNotifier<McdEvent>,
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as McdData;
    if (textureWtaPath != null && data.textureWtaPath != null)
      textureWtaPath!.restoreWith(data.textureWtaPath!);
    if (textureWtpPath != null && data.textureWtpPath != null)
      textureWtpPath!.restoreWith(data.textureWtpPath!);
    usedFonts = data.usedFonts.map((id, font) => MapEntry(id, font));
    events.restoreWith(data.events);
  }
}
