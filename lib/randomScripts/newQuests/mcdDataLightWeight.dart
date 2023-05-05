
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/dat/datRepacker.dart';
import '../../fileTypeUtils/mcd/fontAtlasGeneratorTypes.dart';
import '../../fileTypeUtils/mcd/mcdIO.dart';
import '../../fileTypeUtils/wta/wtaReader.dart';
import 'dirs.dart';
import 'utils.dart';

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

class McdLine {
  String text;

  McdLine(this.text);

  McdLine.fromMcd(McdFileLine mcdLine)
    : text = mcdLine.toString();

  Set<UsedFontSymbol> getUsedSymbolCodes() {
    var charMatcher = RegExp(r"<[^>]+>|[^ ≡]");
    var symbols = charMatcher.allMatches(text)
      .map((m) => m.group(0)!)
      .where((s) => s.length == 1)
      .map((c) {
        var code = c != "…" ? c.codeUnitAt(0) : 0x80;
        return UsedFontSymbol(code, c, -1);
      })
      .toSet();
    return symbols;
  }

  List<McdFileLetter> toLetters(int fontId, List<McdFileSymbol> symbols) {
    List<McdFileLetter> letters = [];
    McdFileSymbol prevSymbol = symbols.first;
    for (var i = 0; i < text.length; i++) {
      var char = text[i];
      if (char == " ")
        letters.add(McdFileLetter(0x8001, prevSymbol.fontId, const []));
      else if (char == "…")
        letters.add(McdFileLetter(0x80, 0, const []));
      else if (char == "≡")
        letters.add(McdFileLetter(0x8020, 9, const []));
      else if (char == "<" && i + 5 <= text.length && text.substring(i, i + 5) == "<Alt>") {
        letters.add(McdFileLetter(0x8020, 121, const []));
        i += 4;
      } else if (char == "<" && i + 11 <= text.length && text.substring(i, i + 11) == "<Special_0x")
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

class McdParagraph {
  int fontId;
  List<McdLine> lines;

  McdParagraph(this.fontId, this.lines);
  
  McdParagraph.fromMcd(McdFileParagraph paragraph, List<McdLocalFont> fonts) : 
    fontId = paragraph.fontId,
    lines = paragraph.lines
      .map((l) => McdLine.fromMcd(l))
      .toList();

  void addLine() {
    lines.add(McdLine(""));
  }

  void removeLine(int index) {
    lines.removeAt(index);
  }

  Set<UsedFontSymbol> getUsedSymbols() {
    Set<UsedFontSymbol> symbols = {};
    for (var line in lines) {
      var lineSymbols = line
        .getUsedSymbolCodes()
        .map((c) => UsedFontSymbol.withFont(c, fontId));
      symbols.addAll(lineSymbols);
    }
    return symbols;
  }
}

class McdEvent {
  String name;
  List<McdParagraph> paragraphs;

  McdEvent(this.name, this.paragraphs);

  McdEvent.fromMcd(McdFileEvent event, List<McdLocalFont> fonts) : 
    name = event.name,
    paragraphs = event.message.paragraphs
      .map((p) => McdParagraph.fromMcd(p, fonts))
      .toList();

  void addParagraph(int fontId) {
    paragraphs.add(McdParagraph(fontId, []));
  }

  void removeParagraph(int index) {
    paragraphs.removeAt(index);
  }

  Set<UsedFontSymbol> getUsedSymbols() {
    Set<UsedFontSymbol> symbols = {};
    for (var paragraph in paragraphs)
      symbols.addAll(paragraph.getUsedSymbols());
    return symbols;
  }

  int calcNameHash() {
    return crc32(name.toLowerCase()) & 0x7FFFFFFF;
  }
}

class McdData {
  static Map<int, McdGlobalFont> availableFonts = {};

  final String mcdPath;
  final String? textureWtaPath;
  final String? textureWtpPath;
  final int firstMsgSeqNum;
  List<McdEvent> events;
  Map<int, McdLocalFont> usedFonts;
  

  McdData(this.mcdPath, this.textureWtaPath, this.textureWtpPath, this.usedFonts, this.firstMsgSeqNum, this.events);
  
  static Future<String?> searchForTexFile(String initDir, String mcdName, String ext) async {
    String? texPath = join(initDir, mcdName + ext);

    if (initDir.endsWith(".dat") && ext == ".wtp") {
      var dttDir = "${initDir.substring(0, initDir.length - 4)}.dtt";
      texPath = join(dttDir, mcdName + ext);
      if (await File(texPath).exists())
        return texPath;
      var dttPath = join(dirname(dirname(dttDir)), basename(dttDir));
      if (!await File(dttPath).exists()) {
        print("Couldn't find DTT file");
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

  static Future<McdData> fromMcdFile(String mcdPath) async {
    var datDir = dirname(mcdPath);
    var mcdName = basenameWithoutExtension(mcdPath);
    String? wtpPath = await searchForTexFile(datDir, mcdName, ".wtp");
    String? wtaPath = await searchForTexFile(datDir, mcdName, ".wta");

    var mcd = await McdFile.fromFile(mcdPath);
    mcd.events.sort((a, b) => a.msgId - b.msgId);

    var usedFonts = await Future.wait(
      mcd.fonts.map((f) => McdLocalFont.fromMcdFile(mcd, f.id))
    );

    var events = mcd.events.map((e) => McdEvent.fromMcd(e, usedFonts)).toList();

    if (availableFonts.isEmpty)
      await loadAvailableFonts();

    return McdData(
      mcdPath,
      wtaPath,
      wtpPath,
      {for (var f in usedFonts) f.fontId: f},
      mcd.messages.first.seqNumber,
      events
    );
  }

  static Future<void> loadAvailableFonts() async {
    const fontIds = [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "19", "20", "35", "36", "37" ];
    for (var fontId in fontIds) {
      var fontDir = join(mcdFontsDir, fontId);
      var atlasInfoPath = join(fontDir, "_atlas.json");
      var atlasTexturePath = join(fontDir, "_atlas.png");
      var font = await McdGlobalFont.fromInfoFile(
        atlasInfoPath,
        atlasTexturePath
      );
      availableFonts[font.fontId] = font;
    }
  }

  McdEvent addEvent([String suffix = ""]) {
    var event = McdEvent(
      "NEW_EVENT_NAME${suffix.isNotEmpty ? "_$suffix" : ""}",
      []
    );
    events.add(event);
    return event;
  }

  void removeEvent(int index) {
    events.removeAt(index);
  }

  Future<void> save() async {
    if (availableFonts.isEmpty) {
      await loadAvailableFonts();
      if (availableFonts.isEmpty) {
        print("No MCD font assets found");
        return;
      }
    }
    if (textureWtaPath == null || textureWtpPath == null) {
      print("No wta or wtp files found");
      return;
    }
    // potentially update font texture
    if (getLocalFontUnsupportedSymbols().isNotEmpty) {
      if (getGlobalFontUnsupportedSymbols().length > 1) {
        print("Unsupported symbols: ${getGlobalFontUnsupportedSymbols()}");
        return;
      }
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
        double heightScale = 1.0;
        return McdFileFont(
          f.fontId,
          f.fontWidth.toDouble(), f.fontHeight * heightScale,
          f.fontBelow.toDouble(), 0
        );
      })
      .toList();
    var exportFontMap = { for (var f in exportFonts) f.id: f };
    
    // glyphs
    var wta = await WtaFile.readFromFile(textureWtaPath!);
    var texId = wta.textureIdx.first;
    var texSize = await getDdsFileSize(textureWtpPath!);
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
        event.name,
        eventMsg
      );
      exportEvents.add(exportEvent);
    }

    // paragraphs, lines, letters
    for (int msgI = 0; msgI < exportMessages.length; msgI++) {
      for (int parI = 0; parI < events[msgI].paragraphs.length; parI++) {
        var paragraph = events[msgI].paragraphs[parI];
        List<McdFileLine> paragraphLines = [];
        var font = exportFontMap[paragraph.fontId]!;
        for (var line in paragraph.lines) {
          var lineLetters = line.toLetters(paragraph.fontId, exportSymbols);
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
    await mcdFile.writeToFile(mcdPath);

    print("Saved MCD file");
  }

  Future<void> updateFontsTexture() async {
    var newFonts = await makeFontsForSymbols(getUsedSymbols().toList());
    usedFonts.clear();
    usedFonts.addAll(newFonts);
    for (var event in events) {
      for (var paragraph in event.paragraphs) {
        paragraph.fontId = paragraph.fontId;
      }
    }
  }
  
  Future<Map<int, McdLocalFont>> makeFontsForSymbols(List<UsedFontSymbol> symbols) async {
    // generate cli json args
    List<String> srcTexPaths = [];
    Map<int, CliFontOptions> fonts = {};
    List<CliImgOperation> imgOperations = [];
    for (int i = 0; i < symbols.length; i++) {
      var symbol = symbols[i];
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

    var texPngPath = join(dirname(textureWtpPath!), "${basename(textureWtpPath!)}.png");
    var cliArgs = FontAtlasGenCliOptions(
      texPngPath, srcTexPaths,
      0,
      256,
      fonts, imgOperations
    );
    var cliJson = jsonEncode(cliArgs.toJson());
    cliJson = base64Encode(utf8.encode(cliJson));

    // run cli tool
    var cliToolProcess = await Process.start(pythonCmd, [fontAtlasGeneratorPath]);
    cliToolProcess.stdin.writeln(cliJson);
    cliToolProcess.stdin.close();
    var stdout = cliToolProcess.stdout.transform(utf8.decoder).join();
    var stderr = cliToolProcess.stderr.transform(utf8.decoder).join();
    if (await cliToolProcess.exitCode != 0) {
      print("Font atlas generator failed");
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
      print("Font atlas generator failed");
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
      var heightScale = 1.0;
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
      magickBinPath,
      [texPngPath, "-define", "dds:mipmaps=0", texDdsPath]
    );
    if (result.exitCode != 0)
      throw Exception("Failed to convert texture to DDS: ${result.stderr}");
    await File(texDdsPath).rename(textureWtpPath!);
    var texFileSize = await File(textureWtpPath!).length();

    // update size in wta file
    var wta = await WtaFile.readFromFile(textureWtaPath!);
    wta.textureSizes[0] = texFileSize;
    await wta.writeToFile(textureWtaPath!);

    // export dtt
    var dttPath = dirname(textureWtpPath!);
    var dttName = basename(dttPath);
    var exportPath = join(exportDir, getDatFolder(dttName), dttName);
    await repackDat(dttPath, exportPath);

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
      .where((usedSym) => !availableFonts.containsKey(usedSym.fontId) || !availableFonts[usedSym.fontId]!
        .supportedSymbols
        .values
        .any((supSym) => supSym.code == usedSym.code))
      .toSet();
  }
}
