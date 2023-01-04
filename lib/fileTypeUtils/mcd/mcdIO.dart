
import 'dart:io';

import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';

class McdFileHeader {
  final int messagesOffset;
  final int messagesCount;
  final int symbolsOffset;
  final int symbolsCount;
  final int glyphsOffset;
  final int glyphsCount;
  final int fontsOffset;
  final int fontsCount;
  final int eventsOffset;
  final int eventsCount;

  McdFileHeader(this.messagesOffset, this.messagesCount, this.symbolsOffset,
      this.symbolsCount, this.glyphsOffset, this.glyphsCount, this.fontsOffset,
      this.fontsCount, this.eventsOffset, this.eventsCount);
  
  McdFileHeader.read(ByteDataWrapper bytes) :
    messagesOffset = bytes.readUint32(),
    messagesCount = bytes.readUint32(),
    symbolsOffset = bytes.readUint32(),
    symbolsCount = bytes.readUint32(),
    glyphsOffset = bytes.readUint32(),
    glyphsCount = bytes.readUint32(),
    fontsOffset = bytes.readUint32(),
    fontsCount = bytes.readUint32(),
    eventsOffset = bytes.readUint32(),
    eventsCount = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(messagesOffset);
    bytes.writeUint32(messagesCount);
    bytes.writeUint32(symbolsOffset);
    bytes.writeUint32(symbolsCount);
    bytes.writeUint32(glyphsOffset);
    bytes.writeUint32(glyphsCount);
    bytes.writeUint32(fontsOffset);
    bytes.writeUint32(fontsCount);
    bytes.writeUint32(eventsOffset);
    bytes.writeUint32(eventsCount);
  }
}

class McdFileSymbol {
  final int fontId;
  final int charCode;
  late final String char;
  final int glyphId;

  McdFileSymbol(this.fontId, this.charCode, this.glyphId) :
    char = String.fromCharCode(charCode);
  
  McdFileSymbol.read(ByteDataWrapper bytes, List<McdFileFont> fonts, List<McdFileGlyph> glyphs) :
    fontId = bytes.readUint16(),
    charCode = bytes.readUint16(),
    glyphId = bytes.readUint32() {
    char = String.fromCharCode(charCode);
    // if (_glyph.height != _font.height) {
    //   print("Warning: Glyph height (${_glyph.height}) does not match font height (${_font.height})");
    // }
    // if (_glyph.below != _font.below || _glyph.horizontal != _font.horizontal) {
    //   print("Warning: Glyph kerning (${_glyph.below}, ${_glyph.horizontal}) does not match font kerning (${_font.below}, ${_font.horizontal})");
    // }
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint16(fontId);
    bytes.writeUint16(charCode);
    bytes.writeUint32(glyphId);
  }
}

class McdFileGlyph {
  final int textureId;
  final double u1;
  final double v1;
  final double u2;
  final double v2;
  final double width;
  final double height;
  final double above;
  final double below;
  final double horizontal;

  McdFileGlyph(this.textureId, this.u1, this.v1, this.u2, this.v2, this.width,
      this.height, this.above, this.below, this.horizontal);
  
  McdFileGlyph.read(ByteDataWrapper bytes) :
    textureId = bytes.readUint32(),
    u1 = bytes.readFloat32(),
    v1 = bytes.readFloat32(),
    u2 = bytes.readFloat32(),
    v2 = bytes.readFloat32(),
    width = bytes.readFloat32(),
    height = bytes.readFloat32(),
    above = bytes.readFloat32(),
    below = bytes.readFloat32(),
    horizontal = bytes.readFloat32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(textureId);
    bytes.writeFloat32(u1);
    bytes.writeFloat32(v1);
    bytes.writeFloat32(u2);
    bytes.writeFloat32(v2);
    bytes.writeFloat32(width);
    bytes.writeFloat32(height);
    bytes.writeFloat32(above);
    bytes.writeFloat32(below);
    bytes.writeFloat32(horizontal);
  }
}

class McdFileFont {
  final int id;
  final double width;
  final double height;
  final double below;
  final double horizontal;

  McdFileFont(this.id, this.width, this.height, this.below, this.horizontal);
  
  McdFileFont.read(ByteDataWrapper bytes) :
    id = bytes.readUint32(),
    width = bytes.readFloat32(),
    height = bytes.readFloat32(),
    below = bytes.readFloat32(),
    horizontal = bytes.readFloat32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(id);
    bytes.writeFloat32(width);
    bytes.writeFloat32(height);
    bytes.writeFloat32(below);
    bytes.writeFloat32(horizontal);
  }
}

class McdFileLetterBase {
  late final int code;

  int get byteSize => 2;
}
class McdFileLetter extends McdFileLetterBase {
  late final int idx;

  final List<McdFileSymbol> _symbols;

  McdFileLetter(int code, this.idx, this._symbols) {
    super.code = code;
  }
  
  McdFileLetter.read(ByteDataWrapper bytes, this._symbols) {
    code = bytes.readUint16();
    idx = bytes.readInt16();
  }

  @override
  String toString() {
    if(code < 0x8000) {
      if (_symbols[code].charCode == 0x80)
        return "…";
      return _symbols[code].char;
    } else if (code == 0x8001)
      return " ";
    else if (code == 0x8020) {
      if (idx == 9)
        return "≡";  // controller menu button
      if (idx == 121)
        return "<Alt>";
    }

    print("<Special_0x${(code).toRadixString(16)}_$idx>");
    return "<Special_0x${(code).toRadixString(16)}_$idx>";
  }

  @override
  int get byteSize => 4;

  void write(ByteDataWrapper bytes) {
    bytes.writeUint16(code);
    bytes.writeInt16(idx);
  }
}
class McdFileLetterTerminator extends McdFileLetterBase {
  McdFileLetterTerminator() {
    super.code = 0x8000;
  }
}

class McdFileLine {
  int lettersOffset;
  final int padding;
  final int lettersCount;
  final int length2;
  final double below;
  final double horizontal;
  final List<McdFileLetter> letters;
  late final int terminator;

  McdFileLine(this.lettersOffset, this.padding, this.lettersCount, this.length2,
      this.below, this.horizontal, this.letters, this.terminator);
  
  McdFileLine.read(ByteDataWrapper bytes, List<McdFileSymbol> symbols) :
    lettersOffset = bytes.readUint32(),
    padding = bytes.readUint32(),
    lettersCount = bytes.readUint32(),
    length2 = bytes.readUint32(),
    below = bytes.readFloat32(),
    horizontal = bytes.readFloat32(),
    letters = [] {
    int pos = bytes.position;
    bytes.position = lettersOffset;
    var actualLettersCount = (lettersCount - 1) ~/ 2;
    for (int i = 0; i < actualLettersCount; i++) {
      letters.add(McdFileLetter.read(bytes, symbols));
    }
    terminator = bytes.readUint16();
    bytes.position = pos;
  }

  @override
  String toString() {
    return letters.join();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(lettersOffset);
    bytes.writeUint32(padding);
    bytes.writeUint32(lettersCount);
    bytes.writeUint32(length2);
    bytes.writeFloat32(below);
    bytes.writeFloat32(horizontal);

    var pos = bytes.position;
    bytes.position = lettersOffset;
    for (var letter in letters)
      letter.write(bytes);
    bytes.writeUint16(terminator);
    bytes.position = pos;
  }
}

class McdFileParagraph {
  int linesOffset;
  final int linesCount;
  final int vPos;
  final int hPos;
  final int fontId;
  final List<McdFileLine> lines;

  McdFileParagraph(this.linesOffset, this.linesCount, this.vPos, this.hPos, this.fontId,
      this.lines);
  
  McdFileParagraph.read(ByteDataWrapper bytes, List<McdFileSymbol> symbols) :
    linesOffset = bytes.readUint32(),
    linesCount = bytes.readUint32(),
    vPos = bytes.readUint32(),
    hPos = bytes.readUint32(),
    fontId = bytes.readUint32(),
    lines = [] {
      int pos = bytes.position;
      bytes.position = linesOffset;
      for (int i = 0; i < linesCount; i++) {
        lines.add(McdFileLine.read(bytes, symbols));
      }
      bytes.position = pos;
    }
  
  @override
  String toString() {
    return lines.join("\n");
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(linesOffset);
    bytes.writeUint32(linesCount);
    bytes.writeUint32(vPos);
    bytes.writeUint32(hPos);
    bytes.writeUint32(fontId);

    var pos = bytes.position;
    bytes.position = linesOffset;
    for (var line in lines)
      line.write(bytes);
    bytes.position = pos;
  }
}

class McdFileMessage {
  int paragraphsOffset;
  final int paragraphsCount;
  final int seqNumber;
  final int eventId;
  final List<McdFileParagraph> paragraphs;

  McdFileMessage(this.paragraphsOffset, this.paragraphsCount, this.seqNumber,
      this.eventId, this.paragraphs);
  
  McdFileMessage.read(ByteDataWrapper bytes, List<McdFileSymbol> symbols) :
    paragraphsOffset = bytes.readUint32(),
    paragraphsCount = bytes.readUint32(),
    seqNumber = bytes.readUint32(),
    eventId = bytes.readUint32(),
    paragraphs = [] {
    int pos = bytes.position;
    bytes.position = paragraphsOffset;
    for (int i = 0; i < paragraphsCount; i++) {
      paragraphs.add(McdFileParagraph.read(bytes, symbols));
    }
    bytes.position = pos;
  }

  @override
  String toString() {
    return paragraphs.join("\n\n");
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(paragraphsOffset);
    bytes.writeUint32(paragraphsCount);
    bytes.writeUint32(seqNumber);
    bytes.writeUint32(eventId);

    var pos = bytes.position;
    bytes.position = paragraphsOffset;
    for (var paragraph in paragraphs)
      paragraph.write(bytes);
    bytes.position = pos;
  }
}

class McdFileEvent {
  final int id;
  final int msgId;
  final String name;
  late final McdFileMessage message;

  McdFileEvent(this.id, this.msgId, this.name, this.message);
  
  McdFileEvent.read(ByteDataWrapper bytes, Map<int, McdFileMessage> messages) :
    id = bytes.readUint32(),
    msgId = bytes.readUint32(),
    name = bytes.readString(32).trimNull() {
    message = messages[msgId]!;
  }

  @override
  String toString() {
    var msgLines = message.toString()
      .split("\n")
      .map((line) => "  $line")
      .join("\n");
    return
      "Event $name {\n"
      "$msgLines\n"
      "}";
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(id);
    bytes.writeUint32(msgId);
    var fullName = name.padRight(32, "\x00");
    bytes.writeString(fullName);
  }
}

class McdFile {
  late final McdFileHeader header;
  late final List<McdFileMessage> messages;
  late final List<McdFileSymbol> symbols;
  late final List<McdFileGlyph> glyphs;
  late final List<McdFileFont> fonts;
  late final List<McdFileEvent> events;

  McdFile.read(ByteDataWrapper bytes) {
    header = McdFileHeader.read(bytes);
    messages = [];
    symbols = [];
    glyphs = [];
    fonts = [];
    events = [];

    // glyphs & fonts needed for symbols
    bytes.position = header.glyphsOffset;
    for (int i = 0; i < header.glyphsCount; i++) {
      glyphs.add(McdFileGlyph.read(bytes));
    }

    bytes.position = header.fontsOffset;
    for (int i = 0; i < header.fontsCount; i++) {
      fonts.add(McdFileFont.read(bytes));
    }

    // symbols needed for messages
    bytes.position = header.symbolsOffset;
    for (int i = 0; i < header.symbolsCount; i++) {
      symbols.add(McdFileSymbol.read(bytes, fonts, glyphs));
    }

    // messages needed for events
    bytes.position = header.messagesOffset;
    for (int i = 0; i < header.messagesCount; i++) {
      messages.add(McdFileMessage.read(bytes, symbols));
    }

    // events
    bytes.position = header.eventsOffset;
    Map<int, McdFileMessage> messagesMap = {};
    for (int i = 0; i < messages.length; i++)
      messagesMap[i] = messages[i];
    for (int i = 0; i < header.eventsCount; i++) {
      events.add(McdFileEvent.read(bytes, messagesMap));
    }
  }

  McdFile.fromParts(this.header, this.messages, this.symbols, this.glyphs, this.fonts,
      this.events);

  static Future<McdFile> fromFile(String path) async {
    final bytes = await ByteDataWrapper.fromFile(path);
    return McdFile.read(bytes);
  }

  Future<void> writeToFile(String path) async {
    var fileSize = header.eventsOffset + events.length * 0x28;
    var bytes = ByteDataWrapper.allocate(fileSize);

    header.write(bytes);
    bytes.position = header.messagesOffset;
    for (var message in messages)
      message.write(bytes);
    
    bytes.position = header.symbolsOffset;
    for (var symbol in symbols)
      symbol.write(bytes);
    
    bytes.position = header.glyphsOffset;
    for (var glyph in glyphs)
      glyph.write(bytes);
    
    bytes.position = header.fontsOffset;
    for (var font in fonts)
      font.write(bytes);
    
    bytes.position = header.eventsOffset;
    for (var event in events)
      event.write(bytes);
    
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
  }

  @override
  String toString() {
    return events.join("\n\n");
  }
}
