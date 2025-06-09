// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:convert';

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
import '../../../fileTypeUtils/wta/wtbUtils.dart';
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
import '../../../fileSystem/FileSystem.dart';

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
    var infoJson = jsonDecode(await FS.i.readAsString(atlasInfoPath));
    var fontId = infoJson["id"];
    var fontWidth = infoJson["fontWidth"].toDouble();
    var fontHeight = infoJson["fontHeight"].toDouble();
    var horizontalSpacing = infoJson["fontHorizontal"].toDouble();
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

  static Future<McdLocalFont> fromMcdFile(McdFile mcd, int fontId, SizeInt textureSize, List<McdFileSymbol> symbolsMap) async {
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
        var left = prevLet?.encodeChar(prevLet.getSymbol(symbolsMap)) ?? "";
        var right = curLet.encodeChar(curLet.getSymbol(symbolsMap));
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
  final NumberProp rgbBlurSize;
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
    rgbBlurSize = NumberProp(0.0, false, fileId: null),
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
    rgbBlurSize.dispose();
    isFallbackOnly.dispose();
  }
}

class McdLine extends _McdFilePart {
  StringProp text;

  McdLine(super.file, this.text) {
    text.addListener(onDataChanged);
  }

  McdLine.fromMcd(super.file, McdFileLine mcdLine, int fontId, List<McdFileSymbol> symbolsMap)
      : text = StringProp(mcdLine.encodeAsString(fontId, symbolsMap), fileId: file) {
    text.addListener(onDataChanged);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  List<UsedFontSymbol> getUsedSymbolCodes(bool isMessCommon, int fontId) {
    List<UsedFontSymbol> symbols = [];
    var parsedChars = ParsedMcdCharBase.parseLine(text.value, fontId);
    for (var char in parsedChars) {
      switch (char) {
        case ParsedMcdChar _:
          if (!isMessCommon && _messCommonFontIds.contains(char.fontId)) {
            var messCommonLetter = McdFileLetter.tryMakeMessCommonLetter(char.char, char.fontId);
            if (messCommonLetter != null)
              break;
          }
          symbols.add(UsedFontSymbol(char.char.codeUnitAt(0), char.char, char.fontId));
          break;
        case ParsedMcdSpecialChar _:
          // special chars are not added to symbols
          break;
        default:
          throw Exception("Unexpected ParsedMcdChar type: $char");
      }
    }
    return symbols;
  }

  List<McdFileLetter> toLetters(int fontId, Iterable<McdFileSymbol> symbols, Map<int, KerningGetter>? fontKernings, bool isMessCommon) {
    List<McdFileLetter> letters = [];
    var parsedChars = ParsedMcdCharBase.parseLine(text.value, fontId);
    for (int i = 0; i < parsedChars.length; i++) {
      var char = parsedChars[i];
      switch (char) {
        case ParsedMcdChar _:
          if (!isMessCommon && _messCommonFontIds.contains(char.fontId)) {
            var messCommonLetter = McdFileLetter.tryMakeMessCommonLetter(char.char, char.fontId);
            if (messCommonLetter != null) {
              letters.add(messCommonLetter);
              break;
            }
          }
          var charCode = char.char.codeUnitAt(0);
          final glyphId = symbols
            .where((s) => s.charCode == charCode && s.fontId == char.fontId)
            .first
            .glyphId;
          if (glyphId == -1)
            throw Exception("Unknown char: $char");
          var prevChar = i > 0 ? parsedChars[i - 1].representation : null;
          var kerning = prevChar != null ? (fontKernings?[charCode]?.getKerning(prevChar, char.char)) : 0;
          letters.add(McdFileLetter(glyphId, kerning?.round() ?? 0));
          break;
        case ParsedMcdSpecialChar _:
          letters.add(McdFileLetter(char.code1, char.code2));
          break;
        default:
          throw Exception("Unexpected ParsedMcdChar type: $char");
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

  McdParagraph.fromMcd(super.file, McdFileParagraph paragraph, List<McdLocalFont> fonts, List<McdFileSymbol> symbolsMap) :
    fontId = NumberProp(paragraph.fontId, true, fileId: file),
    lines = ValueListNotifier(
      paragraph.lines
        .map((l) => McdLine.fromMcd(file, l, paragraph.fontId, symbolsMap))
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

  List<UsedFontSymbol> getUsedSymbols(bool isMessCommon) {
    List<UsedFontSymbol> symbols = [];
    for (var line in lines) {
      var lineSymbols = line.getUsedSymbolCodes(isMessCommon, fontId.value.toInt());
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
  
  Map toJson() {
    return {
      "fontId": fontId.value,
      "lines": lines.map((l) => l.text.value).toList(),
    };
  }

  McdParagraph.fromJson(super.file, Map json) :
    fontId = NumberProp(json["fontId"], true, fileId: file),
    lines = ValueListNotifier(
      (json["lines"] as List).map((l) => McdLine(file, StringProp(l, fileId: file))).toList(),
      fileId: file
    ) {
    fontId.addListener(onDataChanged);
    lines.addListener(onDataChanged);
  }
}

const _messCommonFontIds = [0, 6, 8];
const _messCommonEventIds = [0x1e8654f4, 0x78f054e, 0x708835d8];

class McdEvent extends _McdFilePart {
  // StringProp name;
  HexProp id;
  ValueListNotifier<McdParagraph> paragraphs;

  McdEvent(super.file, this.id, this.paragraphs) {
    id.addListener(onDataChanged);
    paragraphs.addListener(onDataChanged);
  }

  McdEvent.fromMcd(super.file, McdFileEvent event, List<McdLocalFont> fonts, List<McdFileSymbol> symbolsMap) :
    id = HexProp(event.id, fileId: file),
    paragraphs = ValueListNotifier(
      event.message.paragraphs
        .map((p) => McdParagraph.fromMcd(file, p, fonts, symbolsMap))
        .toList(),
      fileId: file
    ) {
    id.addListener(onDataChanged);
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
    id.dispose();
    paragraphs.dispose();
    super.dispose();
  }

  List<UsedFontSymbol> getUsedSymbols() {
    List<UsedFontSymbol> symbols = [];
    var isMessCommon = _messCommonEventIds.contains(id.value);
    for (var paragraph in paragraphs)
      symbols.addAll(paragraph.getUsedSymbols(isMessCommon));
    return symbols;
  }

  // int calcNameHash() {
  //   return crc32(name.value.toLowerCase()) & 0x7FFFFFFF;
  // }

  @override
  Undoable takeSnapshot() {
    var snapshot =  McdEvent(
      file,
      id.takeSnapshot() as HexProp,
      paragraphs.takeSnapshot() as ValueListNotifier<McdParagraph>
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var event = snapshot as McdEvent;
    id.restoreWith(event.id);
    paragraphs.restoreWith(event.paragraphs);
  }
  
  List toJson() {
    return paragraphs.map((p) => p.toJson()).toList();
  }
  
  McdEvent.fromJson(super.file, int id, List paragraphs) :
    // name = StringProp(name, fileId: file),
    id = HexProp(id, fileId: file),
    paragraphs = ValueListNotifier(
      paragraphs.map((p) => McdParagraph.fromJson(file, p)).toList(),
      fileId: file
    ) {
    this.id.addListener(onDataChanged);
    this.paragraphs.addListener(onDataChanged);
  }
}

class McdData extends _McdFilePart {
  static Map<int, McdGlobalFont> availableFonts = {};
  static ValueListNotifier<McdFontOverride> fontOverrides = ValueListNotifier([], fileId: null);
  static NumberProp fontAtlasLetterSpacing = NumberProp(0, true, fileId: null);
  static NumberProp fontAtlasResolutionScale = NumberProp(1.0, false, fileId: null);
  static ChangeNotifier fontChanges = ChangeNotifier();

  final StringProp textureWtbPath;
  final int firstMsgSeqNum;
  ValueListNotifier<McdEvent> events;
  Map<int, McdLocalFont> usedFonts;

  McdData(super.file, this.textureWtbPath, this.usedFonts, this.firstMsgSeqNum, this.events) {
    events.addListener(onDataChanged);
  }

  static Future<String?> searchForTexFile(String initDir, String mcdName, String ext) async {
    String? texPath = join(initDir, mcdName + ext);

    if (initDir.endsWith(".dat") && ext == ".wtb") {
      var dttDir = "${initDir.substring(0, initDir.length - 4)}.dtt";
      texPath = join(dttDir, mcdName + ext);
      if (await FS.i.existsFile(texPath))
        return texPath;
      var dttPath = join(dirname(dirname(dttDir)), basename(dttDir));
      if (!await FS.i.existsFile(dttPath)) {
        showToast("Couldn't find DTT file");
        return null;
      }
      await extractDatFiles(dttPath);
      if (await FS.i.existsFile(texPath))
        return texPath;
      return null;
    }

    if (await FS.i.existsFile(texPath))
      return texPath;

    return null;
  }

  static Future<McdData> fromMcdFile(OpenFileId file, String mcdPath) async {
    var datDir = dirname(mcdPath);
    var mcdName = basenameWithoutExtension(mcdPath);
    String? wtbPath = await searchForTexFile(datDir, mcdName, ".wtb");
    if (wtbPath == null) {
      showToast("Unable to find related .wtb file in .dtt!");
      throw Exception("Unable to find related .wta file in .dat!");
    }
    var wtbBytes = await ByteDataWrapper.fromFile(wtbPath);
    var wtb = WtaFile.read(wtbBytes);
    wtbBytes.position = wtb.textureOffsets[0];
    var textureBytes = wtbBytes.asUint8List(wtb.textureSizes[0]);
    SizeInt textureSize;
    try {
      textureSize = await getImageBytesSize(textureBytes);
    }
    catch (e, s) {
      showToast("Unable to read ${basename(wtbPath)} file!");
      print("$e\n$s");
      throw Exception("Unable to read $wtbPath");
    }

    var mcd = await McdFile.fromFile(mcdPath);
    mcd.events.sort((a, b) => a.msgId - b.msgId);
    var symbolsMap = mcd.makeSymbolsMap();

    var usedFonts = await Future.wait(
        mcd.fonts.map((f) => McdLocalFont.fromMcdFile(mcd, f.id, textureSize, symbolsMap))
    );

    var events = mcd.events.map((e) => McdEvent.fromMcd(file, e, usedFonts, symbolsMap)).toList();

    if (availableFonts.isEmpty)
      await loadAvailableFonts();

    return McdData(
        file,
        StringProp(wtbPath, fileId: file),
        {for (var f in usedFonts) f.fontId: f},
        mcd.messages.first.seqNumber,
        ValueListNotifier<McdEvent>(events, fileId: file)
    );
  }

  @override
  void dispose() {
    textureWtbPath.dispose();
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
        HexProp(randomId() & 0x7FFFFFFF, fileId: file),
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
      .firstWhere((fId) => !overriddenFontIds.contains(fId), orElse: () => -1);
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

    var usedSymbols = getUsedSymbols();

    // get export fonts
    List<int> usedFontIds = [];
    for (var sym in usedSymbols) {
      if (!usedFontIds.contains(sym.fontId))
        usedFontIds.add(sym.fontId);
    }
    var paragraphFontIds = events
      .expand((e) => e.paragraphs)
      .map((p) => p.fontId.value.toInt());
    for (var fontId in paragraphFontIds) {
      if (!usedFontIds.contains(fontId))
        usedFontIds.add(fontId);
    }
    var exportFonts = usedFontIds
      .map((id) {
        var font = usedFonts[id]!;
        var fontOverrideRes = fontOverrides.where((fo) => fo.fontIds.contains(font.fontId));
        double heightScale = 1.0;
        if (fontOverrideRes.isNotEmpty) {
          var fontOverride = fontOverrideRes.first;
          heightScale = fontOverride.heightScale.value.toDouble();
        }
        return McdFileFont(
            font.fontId,
            font.fontWidth, font.fontHeight * heightScale,
            font.horizontalSpacing, 0
        );
      })
      .toList();
    exportFonts.sort((a, b) => a.id.compareTo(b.id));
    var exportFontMap = { for (var f in exportFonts) f.id: f };

    // glyphs
    var texId = await WtbUtils.getSingleId(textureWtbPath.value);
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
    exportSymbols.sort((a, b) {
      var fontCmp = a.fontId.compareTo(b.fontId);
      if (fontCmp != 0)
        return fontCmp;
      return a.charCode.compareTo(b.charCode);
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
        firstMsgSeqNum + i, event.id.value,
        [],
      );
      exportMessages.add(eventMsg);

      var exportEvent = McdFileEvent(
          event.id.value, i,
          // event.name.value,
          eventMsg
      );
      exportEvents.add(exportEvent);
    }

    // paragraphs, lines, letters
    for (int msgI = 0; msgI < exportMessages.length; msgI++) {
      var isMessCommon = _messCommonEventIds.contains(exportEvents[msgI].id);
      for (int parI = 0; parI < events[msgI].paragraphs.length; parI++) {
        var paragraph = events[msgI].paragraphs[parI];
        List<McdFileLine> paragraphLines = [];
        var font = exportFontMap[paragraph.fontId.value.toInt()]!;
        var usedFont = usedFonts[paragraph.fontId.value];
        var totalNonControlCharacterCount = 0;
        for (var line in paragraph.lines) {
          var lineLetters = line.toLetters(paragraph.fontId.value.toInt(), exportSymbols, usedFont?.symbolKernings, isMessCommon);
          exportLetters.addAll(lineLetters);
          var nonControlCharacterCount = lineLetters.where((l) => !l.isControlChar).length;
          totalNonControlCharacterCount += nonControlCharacterCount;
          var parLine = McdFileLine(
              -1, 0,
              nonControlCharacterCount, lineLetters.length + 1,
              font.height.round(), font.horizontalSpacing.round(),
              lineLetters, 0x8000,
          );
          exportLetters.add(McdFileLetterTerminator());
          exportLines.add(parLine);
          paragraphLines.add(parLine);
        }

        var par = McdFileParagraph(
          -1, paragraphLines.length,
          parI, totalNonControlCharacterCount,
          font.id,
          paragraphLines
        );
        exportParagraphs.add(par);
        exportMessages[msgI].paragraphs.add(par);
      }
    }

    var lettersStart = 0x28;
    var lettersEnd = lettersStart + exportLetters.fold<int>(0, (sum, let) => sum + let.byteSize);
    var msgStart = alignTo(lettersEnd, 4);
    var msgEnd = msgStart + exportMessages.length * 0x10;
    var parLineStart = msgEnd;
    var parLineEnd = parLineStart + exportParagraphs.length * 0x14 + exportLines.length * 0x18;
    var symStart = parLineEnd;
    var symEnd = symStart + exportSymbols.length * 0x8;
    var glyphStart = symEnd;
    var glyphEnd = glyphStart + exportGlyphs.length * 0x28;
    var fontStart = glyphEnd;
    var fontEnd = fontStart + exportFonts.length * 0x14;
    var eventsStart = fontEnd;

    // update all offsets
    var curLetterOffset = lettersStart;
    var curParLineOffset = parLineStart;
    for (var line in exportLines) {
      line.lettersOffset = curLetterOffset;
      var lettersSize = line.letters.fold<int>(0, (sum, let) => sum + let.byteSize);
      curLetterOffset += lettersSize + 2;
    }
    for (var msg in exportMessages) {
      msg.paragraphsOffset = curParLineOffset;
      curParLineOffset += msg.paragraphsCount * 0x14;
      for (var par in msg.paragraphs) {
        par.linesOffset = curParLineOffset;
        curParLineOffset += par.linesCount * 0x18;
      }
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
    await backupFile(openFile.path);
    await mcdFile.writeToFile(openFile.path);

    print("Saved MCD file");
    messageLog.add("Saved MCD file ${basename(openFile.path)}");
  }

  Future<void> updateFontsTexture() async {
    Set<int> allUsedFontIds = {};
    for (var event in events) {
      for (var paragraph in event.paragraphs) {
        for (var line in paragraph.lines) {
          var parsed = ParsedMcdCharBase.parseLine(line.text.value, paragraph.fontId.value.toInt());
          for (var char in parsed) {
            if (char is ParsedMcdChar) {
              allUsedFontIds.add(char.fontId);
            }
          }
        }
      }
    }
    var newFonts = await makeFontsForSymbols(getUsedSymbols().toList(), allUsedFontIds);
    usedFonts.clear();
    usedFonts.addAll(newFonts);
    // idk why I added this
    for (var event in events) {
      for (var paragraph in event.paragraphs) {
        paragraph.fontId.value = paragraph.fontId.value;
      }
    }
    fontChanges.notifyListeners();
  }

  Future<Map<int, McdLocalFont>> makeFontsForSymbols(List<UsedFontSymbol> symbols, Set<int> allUsedFontIds) async {
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
      fontOverrides.map((f) => FS.i.existsFile(f.fontPath.value))
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
    String? localTexDdsTmp;
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
        int texId;
        if (localTexDdsTmp == null) {
          localTexDdsTmp = "${textureWtbPath.value}.png";
          await WtbUtils.extractSingle(textureWtbPath.value, localTexDdsTmp);
          srcTexPaths.add(localTexDdsTmp);
          texId = srcTexPaths.length - 1;
        }
        else {
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
            fontOverridesMap[fontId]!.rgbBlurSize.value.toDouble(),
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

    var texPngPath = join(dirname(textureWtbPath.value), "${basename(textureWtbPath.value)}.png");
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
    for (var fontId in allUsedFontIds) {
      var font = availableFonts[fontId]!;
      var heightScale = fontOverridesMap[fontId]?.heightScale.value ?? 1.0;
      var fontHeight = font.fontHeight * heightScale;
      Map<int, McdFontSymbol> exportSymbols = {};
      for (var genSym in generatedSymbols[fontId] ?? []) {
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

    // update wtb
    var texDdsPath = "${texPngPath.substring(0, texPngPath.length - 3)}dds";
    await texToDds(texPngPath, dstPath: texDdsPath);
    await WtbUtils.replaceSingle(textureWtbPath.value, texDdsPath);

    // export dat and dtt
    var dttPath = dirname(textureWtbPath.value);
    changedDatFiles.add(dttPath);
    var datPath = dirname(areasManager.fromId(file)!.path);
    changedDatFiles.add(datPath);

    // delete tmp
    if (localTexDdsTmp != null) {
      await FS.i.delete(localTexDdsTmp);
    }

    print("Generated font texture with ${symbols.length} symbols");

    return exportFonts;
  }

  List<UsedFontSymbol> getUsedSymbols() {
    List<UsedFontSymbol> symbols = [];
    for (var event in events)
      symbols.addAll(event.getUsedSymbols());
    return deduplicate(symbols);
  }

  Set<UsedFontSymbol> getLocalFontUnsupportedSymbols() {
    var usedSymbols = getUsedSymbols();
    return usedSymbols
      .where((usedSym) => !usedFonts.containsKey(usedSym.fontId) ||
        !usedFonts[usedSym.fontId]!
          .supportedSymbols
          .values
          .any((supSym) => supSym.code == usedSym.code)
      )
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

  Map toJson() {
    return {
      for (var event in events)
        "0x${event.id.value.toRadixString(16)}": event.toJson()
    };
  }

  void fromJson(Map json) {
    events.clear();
    for (var entry in json.entries) {
      events.add(McdEvent.fromJson(file, int.parse(entry.key.replaceAll("0x", ""), radix: 16), entry.value));
    }
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = McdData(
      file,
      textureWtbPath.takeSnapshot() as StringProp,
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
    textureWtbPath.restoreWith(data.textureWtbPath);
    usedFonts = data.usedFonts.map((id, font) => MapEntry(id, font));
    events.restoreWith(data.events);
  }
}
