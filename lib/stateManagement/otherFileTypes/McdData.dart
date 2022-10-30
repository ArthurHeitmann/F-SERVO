
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';

import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/mcd/mcdReader.dart';
import '../../fileTypeUtils/wta/wtaReader.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../nestedNotifier.dart';
import '../openFileTypes.dart';

abstract class _McdFilePart {
  McdFileData? file;

  _McdFilePart(this.file);

  void onDataChanged() {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    file?.contentNotifier.notifyListeners();
    file?.hasUnsavedChanges = true;
  }

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
  final McdFontSymbol? fontSymbol;

  UsedFontSymbol(this.code, this.char, this.fontId, this.fontSymbol);

  UsedFontSymbol.withFont(UsedFontSymbol other, this.fontId, this.fontSymbol) :
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

class McdLine extends _McdFilePart with HasUuid {
  StringProp text;

  McdLine(super.file, this.text) {
    text.addListener(onDataChanged);
  }

  McdLine.fromMcd(super.file, McdFileLine mcdLine)
    : text = StringProp(mcdLine.toString()) {
    text.addListener(onDataChanged);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Set<UsedFontSymbol> getUsedSymbolCodes(Map<int, McdFontSymbol> fontSymbols) {
    var charMatcher = RegExp(r"<[^>]+>|[^ ≡]");
    var symbols = charMatcher.allMatches(text.value)
      .map((m) => m.group(0)!)
      .map((c) {
        var code = c != "…" ? c.codeUnitAt(0) : 0x80;
        var sym = fontSymbols[code];
        return UsedFontSymbol(code, c, -1, sym);
      })
      .toSet();
    return symbols;
  }

  List<McdFileLetter> toLetters(int fontId, List<McdFileSymbol> symbols) {
    var str = text.value;
    List<McdFileLetter> letters = [];
    McdFileSymbol prevSymbol = symbols.first;
    for (var i = 0; i < str.length; i++) {
      var char = str[i];
      if (char == " ")
        letters.add(McdFileLetter(0x8001, prevSymbol.fontId, const []));
      else if (char == "…")
        letters.add(McdFileLetter(0x80, 0, const []));
      else if (char == "≡")
        letters.add(McdFileLetter(0x8020, 9, const []));
      else if (char == "<" && str.substring(i, i + 5) == "<Alt>")
        letters.add(McdFileLetter(0x8020, 121, const []));
      else if (char == "<" && str.substring(i, i + 11) == "<Special_0x")
        throw Exception("Special symbols are not supported");
      else {
        var charCode = char.codeUnitAt(0);
        final symbolIndex = symbols.indexWhere((s) => s.charCode == charCode && s.fontId == fontId);
        if (symbolIndex == -1)
          throw Exception("Unknown char: $char");
        letters.add(McdFileLetter(symbolIndex, 0, symbols));  
        prevSymbol = symbols[symbolIndex];
      }
    }
    return letters;
  }
}

class McdParagraph extends _McdFilePart with HasUuid {
  NumberProp vPos;
  McdFont font;
  ValueNestedNotifier<McdLine> lines;

  McdParagraph(super.file, this.vPos, this.font, this.lines) {
    vPos.addListener(onDataChanged);
    lines.addListener(onDataChanged);
  }
  
  McdParagraph.fromMcd(super.file, McdFileParagraph paragraph, List<McdLocalFont> fonts) : 
    vPos = NumberProp(paragraph.vPos, true),
    font = fonts.firstWhere((f) => f.fontId == paragraph.fontId),
    lines = ValueNestedNotifier(
      paragraph.lines
        .map((l) => McdLine.fromMcd(file, l))
        .toList()
    ) {
    vPos.addListener(onDataChanged);
    lines.addListener(onDataChanged);
  }

  void addLine() {
    lines.add(McdLine(file, StringProp("")));
  }

  void removeLine(int index) {
    lines.removeAt(index)
      .dispose();
  }

  @override
  void dispose() {
    vPos.dispose();
    for (var line in lines)
      line.dispose();
    lines.dispose();
    super.dispose();
  }

  Set<UsedFontSymbol> getUsedSymbols() {
    Set<UsedFontSymbol> symbols = {};
    for (var line in lines) {
      var lineSymbols = line
        .getUsedSymbolCodes(font.supportedSymbols)
        .map((c) => UsedFontSymbol.withFont(c, font.fontId, c.fontSymbol));
      symbols.addAll(lineSymbols);
    }
    return symbols;
  }
}

class McdEvent extends _McdFilePart with HasUuid {
  HexProp eventId;
  StringProp name;
  NumberProp msgSeqNum;
  ValueNestedNotifier<McdParagraph> paragraphs;

  McdEvent(super.file, this.eventId, this.name, this.msgSeqNum, this.paragraphs) {
    eventId.addListener(onDataChanged);
    name.addListener(onDataChanged);
    msgSeqNum.addListener(onDataChanged);
    paragraphs.addListener(onDataChanged);
  }

  McdEvent.fromMcd(super.file, McdFileEvent event, List<McdLocalFont> fonts) : 
    eventId = HexProp(event.id),
    name = StringProp(event.name),
    msgSeqNum = NumberProp(event.message.seqNumber, true),
    paragraphs = ValueNestedNotifier(
      event.message.paragraphs
        .map((p) => McdParagraph.fromMcd(file, p, fonts))
        .toList()
    ) {
    eventId.addListener(onDataChanged);
    name.addListener(onDataChanged);
    msgSeqNum.addListener(onDataChanged);
    paragraphs.addListener(onDataChanged);
  }

  void addParagraph(McdLocalFont font) {
    paragraphs.add(McdParagraph(
      file,
      NumberProp(0, true),
      font,
      ValueNestedNotifier([])
    ));
  }

  void removeParagraph(int index) {
    paragraphs.removeAt(index)
      .dispose();
  }

  @override
  void dispose() {
    eventId.dispose();
    name.dispose();
    msgSeqNum.dispose();
    for (var paragraph in paragraphs)
      paragraph.dispose();
    paragraphs.dispose();
    super.dispose();
  }

  Set<UsedFontSymbol> getUsedSymbols() {
    Set<UsedFontSymbol> symbols = {};
    for (var paragraph in paragraphs)
      symbols.addAll(paragraph.getUsedSymbols());
    return symbols;
  }
}

class McdData extends _McdFilePart {
  static ValueNestedNotifier<McdGlobalFont> availableFonts = ValueNestedNotifier([]);

  final StringProp? textureWtaPath;
  final StringProp? textureWtpPath;
  ValueNestedNotifier<McdLocalFont> usedFonts;
  ValueNestedNotifier<McdEvent> events;

  McdData(super.file, this.textureWtaPath, this.textureWtpPath, this.usedFonts, this.events) {
    usedFonts.addListener(onDataChanged);
    events.addListener(onDataChanged);
  }
  
  static Future<String?> searchTexFile(String initDir, String mcdName, String ext) async {
    String? texPath = join(initDir, mcdName + ext);

    if (initDir.endsWith(".dat") && ext == ".wtp") {
      var dttDir = "${initDir.substring(0, initDir.length - 4)}.dtt";
      texPath = join(dttDir, mcdName + ext);
      if (await File(texPath).exists())
        return texPath;
      var dttPath = join(dirname(dirname(dttDir)), basename(dttDir));
      await extractDatFiles(dttPath);
      if (await File(texPath).exists())
        return texPath;
      texPath = join(initDir, mcdName + ext);
    }

    if (await File(texPath).exists())
      return texPath;

    return null;
  }

  static Future<McdData> fromMcdFile(McdFileData? file, String mcdPath) async {
    var datDir = dirname(mcdPath);
    var mcdName = basenameWithoutExtension(mcdPath);
    String? wtpPath = await searchTexFile(datDir, mcdName, ".wtp");
    String? wtaPath = await searchTexFile(datDir, mcdName, ".wta");

    var mcd = await McdFile.fromFile(mcdPath);

    var usedFonts = await Future.wait(
      mcd.fonts.map((f) => McdLocalFont.fromMcdFile(mcd, f.id))
    );

    var events = mcd.events.map((e) => McdEvent.fromMcd(file, e, usedFonts)).toList();

    return McdData(
      file,
      wtaPath != null ? StringProp(wtaPath) : null,
      wtpPath != null ? StringProp(wtpPath) : null,
      ValueNestedNotifier<McdLocalFont>(usedFonts),
      ValueNestedNotifier<McdEvent>(events)
    );
  }

  @override
  void dispose() {
    textureWtaPath?.dispose();
    textureWtpPath?.dispose();
    usedFonts.dispose();
    for (var event in events)
      event.dispose();
    events.dispose();
    super.dispose();
  }

  Future<void> loadAvailableFonts() async {
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
      availableFonts.add(font);
    }
  }

  void addEvent() {
    events.add(McdEvent(
      file,
      HexProp(events.isNotEmpty ? events.last.eventId.value + 1 : randomId()),
      StringProp("NEW_EVENT_NAME"),
      NumberProp(getLastSeqNum() + 1, true),
      ValueNestedNotifier([])
    ));
  }

  void removeEvent(int index) {
    events.removeAt(index)
      .dispose();
  }

  int getLastSeqNum() {
    return events
      .map((e) => e.msgSeqNum.value as int)
      .reduce(max);
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
    if (getLocalFontUnsupportedSymbols().isNotEmpty) {
      showToast("Some symbols are not supported");
      print("Unsupported symbols: ${getLocalFontUnsupportedSymbols()}");
      return;
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
        return usedFonts.firstWhere((f) => f.fontId == id);
      })
      .map((f) => McdFileFont(
        f.fontId,
        f.fontWidth.toDouble(), f.fontHeight.toDouble(),
        f.fontBelow.toDouble(), 0)
      )
      .toList();
    var exportFontMap = { for (var f in exportFonts) f.id: f };
    
    // glyphs
    var wta = await WtaFile.readFromFile(textureWtaPath!.value);
    var texId = wta.textureIdx.first;
    var texSize = await getDdsFileSize(textureWtpPath!.value);
    var exportGlyphs = List.generate(usedSymbols.length, (i) {
      var sym = usedSymbols[i].fontSymbol;
      if (sym == null) {
        print("Symbol ${usedSymbols[i].code} not found");
        showToast("Symbol ${usedSymbols[i].code} not found");
        throw Exception("Symbol ${usedSymbols[i].code} not found");
      }
      return McdFileGlyph(
        texId,
        sym.x / texSize.width, sym.y / texSize.height,
        (sym.x + sym.width) / texSize.width, (sym.y + sym.height) / texSize.height,
        sym.width.toDouble(), sym.height.toDouble(),
        0, exportFontMap[sym.fontId]!.below, 0
      );
    });

    // symbols
    var exportSymbols = List.generate(usedSymbols.length, (i) {
      var sym = usedSymbols[i];
      return McdFileSymbol(
        sym.fontId,
        sym.code,
        i,
        exportFontMap[sym.fontId]!,
        exportGlyphs[i]
      );
    });

    List<McdFileEvent> exportEvents = [];
    List<McdFileMessage> exportMessages = [];
    List<McdFileParagraph> exportParagraphs = [];
    List<McdFileLine> exportLines = [];
    List<McdFileLetterBase> exportLetters = [];

    // messages and events
    var sortedEvents = events.toList();
    sortedEvents.sort((a, b) => a.msgSeqNum.value.compareTo(b.msgSeqNum.value));
    for (int i = 0; i < sortedEvents.length; i++) {
      var event = sortedEvents[i];
      var eventMsg = McdFileMessage(
        -1, event.paragraphs.length,
        event.msgSeqNum.value.toInt(), event.eventId.value,
        [],
      );
      exportMessages.add(eventMsg);

      var exportEvent = McdFileEvent(
        event.eventId.value, i,
        event.name.value,
        eventMsg
      );
      exportEvents.add(exportEvent);
    }

    // paragraphs, lines, letters
    for (int i = 0; i < exportMessages.length; i++) {
      for (var paragraph in sortedEvents[i].paragraphs) {
        List<McdFileLine> paragraphLines = [];
        for (var line in paragraph.lines) {
          var lineLetters = line.toLetters(paragraph.font.fontId, exportSymbols);
          exportLetters.addAll(lineLetters);
          var parLine = McdFileLine(
            -1, 0, lineLetters.length * 2 + 1, lineLetters.length * 2 + 1,
            paragraph.font.fontBelow.toDouble(), 0, lineLetters,
            0x8000
          );
          exportLetters.add(McdFileLetterTerminator());
          exportLines.add(parLine);
          paragraphLines.add(parLine);
        }

        var par = McdFileParagraph(
          -1, paragraphLines.length,
          paragraph.vPos.value.toInt(), 0,
          paragraph.font.fontId,
          paragraphLines
        );
        exportParagraphs.add(par);
        exportMessages[i].paragraphs.add(par);
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
    await mcdFile.writeToFile(file!.path);

    print("Saved MCD file");
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
      .where((usedSym) => !usedFonts
        .firstWhere((f) => f.fontId == usedSym.fontId)
        .supportedSymbols
        .values
        .any((supSym) => supSym.code == usedSym.code))
      .toSet();
  }

  Set<UsedFontSymbol> getGlobalFontUnsupportedSymbols() {
    var usedSymbols = getUsedSymbols();
    return usedSymbols
      .where((usedSym) => !availableFonts
        .firstWhere((f) => f.fontId == usedSym.fontId)
        .supportedSymbols
        .values
        .any((supSym) => supSym.code == usedSym.code))
      .toSet();
  }
}
