
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';

import '../../fileTypeUtils/mcd/mcdReader.dart';
import '../../utils.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../nestedNotifier.dart';

class McdFontSymbol {
  final int code;
  final String char;
  final int x;
  final int y;
  final int width;
  final int height;

  McdFontSymbol(this.code, this.char, this.x, this.y, this.width, this.height);
}

class McdFont {
  late final int fontId;
  late final int fontWidth;
  late final int fontHeight;
  late final int fontBelow;
  late final List<McdFontSymbol> supportedSymbols;

  McdFont(this.fontId, this.fontWidth, this.fontHeight, this.fontBelow, this.supportedSymbols);
}

class McdGlobalFont extends McdFont {
  final String atlasInfoPath;
  final String atlasTexturePath;

  McdGlobalFont(this.atlasInfoPath, this.atlasTexturePath, super.fontId, super.fontWidth, super.fontHeight, super.fontBelow, super.supportedSymbols);

  static Future<McdFont> fromInfoFile(String atlasInfoPath, String atlasTexturePath) async {
    var infoJson = jsonDecode(await File(atlasInfoPath).readAsString());
    var fontId = infoJson["id"];
    var fontWidth = infoJson["fontWidth"];
    var fontHeight = infoJson["fontHeight"];
    var fontBelow = infoJson["fontBelow"];
    var supportedSymbols = (infoJson["supportedSymbols"] as List)
      .map((e) => McdFontSymbol(
        e["code"], e["char"], e["x"], e["y"], e["width"], e["height"])
      )
      .toList();
    return McdGlobalFont(atlasInfoPath, atlasTexturePath, fontId, fontWidth, fontHeight, fontBelow, supportedSymbols);
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
    var supportedSymbols = List.generate(symbols.length, (i) => McdFontSymbol(
      symbols[i].charCode,
      symbols[i].char,
      (glyphs[i].u1 * textWidth).round(),
      (glyphs[i].v1 * textHeight).round(),
      glyphs[i].width.toInt(),
      glyphs[i].height.toInt(),
    ));
    return McdLocalFont(fontId, textWidth, textHeight, font.below.toInt(), supportedSymbols);
  }
}

class McdLine with HasUuid {
  StringProp text;

  McdLine(this.text);

  McdLine.fromMcd(McdFileLine mcdLine) : text = StringProp(mcdLine.toString());

  void dispose() {
    text.dispose();
  }
}

class McdParagraph with HasUuid {
  NumberProp vPos;
  McdFont font;
  ValueNestedNotifier<McdLine> lines;

  McdParagraph(this.vPos, this.font, this.lines);
  
  McdParagraph.fromMcd(McdFileParagraph paragraph, List<McdLocalFont> fonts) : 
    vPos = NumberProp(paragraph.vPos, true),
    font = fonts.firstWhere((f) => f.fontId == paragraph.fontId),
    lines = ValueNestedNotifier(paragraph.lines.map((l) => McdLine.fromMcd(l)).toList());

  void addLine() {
    lines.add(McdLine(StringProp("")));
  }

  void removeLine(int index) {
    lines.removeAt(index)
      .dispose();
  }

  void dispose() {
    vPos.dispose();
    for (var line in lines)
      line.dispose();
    lines.dispose();
  }
}

class McdEvent with HasUuid {
  HexProp eventId;
  StringProp name;
  NumberProp msgSeqNum;
  ValueNestedNotifier<McdParagraph> paragraphs;

  McdEvent(this.eventId, this.name, this.msgSeqNum, this.paragraphs);

  McdEvent.fromMcd(McdFileEvent event, List<McdLocalFont> fonts) : 
    eventId = HexProp(event.id),
    name = StringProp(event.name),
    msgSeqNum = NumberProp(event.message.seqNumber, true),
    paragraphs = ValueNestedNotifier(
      event.message.paragraphs
        .map((p) => McdParagraph.fromMcd(p, fonts))
        .toList()
    );

  void addParagraph(McdLocalFont font) {
    paragraphs.add(McdParagraph(
      NumberProp(0, true),
      font,
      ValueNestedNotifier([])
    ));
  }

  void removeParagraph(int index) {
    paragraphs.removeAt(index)
      .dispose();
  }

  void dispose() {
    eventId.dispose();
    name.dispose();
    msgSeqNum.dispose();
    for (var paragraph in paragraphs)
      paragraph.dispose();
    paragraphs.dispose();
  }
}

class McdData {
  static ValueNestedNotifier<McdGlobalFont> availableFonts = ValueNestedNotifier([]);

  final StringProp? textureWtaPath;
  final StringProp? textureWtpPath;
  ValueNestedNotifier<McdLocalFont> usedFonts;
  ValueNestedNotifier<McdEvent> events;

  McdData(this.textureWtaPath, this.textureWtpPath, this.usedFonts, this.events);
  
  static Future<String?> searchTexFile(String initDir, String mcdName, String ext) async {
    String? texPath = join(initDir, mcdName + ext);

    if (initDir.endsWith(".dat") && ext == ".wtp") {
      var dttDir = "${initDir.substring(0, initDir.length - 4)}.dtt";
      texPath = join(dttDir, mcdName + ext);
      if (await File(texPath).exists())
        return texPath;
      texPath = join(initDir, mcdName + ext);
    }

    if (await File(texPath).exists())
      return texPath;

    return null;
  }

  static Future<McdData> fromMcdFile(String mcdPath) async {
    var datDir = dirname(mcdPath);
    var mcdName = basenameWithoutExtension(mcdPath);
    String? wtpPath = await searchTexFile(datDir, mcdName, ".wtp");
    String? wtaPath = await searchTexFile(datDir, mcdName, ".wta");

    var mcd = await McdFile.fromFile(mcdPath);

    var usedFonts = await Future.wait(
      mcd.fonts.map((f) => McdLocalFont.fromMcdFile(mcd, f.id))
    );

    var events = mcd.events.map((e) => McdEvent.fromMcd(e, usedFonts)).toList();

    return McdData(
      wtaPath != null ? StringProp(wtaPath) : null,
      wtpPath != null ? StringProp(wtpPath) : null,
      ValueNestedNotifier<McdLocalFont>(usedFonts),
      ValueNestedNotifier<McdEvent>(events)
    );
  }

  void addEvent() {
    events.add(McdEvent(
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

  void dispose() {
    textureWtaPath?.dispose();
    textureWtpPath?.dispose();
    usedFonts.dispose();
    for (var event in events)
      event.dispose();
    events.dispose();
  }
}
