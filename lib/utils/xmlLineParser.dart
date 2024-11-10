
// very very basic xml parser that stores the line number of each element

/// XML element with line number
class XmlElementWL {
  final String tag;
  final String text;
  final List<XmlElementWL> _children;
  XmlElementWL? parent;
  final int line;
  Iterable<XmlElementWL> get children => _children;

  XmlElementWL(this.tag, this.text, this._children, this.parent, this.line);

  void addChild(XmlElementWL child) {
    _children.add(child);
    child.parent = this;
  }

  XmlElementWL? get(String tag) {
    for (var child in _children) {
      if (child.tag == tag)
        return child;
    }
    return null;
  }

  List<XmlElementWL> getAll(String tag) {
    return _children.where((child) => child.tag == tag).toList();
  }

  XmlElementWL? getByLine(int line) {
    if (line == this.line)
      return this;
    for (var child in _children) {
      var result = child.getByLine(line);
      if (result != null)
        return result;
    }
    return null;
  }

  @override
  String toString() {
    return "XmlElementWL(name: $tag, text: $text)";
  }
}

class _ParserCursor {
  String allText;
  int index;
  int line;

  _ParserCursor(this.allText, this.index, this.line);

  void next([int count = 1]) {
    if (count == 0)
      return;
    int prevIndex = index;
    index += count;
    String sub = allText.substring(prevIndex, index);
    line += sub.split('\n').length - 1;
  }

  String substring(int start, int end) {
    return allText.substring(index + start, index + end);
  }

  int indexOf(String str, [int start = 0]) {
    var i = allText.indexOf(str, index + start);
    if (i == -1)
      return -1;
    return i - index;
  }

  bool startsWith(String str) {
    return allText.startsWith(str, index);
  }
}

class XmlWlParseException implements Exception {
  final String message;
  final int line;

  XmlWlParseException(this.message, this.line);

  @override
  String toString() {
    return "line $line: $message";
  }
}

/// Parse XML with line numbers
XmlElementWL parseXmlWL(String xml) {
  var cursor = _ParserCursor(xml, 0, 1);
  _skipHeader(cursor);
  return _parseElement(cursor, null)!;  
}

XmlElementWL? _parseElement(_ParserCursor cursor, XmlElementWL? parent) {
  _skipWhitespace(cursor, "Unexpected end of file");
  int line = cursor.line;
  // parse opening tag
  int openTagStart = 0;
  int openTagEnd = cursor.indexOf(">", openTagStart);
  if (openTagStart == -1 || openTagEnd == -1)
    throw XmlWlParseException("Tag not closed", line);
  String openTag = cursor.substring(openTagStart + 1, openTagEnd);
  // skip comment
  if (openTag.startsWith("!--")) {
    int commentEnd = cursor.indexOf("-->", openTagEnd);
    if (commentEnd == -1)
      throw XmlWlParseException("Comment not closed", line);
    cursor.next(commentEnd + 3);
    return null;
  }
  String tag = openTag.split(" ").first;
  if (tag.startsWith("/"))
    throw XmlWlParseException("Unexpected closing tag $tag", line);

  cursor.next(openTagEnd + 1);
  
  if (openTag.endsWith("/")) {  // <tag/>
    return XmlElementWL(tag, "", [], parent, line);
  }
  
  // parse text
  var textEnd = cursor.indexOf("<");
  if (textEnd == -1)
    throw XmlWlParseException("Unexpected end of file parsing text of <$tag> (start at line $line)", line);
  String text = cursor.substring(0, textEnd);
  cursor.next(text.length);
  text = text.trim();
  
  // parse children
  var element = XmlElementWL(tag, text, [], parent, line);
  while (!cursor.startsWith("</$tag>")) {
    var child = _parseElement(cursor, element);
    _skipWhitespace(cursor, "Unexpected end of file parsing children of <$tag> (opened at line $line)");
    if (child == null)
      continue;
    element.addChild(child);
  }

  // parse closing tag
  int closeTagStart = cursor.indexOf("<");
  int closeTagEnd = closeTagStart != -1 ? cursor.indexOf(">", closeTagStart) : -1;
  if (closeTagStart == -1 || closeTagEnd == -1)
    throw XmlWlParseException("<$tag> not closed (opened at line $line)", line);
  String closeTag = cursor.substring(closeTagStart + 2, closeTagEnd);
  if (closeTag != tag)
    throw XmlWlParseException("Closing tag $closeTag does not match opening tag $tag (opened at line $line)", line);
  cursor.next(closeTagEnd + 1);

  return element;
}

void _skipHeader(_ParserCursor cursor) {
  int closeIndex = cursor.indexOf(">");
  if (closeIndex == -1)
    throw XmlWlParseException("Header not closed", cursor.line);
  cursor.next(closeIndex + 1);
}

void _skipWhitespace(_ParserCursor cursor, String errorMessage) {
  var nextTag = cursor.indexOf("<");
  if (nextTag == -1)
    throw XmlWlParseException(errorMessage, cursor.line);
  cursor.next(nextTag);
}
