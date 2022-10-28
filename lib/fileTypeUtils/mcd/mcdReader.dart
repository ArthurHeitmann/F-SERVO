
import 'dart:io';

import '../utils/ByteDataWrapper.dart';

/*
struct Header
{
	uint32 messagesOffset;
	uint32 messagesCount;
	uint32 symbolsOffset;
	uint32 symbolsCount;
	uint32 glyphsOffset;
	uint32 glyphsCount;
	uint32 fontsOffset;
	uint32 fontsCount;
	uint32 eventsOffset;
	uint32 eventsCount;

} header;
*/
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
}

/*
struct Symbol {
    uint16 fontId;
    wchar_t code;
    uint32 glyphId;
}
*/
class McdFileSymbol {
  final int fontId;
  final int charCode;
  late final String char;
  final int glyphId;

  late final McdFileFont _font;
  late final McdFileGlyph _glyph;

  McdFileSymbol(this.fontId, this.charCode, this.glyphId, McdFile file) :
    _font = file.fonts[fontId],
    _glyph = file.glyphs[glyphId],
    char = String.fromCharCode(charCode);
  
  McdFileSymbol.read(ByteDataWrapper bytes, List<McdFileFont> fonts, List<McdFileGlyph> glyphs) :
    fontId = bytes.readUint16(),
    charCode = bytes.readUint16(),
    glyphId = bytes.readUint32() {
    char = String.fromCharCode(charCode);
    _font = fonts.firstWhere((f) => f.id == fontId);
    _glyph = glyphs[glyphId];
    // if (_glyph.height != _font.height) {
    //   print("Warning: Glyph height (${_glyph.height}) does not match font height (${_font.height})");
    // }
    // if (_glyph.below != _font.below || _glyph.horizontal != _font.horizontal) {
    //   print("Warning: Glyph kerning (${_glyph.below}, ${_glyph.horizontal}) does not match font kerning (${_font.below}, ${_font.horizontal})");
    // }
  }
}

/*
struct Glyph {
	uint32 textureId;
	float u1;
	float v1;
	float u2;
	float v2;
	float width;
	float height;
	float above;
	float below;
	float horizontal;
}
*/
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
}

/*
struct Font {
	uint32 id;
	float width;
	float height;
	float below;
	float horizontal;
}
*/
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
}

/*
struct Letter {
    uint16 code;
    short positionOffset;
};
*/
class McdFileLetter {
  final int code;
  final int idx;

  final List<McdFileSymbol> _symbols;

  McdFileLetter(this.code, this.idx, this._symbols);
  
  McdFileLetter.read(ByteDataWrapper bytes, this._symbols) :
    code = bytes.readUint16(),
    idx = bytes.readInt16();

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
}

/*
struct Line {
    uint32 lettersOffset;
    uint32 padding;
    uint32 lettersCount;
    uint32 length2;
    float below;
    float horizontal;

    local int pos = FTell();
    FSeek(lettersOffset);

    Letter letters[lettersCount];

    FSeek(pos);
};
*/
class McdFileLine {
  final int lettersOffset;
  final int padding;
  final int lettersCount;
  final int length2;
  final double below;
  final double horizontal;
  final List<McdFileLetter> letters;
  late final int terminator;

  McdFileLine(this.lettersOffset, this.padding, this.lettersCount, this.length2,
      this.below, this.horizontal, this.letters);
  
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
}

/*
struct Paragraph {
    uint32 linesOffset;
    uint32 linesCount;
    uint32 vPos;
    uint32 hPos;
    uint32 fontId;

    local int pos = FTell();
    FSeek(linesOffset);

    Line lines[linesCount] <read=readLine, optimize=false>;

    FSeek(pos);
};
*/
class McdFileParagraph {
  final int linesOffset;
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
}

/*
struct Message {
    uint32 paragraphsOffset;
    uint32 paragraphsCount;
    uint32 seqNumber;
    uint32 eventId;
    
    local int pos = FTell();
    FSeek(paragraphsOffset);

    Paragraph p[paragraphsCount] <read=readParagraph, optimize=false>;;

    FSeek(pos);
};
*/
class McdFileMessage {
  final int paragraphsOffset;
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
}

/*
struct Event {
	uint32 id;
	uint32 msgId;
	char name[32];

    local int pos = FTell();
    FSeek(header.messagesOffset + msgId * 4 * 4);
    
    Message m<read=readMessage>;
    
    FSeek(pos);
};
*/
class McdFileEvent {
  final int id;
  final int msgId;
  final String name;
  late final McdFileMessage message;

  McdFileEvent(this.id, this.msgId, this.name, this.message);
  
  McdFileEvent.read(ByteDataWrapper bytes, Map<int, McdFileMessage> messages) :
    id = bytes.readUint32(),
    msgId = bytes.readUint32(),
    name = bytes.readString(32).replaceAll("\x00", "") {
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

  static Future<McdFile> fromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return McdFile.read(ByteDataWrapper(bytes.buffer));
  }
}
