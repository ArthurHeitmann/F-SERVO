// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../../../fileTypeUtils/dat/datExtractor.dart';
import '../../../fileTypeUtils/mcd/defaultFontKerningMap.dart';
import '../../../fileTypeUtils/textures/fontAtlasGenerator.dart';
import '../../../fileTypeUtils/textures/fontAtlasGeneratorTypes.dart';
import '../../../fileTypeUtils/mcd/mcdIO.dart';
import '../../../fileTypeUtils/textures/ddsConverter.dart';
import '../../../fileTypeUtils/textures/textureUtils.dart';
import '../../../fileTypeUtils/ttf/ttf.dart';
import '../../../fileTypeUtils/utils/ByteDataWrapper.dart';
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

abstract class KerningGetter {
  double? getKerning(String left, String right);
}

class MappedKerningGetter implements KerningGetter {
  final Map<(String, String), int> mapping;

  MappedKerningGetter(this.mapping);

  @override
  double? getKerning(String left, String right) {
    return mapping[(left, right)]?.toDouble();
  }
}

class TtKerningGetter implements KerningGetter {
  final TtfFile file;
  final int fontHeight;

  TtKerningGetter(this.file, this.fontHeight);

  @override
  double? getKerning(String left, String right) {
    if (left.isEmpty)
      return null;
    return file.getKerningScaled(left, right, fontHeight);
  }
}

class CombinedKerningGetter implements KerningGetter {
  final List<KerningGetter?> getters;

  CombinedKerningGetter(this.getters);

  @override
  double? getKerning(String left, String right) {
    for (var getter in getters) {
      var kerning = getter?.getKerning(left, right);
      if (kerning != null)
        return kerning;
    }
    return null;
  }
}

class McdFontSymbol {
  final int code;
  final String char;
  final Offset uv1;
  final Offset uv2;
  final Size renderedSize;
  final SizeInt textureSize;
  final int fontId;
  final KerningGetter kerning;

  McdFontSymbol(this.code, this.char, this.uv1,  this.uv2, this.renderedSize, this.textureSize, this.fontId, this.kerning);

  int getX() => (uv1.dx * textureSize.width).round();
  int getY() => (uv1.dy * textureSize.height).round();
  int getWidth() => ((uv2.dx - uv1.dx) * textureSize.width).round();
  int getHeight() => ((uv2.dy - uv1.dy) * textureSize.height).round();
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
  final int fontId;
  final double fontWidth;
  final double fontHeight;
  final double horizontalSpacing;
  final Map<int, McdFontSymbol> supportedSymbols;
  final Map<int, KerningGetter> symbolKernings;

  McdFont(this.fontId, this.fontWidth, this.fontHeight, this.horizontalSpacing, this.supportedSymbols) :
    symbolKernings = {
      for (var symbol in supportedSymbols.values)
        symbol.code: symbol.kerning
    };
}

class McdGlobalFont extends McdFont {
  final String atlasInfoPath;
  final String atlasTexturePath;

  McdGlobalFont(this.atlasInfoPath, this.atlasTexturePath, super.fontId, super.fontWidth, super.fontHeight, super.horizontalSpacing, super.supportedSymbols);

  static Future<McdGlobalFont> fromInfoFile(String atlasInfoPath, String atlasTexturePath) async {
    var infoJson = jsonDecode(await File(atlasInfoPath).readAsString());
    var fontId = infoJson["id"];
    var fontWidth = infoJson["fontWidth"].toDouble();
    var fontHeight = infoJson["fontHeight"].toDouble();
    var horizontalSpacing = infoJson["fontBelow"].toDouble();
    var textureSize = await getImageSize(atlasTexturePath);
    var supportedSymbols = (infoJson["symbols"] as List)
      .map((e) => McdFontSymbol(
        e["code"], e["char"],
        Offset(e["x"] / textureSize.width, e["y"] / textureSize.height),
        Offset((e["x"] + e["width"]) / textureSize.width, (e["y"] + e["height"]) / textureSize.height),
        Size(e["width"].toDouble(), e["height"].toDouble()),
        textureSize,
        fontId,
        MappedKerningGetter(defaultFontKerningMap[fontId] ?? {})
      ))
      .map((e) => MapEntry(e.code, e));
    var supportedSymbolsMap = Map<int, McdFontSymbol>.fromEntries(supportedSymbols);
    return McdGlobalFont(atlasInfoPath, atlasTexturePath, fontId, fontWidth, fontHeight, horizontalSpacing, supportedSymbolsMap);
  }
}

class McdLocalFont extends McdFont {
  Map<(String, String), int> kerningCache;

  McdLocalFont(super.fontId, super.fontWidth, super.fontHeight, super.horizontalSpacing, super.supportedSymbols, this.kerningCache);

  static Future<McdLocalFont> fromMcdFile(McdFile mcd, int fontId, SizeInt textureSize) async {
    Map<(String, String), Map<int, int>> kerningStats = {};
    var fontLetterLines = mcd.messages
      .map((m) => m.paragraphs)
      .expand((e) => e)
      .where((p) => p.fontId == fontId)
      .map((p) => p.lines)
      .expand((e) => e)
      .map((l) => l.letters);
    for (var line in fontLetterLines) {
      for (var i = 0; i < line.length; i++) {
        var prevLet = i > 0 ? line[i - 1] : null;
        var curLet = line[i];
        int kerning = curLet.kerning;
        var left = prevLet?.toString() ?? "";
        var right = curLet.toString();
        var key = (left, right);
        if (!kerningStats.containsKey(key))
          kerningStats[key] = {};
        var pairStats = kerningStats[key]!;
        if (!pairStats.containsKey(kerning))
          pairStats[kerning] = 0;
        pairStats[kerning] = pairStats[kerning]! + 1;
      }
    }
    Map<(String, String), int> kerningCache = {};
    for (var pairStats in kerningStats.entries) {
      int topKerningValue = pairStats.value.entries.first.key;
      int topKerningCount = pairStats.value.entries.first.value;
      for (var kerningStat in pairStats.value.entries) {
        if (kerningStat.value > topKerningCount) {
          topKerningValue = kerningStat.key;
          topKerningCount = kerningStat.value;
        }
      }
      kerningCache[pairStats.key] = topKerningValue;
    }


    McdFileFont font = mcd.fonts.firstWhere((f) => f.id == fontId);
    List<McdFileSymbol> symbols = mcd.symbols.where((s) => s.fontId == fontId).toList();
    List<McdFileGlyph> glyphs = symbols.map((s) => mcd.glyphs[s.glyphId]).toList();
    var supportedSymbolsList = List.generate(symbols.length, (i) => McdFontSymbol(
        symbols[i].charCode,
        symbols[i].char,
        Offset(glyphs[i].u1, glyphs[i].v1),
        Offset(glyphs[i].u2, glyphs[i].v2),
        Size(glyphs[i].width, glyphs[i].height),
        textureSize,
        fontId,
        MappedKerningGetter(kerningCache),
    ));
    var supportedSymbols = Map<int, McdFontSymbol>
        .fromEntries(supportedSymbolsList.map((e) => MapEntry(e.code, e)));

    return McdLocalFont(fontId, font.width, font.height, font.horizontalSpacing, supportedSymbols, kerningCache);
  }

  McdLocalFont.zero() : kerningCache = {}, super(0, 0, 4, -6, {});
}

class McdFontOverride with HasUuid implements Disposable {
  final ValueListNotifier<int> fontIds;
  final NumberProp heightScale;
  final StringProp fontPath;
  final NumberProp letXPadding;
  final NumberProp letYPadding;
  final NumberProp xOffset;
  final NumberProp yOffset;
  final NumberProp strokeWidth;
  final BoolProp isFallbackOnly;

  McdFontOverride(int firstFontId) :
    fontIds = ValueListNotifier([firstFontId], fileId: null),
    heightScale = NumberProp(1.0, false, fileId: null),
    fontPath = StringProp("", fileId: null),
    letXPadding = NumberProp(0.0, true, fileId: null),
    letYPadding = NumberProp(0.0, true, fileId: null),
    xOffset = NumberProp(0.0, false, fileId: null),
    yOffset = NumberProp(0.0, false, fileId: null),
    strokeWidth = NumberProp(0, true, fileId: null),
    isFallbackOnly = BoolProp(false, fileId: null);

  @override
  void dispose() {
    fontIds.dispose();
    yOffset.dispose();
    fontPath.dispose();
    letXPadding.dispose();
    letYPadding.dispose();
    xOffset.dispose();
    heightScale.dispose();
    strokeWidth.dispose();
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

  List<McdFileLetter> toLetters(int fontId, List<McdFileSymbol> symbols, Map<int, KerningGetter>? fontKernings) {
    var str = text.value;
    List<McdFileLetter> letters = [];
    for (var i = 0; i < str.length; i++) {
      var char = str[i];
      if (char == " ")
        letters.add(McdFileLetter(0x8001, fontId, const []));
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
        var prevChar = i > 0 ? str[i - 1] : "";
        var kerning = fontKernings?[charCode]?.getKerning(prevChar, char);
        letters.add(McdFileLetter(symbolIndex, kerning?.round() ?? 0, symbols));
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
  static NumberProp fontAtlasResolutionScale = NumberProp(1.0, false, fileId: null);
  static ChangeNotifier fontChanges = ChangeNotifier();

  final StringProp textureWtaPath;
  final StringProp textureWtpPath;
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
    if (wtaPath == null) {
      showToast("Unable to find related .wta file in .dat!");
      throw Exception("Unable to find related .wta file in .dat!");
    }
    if (wtpPath == null) {
      showToast("Unable to find related .wtp file in .dtt!");
      throw Exception("Unable to find related .wtp file in .dtt!");
    }
    SizeInt textureSize;
    try {
      textureSize = await getImageSize(wtpPath);
    }
    catch (e) {
      showToast("Unable to read ${basename(wtpPath)} file!");
      print(e);
      throw Exception("Unable to read $wtpPath");
    }

    var mcd = await McdFile.fromFile(mcdPath);
    mcd.events.sort((a, b) => a.msgId - b.msgId);

    var usedFonts = await Future.wait(
        mcd.fonts.map((f) => McdLocalFont.fromMcdFile(mcd, f.id, textureSize))
    );

    var events = mcd.events.map((e) => McdEvent.fromMcd(file, e, usedFonts)).toList();

    if (availableFonts.isEmpty)
      await loadAvailableFonts();

    return McdData(
        file,
        StringProp(wtaPath, fileId: file),
        StringProp(wtpPath, fileId: file),
        {for (var f in usedFonts) f.fontId: f},
        mcd.messages.first.seqNumber,
        ValueListNotifier<McdEvent>(events, fileId: file)
    );
  }

  @override
  void dispose() {
    textureWtaPath.dispose();
    textureWtpPath.dispose();
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
    // potentially update font texture
    if (getLocalFontUnsupportedSymbols().isNotEmpty) {
      await updateFontsTexture();
    }
    else if (fontOverrides.any((f) => !f.isFallbackOnly.value)) {
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
            f.fontWidth, f.fontHeight * heightScale,
            f.horizontalSpacing, 0
        );
      })
      .toList();
    var exportFontMap = { for (var f in exportFonts) f.id: f };

    // glyphs
    var wta = await WtaFile.readFromFile(textureWtaPath.value);
    var texId = wta.textureIdx.first;
    var exportGlyphs = usedSymbols.map((usedSym) {
      var font = usedFonts[usedSym.fontId]!;
      var sym = font.supportedSymbols[usedSym.code]!;
      return McdFileGlyph(
        texId,
        sym.uv1.dx, sym.uv1.dy,
        sym.uv2.dx, sym.uv2.dy,
        sym.renderedSize.width, sym.renderedSize.height,
        0, exportFontMap[sym.fontId]!.horizontalSpacing, 0
      );
    }).toList();

    // symbols
    var exportSymbols = usedSymbols
      .indexed
      .map((iSym) => McdFileSymbol(iSym.$2.fontId, iSym.$2.code, iSym.$1))
      .toList();

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
        var usedFont = usedFonts[paragraph.fontId.value];
        for (var line in paragraph.lines) {
          var lineLetters = line.toLetters(paragraph.fontId.value.toInt(), exportSymbols, usedFont?.symbolKernings);
          exportLetters.addAll(lineLetters);
          var parLine = McdFileLine(
              -1, 0, lineLetters.length * 2 + 1, lineLetters.length * 2 + 1,
              font.horizontalSpacing, 0, lineLetters,
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
      fontOverrides.map((f) => File(f.fontPath.value).exists())
    );
    if (allValidPaths.any((valid) => !valid)) {
      showToast("One or more font paths are invalid");
      throw Exception("Some font override paths are invalid");
    }
    if (fontOverridesMap.keys.any((id) => !availableFonts.containsKey(id))) {
      showToast("One or more font overrides use an invalid font ID");
      throw Exception("One or more font overrides use an invalid font ID");
    }

    // fonts that need to be fully regenerated
    // fonts outside this set can use the letters in the current mcd texture
    Set<int> staleFonts = {};
    for (var override in McdData.fontOverrides) {
      if (override.isFallbackOnly.value)
        continue;
      staleFonts.addAll(override.fontIds);
    }
    for (var symbol in symbols) {
      if (!usedFonts.containsKey(symbol.fontId)) {
        staleFonts.add(symbol.fontId);
        continue;
      }
      var currentFont = usedFonts[symbol.fontId]!;
      if (!currentFont.supportedSymbols.containsKey(symbol.code)) {
        staleFonts.add(symbol.fontId);
        continue;
      }
    }

    Map<int, TtfFile> ttfFiles = {};
    for (var font in fontOverrides) {
      TtfFile ttf;
      try {
        var bytes = await ByteDataWrapper.fromFile(font.fontPath.value);
        ttf = TtfFile.read(bytes);
      }
      catch (e) {
        messageLog.add("Unable to read font ${font.fontPath.value}");
        rethrow;
      }
      for (var fontId in font.fontIds) {
        ttfFiles[fontId] = ttf;
      }
    }

    List<UsedFontSymbol> unsupportedSymbols = [];
    Map<(int, int), KerningGetter> symbolKernings = {}; // key is (font id, symbol code)
    // generate cli json args
    List<String> srcTexPaths = [];
    Map<int, CliFontOptions> fonts = {};
    List<CliImgOperation> imgOperations = [];
    for (int i = 0; i < symbols.length; i++) {
      var symbol = symbols[i];
      var fontId = symbol.fontId;
      bool isInLocalFont = false;
      bool isInAtlas = false;
      bool isFallbackOnly = false;
      bool isOverridden = false;
      if (!staleFonts.contains(fontId) && usedFonts.containsKey(fontId)) {
        var localFont = usedFonts[fontId]!;
        isInLocalFont = localFont.supportedSymbols.containsKey(symbol.code);
      }
      if (availableFonts.containsKey(fontId)) {
        var defaultFont = availableFonts[fontId]!;
        isInAtlas = defaultFont.supportedSymbols.containsKey(symbol.code);
      }
      if (fontOverridesMap.containsKey(fontId)) {
        isFallbackOnly = fontOverridesMap[fontId]!.isFallbackOnly.value;
        isOverridden = !isFallbackOnly;
      }

      KerningGetter kerning;
      if (isInLocalFont) {
        var texPath = textureWtpPath.value;
        int texId = srcTexPaths.indexOf(texPath);
        if (texId == -1) {
          srcTexPaths.add(texPath);
          texId = srcTexPaths.length - 1;
        }
        var font = usedFonts[fontId]!;
        var fontSymbol = font.supportedSymbols[symbol.code]!;
        var fontHeight = font.fontHeight;
        var currentScaleFactor = (fontSymbol.getHeight() - fontHeight).abs() > 2
          ? fontSymbol.getHeight() / fontHeight
          : 1.0;
        var scaleFactor = McdData.fontAtlasResolutionScale.value.toDouble() / currentScaleFactor;
        imgOperations.add(
          CliImgOperationDrawFromTexture(
            i, texId,
            fontSymbol.getX(), fontSymbol.getY(),
            fontSymbol.getWidth(), fontSymbol.getHeight(),
            scaleFactor,
          )
        );
        kerning = fontSymbol.kerning;
      }
      else if (isInAtlas && !isOverridden) {
        var globalTex = availableFonts[fontId]!;
        int texId = srcTexPaths.indexOf(globalTex.atlasTexturePath);
        if (texId == -1) {
          srcTexPaths.add(globalTex.atlasTexturePath);
          texId = srcTexPaths.length - 1;
        }
        var fontSymbol = availableFonts[fontId]!.supportedSymbols[symbol.code]!;
        imgOperations.add(
          CliImgOperationDrawFromTexture(
            i, texId,
            fontSymbol.getX(), fontSymbol.getY(),
            fontSymbol.getWidth(), fontSymbol.getHeight(),
            McdData.fontAtlasResolutionScale.value.toDouble(),
          )
        );
        kerning = CombinedKerningGetter([
          usedFonts[fontId]?.supportedSymbols[symbol.code]?.kerning,
          MappedKerningGetter(defaultFontKerningMap[fontId]!),
        ]);
      }
      else if (isFallbackOnly || isOverridden) {
        var scaleFact = fontOverridesMap[fontId]!.heightScale.value * McdData.fontAtlasResolutionScale.value.toDouble();
        var fontHeight = (availableFonts[fontId]!.fontHeight * fontOverridesMap[fontId]!.heightScale.value).toInt();
        if (!fonts.containsKey(fontId)) {
          fonts[fontId] = CliFontOptions(
            fontOverridesMap[fontId]!.fontPath.value,
            fontHeight,
            (fontOverridesMap[fontId]!.letXPadding.value * scaleFact).toInt(),
            (fontOverridesMap[fontId]!.letYPadding.value * scaleFact).toInt(),
            fontOverridesMap[fontId]!.xOffset.value * scaleFact,
            fontOverridesMap[fontId]!.yOffset.value * scaleFact,
            McdData.fontAtlasResolutionScale.value.toDouble(),
            fontOverridesMap[fontId]!.strokeWidth.value.toInt(),
          );
        }
        imgOperations.add(CliImgOperationDrawFromFont(
          i, symbol.char, fontId, null
        ));
        kerning = TtKerningGetter(ttfFiles[fontId]!, fontHeight);
      }
      else {
        unsupportedSymbols.add(symbol);
        continue;
      }
      symbolKernings[(fontId, symbol.code)] = kerning;
    }

    if (unsupportedSymbols.isNotEmpty) {
      var missingChars = unsupportedSymbols.groupBy((c) => c.fontId);
      var missingCharsStr = missingChars.entries.map((s) => 
        "font ${s.key} has ${pluralStr(s.value.length, "unsupported symbol")}: "
        "${s.value.map((c) => "'${c.char}'")}"
      ).join("; ");
      showToast("Unable to generate texture: $missingCharsStr");
      throw Exception("Unable to generate texture: $missingCharsStr");
    }

    var texPngPath = join(dirname(textureWtpPath.value), "${basename(textureWtpPath.value)}.png");
    var cliArgs = FontAtlasGenCliOptions(
        texPngPath, srcTexPaths,
        McdData.fontAtlasLetterSpacing.value.toInt(),
        256,
        fonts, imgOperations
    );
    var atlasInfo = await runFontAtlasGenerator(cliArgs);

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
      var fontHeight = font.fontHeight * heightScale;
      Map<int, McdFontSymbol> exportSymbols = {};
      for (var genSym in generatedSymbols[fontId]!) {
        var usedSym = genSym.item1;
        var genSymInfo = genSym.item2;
        var symbolScaleFactor = genSymInfo.height / fontHeight;
        exportSymbols[usedSym.code] = McdFontSymbol(
          usedSym.code, usedSym.char,
          Offset(genSymInfo.x / atlasInfo.texSize, genSymInfo.y / atlasInfo.texSize),
          Offset((genSymInfo.x + genSymInfo.width) / atlasInfo.texSize, (genSymInfo.y + genSymInfo.height) / atlasInfo.texSize),
          Size(genSymInfo.width / symbolScaleFactor, genSymInfo.height / symbolScaleFactor),
          SizeInt(atlasInfo.texSize, atlasInfo.texSize),
          fontId,
          symbolKernings[(fontId, usedSym.code)]!
        );
      }
      var reusedFontKerning = usedFonts.containsKey(fontId) && (fontOverridesMap[fontId]?.isFallbackOnly.value ?? true);
      exportFonts[fontId] = McdLocalFont(
        fontId, font.fontWidth, fontHeight,
        font.horizontalSpacing, exportSymbols,
        reusedFontKerning ? usedFonts[fontId]!.kerningCache : {}
      );
    }

    // save texture
    var texDdsPath = "${texPngPath.substring(0, texPngPath.length - 3)}dds";
    await pngToDds(texDdsPath, texPngPath);
    await File(texDdsPath).rename(textureWtpPath.value);
    var texFileSize = await File(textureWtpPath.value).length();

    // update size in wta file
    var wta = await WtaFile.readFromFile(textureWtaPath.value);
    wta.textureSizes[0] = texFileSize;
    await wta.writeToFile(textureWtaPath.value);

    // export dtt
    var dttPath = dirname(textureWtpPath.value);
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
        var isValidFontId = availableFonts.containsKey(usedSym.fontId);
        if (!isValidFontId)
          return true;
        var fontOverrideExists = fontOverrides.any((fo) => fo.fontIds.contains(usedSym.fontId));
        if (fontOverrideExists)
          return false;
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
      textureWtaPath.takeSnapshot() as StringProp,
      textureWtpPath.takeSnapshot() as StringProp,
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
    textureWtaPath.restoreWith(data.textureWtaPath);
    textureWtpPath.restoreWith(data.textureWtpPath);
    usedFonts = data.usedFonts.map((id, font) => MapEntry(id, font));
    events.restoreWith(data.events);
  }
}
