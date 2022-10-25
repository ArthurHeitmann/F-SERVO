
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
class McdHeader {
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

  McdHeader(this.messagesOffset, this.messagesCount, this.symbolsOffset,
      this.symbolsCount, this.glyphsOffset, this.glyphsCount, this.fontsOffset,
      this.fontsCount, this.eventsOffset, this.eventsCount);
  
  McdHeader.read(ByteDataWrapper bytes) :
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
class McdSymbol {
  final int fontId;
  final String code;
  final int glyphId;

  late final McdFont _font;
  late final McdGlyph _glyph;

  McdSymbol(this.fontId, this.code, this.glyphId, McdFile file) :
    _font = file.fonts[fontId],
    _glyph = file.glyphs[glyphId];
  
  McdSymbol.read(ByteDataWrapper bytes, McdFile file) :
    fontId = bytes.readUint16(),
    code = bytes.readString(2, encoding: StringEncoding.utf16),
    glyphId = bytes.readUint32() {
      _font = file.fonts.firstWhere((f) => f.id == fontId);
      _glyph = file.glyphs[glyphId];
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
class McdGlyph {
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

  McdGlyph(this.textureId, this.u1, this.v1, this.u2, this.v2, this.width,
      this.height, this.above, this.below, this.horizontal);
  
  McdGlyph.read(ByteDataWrapper bytes) :
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
class McdFont {
  final int id;
  final double width;
  final double height;
  final double below;
  final double horizontal;

  McdFont(this.id, this.width, this.height, this.below, this.horizontal);
  
  McdFont.read(ByteDataWrapper bytes) :
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
class McdLetter {
  final int code;
  final int positionOffset;

  final List<McdSymbol> _symbols;

  McdLetter(this.code, this.positionOffset, this._symbols);
  
  McdLetter.read(ByteDataWrapper bytes, this._symbols) :
    code = bytes.readUint16(),
    positionOffset = bytes.readInt16();

  @override
  String toString() {
    String s = "";
    if(code <= 0x8000 && code < _symbols.length) {
      s += _symbols[code].code;
    } else if (code == 0x8001) {
      s += " ";
    } else if (code == 0x8003) {
      s += "<";
      switch(positionOffset) {
        case 0:
          s+= "+";
          break;
        case 1:
          s+= "-";
          break;
        case 2:
          s += "B";
          break;
        case 3:
          s += "A";
          break;
        case 4:
          s += "Y";
          break;
        case 5:
          s += "X";
          break;
        case 6:
          s += "R";
          break;
        case 8:
          s += "";
          break;
        case 11:
          s += "DPadUpDown";
          break;
        case 12:
          s += "DPadLeftRight";
          break;
        case 17:
          s += "RightStick";
          break;
        case 18:
          s += "RightStickPress";
          break;
        case 19:
          s += "LeftStick";
          break;
        case 20:
          s += "LeftStickPress";
          break;
        case 24:
          s += "RightStickRotate";
          break;
        case 25:
          s += "LeftStickUpDown";
          break;
        case 113:
          s += "SwapWeapons";
          break;
        case 114:
          s += "Evade";
          break;
        case 115:
          s += "UmbranClimax";
          break;
        case 116:
          s += "LockOn";
          break;
        default:
          s += "[$positionOffset]";
      }
      s += ">";
    } else {
      s += "<Special0x${(code).toRadixString(16)}_$positionOffset>";
    }
    return s;
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
class McdLine {
  final int lettersOffset;
  final int padding;
  final int lettersCount;
  final int length2;
  final double below;
  final double horizontal;
  final List<McdLetter> letters;
  late final int terminator;

  McdLine(this.lettersOffset, this.padding, this.lettersCount, this.length2,
      this.below, this.horizontal, this.letters);
  
  McdLine.read(ByteDataWrapper bytes, List<McdSymbol> symbols) :
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
      letters.add(McdLetter.read(bytes, symbols));
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
class McdParagraph {
  final int linesOffset;
  final int linesCount;
  final int vPos;
  final int hPos;
  final int fontId;
  final List<McdLine> lines;

  McdParagraph(this.linesOffset, this.linesCount, this.vPos, this.hPos, this.fontId,
      this.lines);
  
  McdParagraph.read(ByteDataWrapper bytes, List<McdSymbol> symbols) :
    linesOffset = bytes.readUint32(),
    linesCount = bytes.readUint32(),
    vPos = bytes.readUint32(),
    hPos = bytes.readUint32(),
    fontId = bytes.readUint32(),
    lines = [] {
      int pos = bytes.position;
      bytes.position = linesOffset;
      for (int i = 0; i < linesCount; i++) {
        lines.add(McdLine.read(bytes, symbols));
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
class McdMessage {
  final int paragraphsOffset;
  final int paragraphsCount;
  final int seqNumber;
  final int eventId;
  final List<McdParagraph> paragraphs;

  McdMessage(this.paragraphsOffset, this.paragraphsCount, this.seqNumber,
      this.eventId, this.paragraphs);
  
  McdMessage.read(ByteDataWrapper bytes, List<McdSymbol> symbols) :
    paragraphsOffset = bytes.readUint32(),
    paragraphsCount = bytes.readUint32(),
    seqNumber = bytes.readUint32(),
    eventId = bytes.readUint32(),
    paragraphs = [] {
    int pos = bytes.position;
    bytes.position = paragraphsOffset;
    for (int i = 0; i < paragraphsCount; i++) {
      paragraphs.add(McdParagraph.read(bytes, symbols));
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
class McdEvent {
  final int id;
  final int msgId;
  final String name;
  late final McdMessage message;

  McdEvent(this.id, this.msgId, this.name, this.message);
  
  McdEvent.read(ByteDataWrapper bytes, Map<int, McdMessage> messages) :
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
  late final McdHeader header;
  late final List<McdMessage> messages;
  late final List<McdSymbol> symbols;
  late final List<McdGlyph> glyphs;
  late final List<McdFont> fonts;
  late final List<McdEvent> events;

  McdFile.read(ByteDataWrapper bytes) {
    header = McdHeader.read(bytes);
    messages = [];
    symbols = [];
    glyphs = [];
    fonts = [];
    events = [];

    // glyphs & fonts needed for symbols
    bytes.position = header.glyphsOffset;
    for (int i = 0; i < header.glyphsCount; i++) {
      glyphs.add(McdGlyph.read(bytes));
    }

    bytes.position = header.fontsOffset;
    for (int i = 0; i < header.fontsCount; i++) {
      fonts.add(McdFont.read(bytes));
    }

    // symbols needed for messages
    bytes.position = header.symbolsOffset;
    for (int i = 0; i < header.symbolsCount; i++) {
      symbols.add(McdSymbol.read(bytes, this));
    }

    // messages needed for events
    bytes.position = header.messagesOffset;
    for (int i = 0; i < header.messagesCount; i++) {
      messages.add(McdMessage.read(bytes, symbols));
    }

    // events
    bytes.position = header.eventsOffset;
    Map<int, McdMessage> messagesMap = {};
    for (int i = 0; i < messages.length; i++)
      messagesMap[i] = messages[i];
    for (int i = 0; i < header.eventsCount; i++) {
      events.add(McdEvent.read(bytes, messagesMap));
    }
  }

  static Future<McdFile> fromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return McdFile.read(ByteDataWrapper(bytes.buffer));
  }
}
