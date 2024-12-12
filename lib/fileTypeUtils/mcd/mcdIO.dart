
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
  final double null0;
  final double horizontalSpacing;
  final double null1;

  McdFileGlyph(this.textureId, this.u1, this.v1, this.u2, this.v2, this.width,
      this.height, this.null0, this.horizontalSpacing, this.null1);
  
  McdFileGlyph.read(ByteDataWrapper bytes) :
    textureId = bytes.readUint32(),
    u1 = bytes.readFloat32(),
    v1 = bytes.readFloat32(),
    u2 = bytes.readFloat32(),
    v2 = bytes.readFloat32(),
    width = bytes.readFloat32(),
    height = bytes.readFloat32(),
    null0 = bytes.readFloat32(),
    horizontalSpacing = bytes.readFloat32(),
    null1 = bytes.readFloat32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(textureId);
    bytes.writeFloat32(u1);
    bytes.writeFloat32(v1);
    bytes.writeFloat32(u2);
    bytes.writeFloat32(v2);
    bytes.writeFloat32(width);
    bytes.writeFloat32(height);
    bytes.writeFloat32(null0);
    bytes.writeFloat32(horizontalSpacing);
    bytes.writeFloat32(null1);
  }
}

class McdFileFont {
  final int id;
  final double width;
  final double height;
  final double horizontalSpacing;
  final double verticalSpacing;

  McdFileFont(this.id, this.width, this.height, this.horizontalSpacing, this.verticalSpacing);
  
  McdFileFont.read(ByteDataWrapper bytes) :
    id = bytes.readUint32(),
    width = bytes.readFloat32(),
    height = bytes.readFloat32(),
    horizontalSpacing = bytes.readFloat32(),
    verticalSpacing = bytes.readFloat32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(id);
    bytes.writeFloat32(width);
    bytes.writeFloat32(height);
    bytes.writeFloat32(horizontalSpacing);
    bytes.writeFloat32(verticalSpacing);
  }
}

const _messCommonCharsLookup = [
  "%", ".", ":", "_", "/", "0", "1", "2", "3", "4", "5", "6", "7", "8",
  "9", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "À",
  "Á", "Â", "Ã", "Ä", "Å", "Æ", "Ç", "È", "É", "Ê", "Ë", "Ì", "Í", "Î",
  "Ï", "Ð", "Ñ", "Ò", "Ó", "Ô", "Õ", "Ö", "Ø", "Ù", "Ú", "Û", "Ü", "Ÿ",
  "Ý", "ß", "-", "#", "%", "+", ",", "-", ".", "0", "1", "2", "3", "4",
  "5", "6", "7", "8", "9", ":", "/", "%", ".", ":", "_", "/", "0", "1",
  "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F",
  "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
  "U", "V", "W", "X", "Y", "Z", "À", "Á", "Â", "Ã", "Ä", "Å", "Æ", "Ç",
  "È", "É", "Ê", "Ë", "Ì", "Í", "Î", "Ï", "Ð", "Ñ", "Ò", "Ó", "Ô", "Õ",
  "Ö", "Ø", "Ù", "Ú", "Û", "Ü", "Ÿ", "Ý", "+", "-", "#", ".", ",", "%",
];
const _messCommonStartIndex = 0x4000;
const _messCommonEndIndex = 0x40A8;
const _messCommonFontRanges = {
  0: (0, 73),
  6: (73, 91),
  8: (91, 168),
};
const _buttonsLookup = [
  "C-A","C-B","C-B","C-A","C-Y","C-X","C-RB","C-RT","C-LB","C-LT","C-DPad","C-DPad-UD",
  "C-DPad-LR","C-DPad-Up","C-DPad-Down","C-DPad-Left","C-DPad-Right","C-RStick","C-RStick-Press",
  "C-LStick","C-LStick-Press","C-Start","C-Back","C-Arrow-Up","C-Arrow-Down","C-Arrow-Left",
  "C-Arrow-Right",null,null,null,null,null,"K-Enter","K-Esc","K-Up","K-Down","K-Left","K-Right",
  null,null,"K-Z","K-X","K-E","K-Ctrl","K-C","K-Shift",null,null,null,"K-V","K-Num4","K-Num3",null,
  null,null,"K-Move","Reload",null,null,null,null,null,null,null,null,null,null,null,null,null,null,
  null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,
  null,null,null,null,null,null,null,null,null,null,"B-Blade-Mode","B-Ninja-Run","B-Use-Subweapon",
  "B-Change-Focus","B-Move","B-Rotate-Camera","B-Light-Attack","B-Heavy-Attack","B-Jump","B-Interact",
  "B-Defensive-Offense","B-","B-Execution",
];
const _buttonsCode = 0x8003;


class McdFileLetterBase {
  late final int code;

  int get byteSize => 2;
}
class McdFileLetter extends McdFileLetterBase {
  late final int kerning;
  late final bool hasKerning;
  bool get isControlChar => code == 0x8000 || code == 0x8008 || code == 0x8009 || code == 0x800A;

  McdFileLetter(int code, this.kerning)
    : hasKerning = code != 0x8009 && code != 0x800A {
    super.code = code;
  }
  
  McdFileLetter.read(ByteDataWrapper bytes) {
    code = bytes.readUint16();
    hasKerning = code != 0x8009 && code != 0x800A;
    if (hasKerning)
      kerning = bytes.readInt16();
    else
      kerning = 0;
  }

  static McdFileLetter? tryMakeMessCommonLetter(String char, int fontId) {
    var range = _messCommonFontRanges[fontId];
    if (range == null)
      return null;
    var (start, end) = range;
    for (int i = start; i < end; i++) {
      if (_messCommonCharsLookup[i] == char)
        return McdFileLetter(_messCommonStartIndex + i, 0);
    }
    return null;
  }

  McdFileSymbol? getSymbol(List<McdFileSymbol> symbols) {
    if (code < symbols.length)
      return symbols[code];
    return null;
  }

  String encodeChar(McdFileSymbol? symbol) {
    if(code < 0x8000) {
      if (code >= _messCommonStartIndex && code < _messCommonEndIndex)
        return _messCommonCharsLookup[code - _messCommonStartIndex];
      if (symbol != null) {
        return symbol.char;
      }
    } else if (code == 0x8001)
      return " ";
    else if (code == _buttonsCode && kerning < _buttonsLookup.length) {
      var button = _buttonsLookup[kerning];
      if (button != null)
        return "[b/$button]";
    }
    if (hasKerning)
      return "[c/0x${(code).toRadixString(16)}:$kerning]";
    else
      return "[c/0x${(code).toRadixString(16)}]";
  }

  @override
  int get byteSize => hasKerning ? 4 : 2;

  void write(ByteDataWrapper bytes) {
    bytes.writeUint16(code);
    if (hasKerning)
      bytes.writeInt16(kerning);
  }
}
class McdFileLetterTerminator extends McdFileLetterBase {
  McdFileLetterTerminator() {
    super.code = 0x8000;
  }
}

final _specialWrapperPattern = RegExp(r"^\[(c/0x[0-9a-f]+(:\d+)?|b/.+|s/.+/f:\d+)\]");
final _specialCharPattern = RegExp(r"^\[c/0x([0-9a-f]+)(?::(\d+))?\]");
final _specialButtonPattern = RegExp(r"^\[b/(.+?)\]");
final _specialFontPattern = RegExp(r"^\[s/(.+?)/f:(\d+)\]");
abstract class ParsedMcdCharBase {
  final String representation;
  void setFontId(int fontId);

  ParsedMcdCharBase(this.representation);

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
  
  static List<ParsedMcdCharBase> parseLine(String line, int lineFontId) {
    List<ParsedMcdCharBase> parsedChars = [];
    List<ParsedMcdCharBase>? pendingChars;
    int? pendingFontId;
    void pushChar(ParsedMcdCharBase char) {
      if (pendingChars != null)
        pendingChars.add(char);
      else
        parsedChars.add(char);
    }
    int i = 0;
    while (i < line.length) {
      var c = line[i];
      switch (c) {
        case " ":
          pushChar(ParsedMcdSpecialChar.space(lineFontId));
          break;
        case "[" when
          i + 4 < line.length &&
          _specialWrapperPattern.hasMatch(line.substring(i)):
          var representation = _specialWrapperPattern.firstMatch(line.substring(i))!.group(0)!;
          var next = line[i + 1];
          if (next == "c") {
            var match = _specialCharPattern.firstMatch(line.substring(i))!;
            var code1 = int.parse(match.group(1)!, radix: 16);
            var code2Match = match.group(2);
            var code2 = int.parse(code2Match ?? "0");
            pushChar(ParsedMcdSpecialChar(representation, code1, code2, code2Match != null));
            i += match.group(0)!.length - 1;
          }
          else if (next == "b") {
            var match = _specialButtonPattern.firstMatch(line.substring(i))!;
            var button = match.group(1)!;
            var buttonIndex = _buttonsLookup.indexOf(button);
            if (buttonIndex == -1)
              throw Exception("Unknown button: $button");
            pushChar(ParsedMcdSpecialChar(representation, _buttonsCode, buttonIndex, true));
            i += match.group(0)!.length - 1;
          }
          else if (next == "s") {
            var match = _specialFontPattern.firstMatch(line.substring(i))!;
            pendingFontId = int.parse(match.group(2)!);
            if (pendingChars != null)
              print("Warning in line \"$line\": pendingChars is not null at $i");
            pendingChars ??= [];
            i += "[s/".length - 1;
          }
          else {
            throw Exception("Unknown special char: $next");
          }
          break;
        case "/" when
          pendingChars != null && pendingFontId != null &&
          i + 3 < line.length &&
          line[i + 1] == "f" && line[i + 2] == ":":
          for (var char in pendingChars) {
            char.setFontId(pendingFontId);
            parsedChars.add(char);
          }
          i = line.indexOf("]", i);
          pendingChars = null;
          pendingFontId = null;
          break;
        default:
          pushChar(ParsedMcdChar(line[i], lineFontId));
          break;
      }
      i++;
    }
    assert(pendingChars == null);
    assert(pendingFontId == null);

    return parsedChars;
  }
}
class ParsedMcdChar extends ParsedMcdCharBase {
  final String char;
  int fontId;

  ParsedMcdChar(this.char, this.fontId) : super(char);
  
  @override
  void setFontId(int fontId) {
    this.fontId = fontId;
  }

  @override
  bool operator ==(Object other) {
    if (other is ParsedMcdChar)
      return char == other.char && fontId == other.fontId;
    return false;
  }

  @override
  int get hashCode => Object.hash(char, fontId);

  @override
  String toString() => "ParsedMcdChar($char, $fontId)";
}
class ParsedMcdSpecialChar extends ParsedMcdCharBase {
  final int code1;
  int code2;
  final bool hasKerning;

  ParsedMcdSpecialChar(super.representation, this.code1, this.code2, this.hasKerning);

  ParsedMcdSpecialChar.space(int fontId) : code1 = 0x8001, code2 = fontId, hasKerning = true, super(" ");
  
  @override
  void setFontId(int fontId) {
    if (code1 == 0x8001)
      code2 = fontId;
  }

  @override
  bool operator ==(Object other) {
    if (other is ParsedMcdSpecialChar)
      return code1 == other.code1 && code2 == other.code2;
    return false;
  }

  @override
  int get hashCode => Object.hash(code1, code2);

  @override
  String toString() {
    if (code1 == 0x8001)
      return "ParsedMcdSpecialChar.space($code2)";
    return "ParsedMcdSpecialChar($code1, $code2)";
  }
}

class McdFileLine {
  int lettersOffset;
  final int padding;
  final int nonControlCharacterCount;
  final int totalLetterCount;
  final int lineHeight;
  final int zero;
  final List<McdFileLetter> letters;
  late final int terminator;

  McdFileLine(this.lettersOffset, this.padding, this.nonControlCharacterCount, this.totalLetterCount,
      this.lineHeight, this.zero, this.letters, this.terminator);
  
  McdFileLine.read(ByteDataWrapper bytes) :
    lettersOffset = bytes.readUint32(),
    padding = bytes.readUint32(),
    nonControlCharacterCount = bytes.readUint32(),
    totalLetterCount = bytes.readUint32(),
    lineHeight = bytes.readInt32(),
    zero = bytes.readInt32(),
    letters = [] {
    int pos = bytes.position;
    bytes.position = lettersOffset;
    for (int i = 0; i < totalLetterCount - 1; i++) {
      letters.add(McdFileLetter.read(bytes));
    }
    terminator = bytes.readUint16();
    bytes.position = pos;
  }

  String encodeAsString(int fontId, List<McdFileSymbol> symbols) {
    var buffer = StringBuffer();
    var prevFontId = fontId;
    for (var letter in letters) {
      var symbol = letter.getSymbol(symbols);
      var letterEncoded = letter.encodeChar(symbol);
      if (symbol != null) {
        var symbolFontId = symbol.fontId;
        if (symbolFontId != prevFontId) {
          if (prevFontId != fontId)
            buffer.write("/f:$prevFontId]");
          if (symbolFontId != fontId)
            buffer.write("[s/");
        }
        prevFontId = symbolFontId;
      }
      buffer.write(letterEncoded);
    }
    if (prevFontId != fontId)
      buffer.write("/f:$prevFontId]");
    return buffer.toString();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(lettersOffset);
    bytes.writeUint32(padding);
    bytes.writeUint32(nonControlCharacterCount);
    bytes.writeUint32(totalLetterCount);
    bytes.writeInt32(lineHeight);
    bytes.writeInt32(zero);

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
  final int paragraphIndex;
  final int nonControlCharacterCount;
  final int fontId;
  final List<McdFileLine> lines;

  McdFileParagraph(this.linesOffset, this.linesCount, this.paragraphIndex, this.nonControlCharacterCount, this.fontId, this.lines);
  
  McdFileParagraph.read(ByteDataWrapper bytes) :
    linesOffset = bytes.readUint32(),
    linesCount = bytes.readUint32(),
    paragraphIndex = bytes.readUint32(),
    nonControlCharacterCount = bytes.readUint32(),
    fontId = bytes.readUint32(),
    lines = [] {
      int pos = bytes.position;
      bytes.position = linesOffset;
      for (int i = 0; i < linesCount; i++) {
        lines.add(McdFileLine.read(bytes));
      }
      bytes.position = pos;
    }
  
  String encodeAsString(List<McdFileSymbol> symbols) {
    var buffer = StringBuffer();
    for (var line in lines) {
      buffer.write(line.encodeAsString(fontId, symbols));
      buffer.write("\n");
    }
    return buffer.toString();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(linesOffset);
    bytes.writeUint32(linesCount);
    bytes.writeUint32(paragraphIndex);
    bytes.writeUint32(nonControlCharacterCount);
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
  
  McdFileMessage.read(ByteDataWrapper bytes) :
    paragraphsOffset = bytes.readUint32(),
    paragraphsCount = bytes.readUint32(),
    seqNumber = bytes.readUint32(),
    eventId = bytes.readUint32(),
    paragraphs = [] {
    int pos = bytes.position;
    bytes.position = paragraphsOffset;
    for (int i = 0; i < paragraphsCount; i++) {
      paragraphs.add(McdFileParagraph.read(bytes));
    }
    bytes.position = pos;
  }

  String encodeAsString(List<McdFileSymbol> symbols) {
    var buffer = StringBuffer();
    for (var paragraph in paragraphs) {
      buffer.write(paragraph.encodeAsString(symbols));
      buffer.write("\n\n");
    }
    return buffer.toString();
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
  // final String name;
  late final McdFileMessage message;

  McdFileEvent(this.id, this.msgId, this.message);
  
  McdFileEvent.read(ByteDataWrapper bytes, Map<int, McdFileMessage> messages) :
    id = bytes.readUint32(),
    msgId = bytes.readUint32()/*,
    name = bytes.readString(32).trimNull()*/ {
    message = messages[msgId]!;
  }

  String encodeAsString(List<McdFileSymbol> symbols) {
    var msgLines = message.encodeAsString(symbols)
      .split("\n")
      .map((line) => "  $line")
      .join("\n");
    return
      "Event {\n"
      "$msgLines\n"
      "}";
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(id);
    bytes.writeUint32(msgId);
    // var fullName = name.padRight(32, "\x00");
    // bytes.writeString(fullName);
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
      messages.add(McdFileMessage.read(bytes));
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
    var fileSize = header.eventsOffset + events.length * 0x8;
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
    
    await bytes.save(path);
  }

  String encodeAsString(List<McdFileSymbol> symbols) {
    var buffer = StringBuffer();
    for (var event in events) {
      buffer.write(event.encodeAsString(symbols));
      buffer.write("\n");
    }
    return buffer.toString();
  }

  List<McdFileSymbol> makeSymbolsMap() {
    List<McdFileSymbol?> symbolsMap = List.filled(symbols.length, null);
    for (var symbol in symbols) {
      symbolsMap[symbol.glyphId] = symbol;
    }
    return symbolsMap.map((e) => e!).toList();
  }
}
