
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
  String text;
  int line;

  _ParserCursor(this.allText, this.index, this.text, this.line);

  void next([int count = 1]) {
    if (count == 0)
      return;
    int prevIndex = index;
    index += count;
    text = allText.substring(index);
    String sub = allText.substring(prevIndex, index);
    line += sub.split('\n').length - 1;
  }
}

/// Parse XML with line numbers
XmlElementWL parseXmlWL(String xml) {
  var cursor = _ParserCursor(xml, 0, xml, 1);
  _skipHeader(cursor);
  return _parseElement(cursor, null)!;  
}

XmlElementWL? _parseElement(_ParserCursor cursor, XmlElementWL? parent) {
  _skipWhitespace(cursor);
  int line = cursor.line;
  // parse opening tag
  int openTagStart = 0;
  int openTagEnd = cursor.text.indexOf(">", openTagStart);
  if (openTagStart == -1 || openTagEnd == -1)
    throw Exception("Invalid xml");
  String openTag = cursor.text.substring(openTagStart + 1, openTagEnd);
  // skip comment
  if (openTag.startsWith("!--")) {
    int commentEnd = cursor.text.indexOf("-->", openTagEnd);
    if (commentEnd == -1)
      throw Exception("Invalid xml");
    cursor.next(commentEnd + 3);
    return null;
  }
  String tag = openTag.split(" ").first;

  cursor.next(openTagEnd + 1);
  
  if (openTag.endsWith("/")) {  // <tag/>
    return XmlElementWL(tag, "", [], parent, line);
  }
  
  // parse text
  String text = cursor.text.substring(0, cursor.text.indexOf("<"));
  cursor.next(text.length);
  text = text.trim();
  
  // parse children
  var element = XmlElementWL(tag, text, [], parent, line);
  while (!cursor.text.startsWith("</$tag>")) {
    var child = _parseElement(cursor, element);
    _skipWhitespace(cursor);
    if (child == null)
      continue;
    element.addChild(child);
  }

  // parse closing tag
  int closeTagStart = cursor.text.indexOf("<");
  int closeTagEnd = cursor.text.indexOf(">", closeTagStart);
  if (closeTagStart == -1 || closeTagEnd == -1)
    throw Exception("Invalid xml");
  String closeTag = cursor.text.substring(closeTagStart + 2, closeTagEnd);
  if (closeTag != tag)
    throw Exception("Invalid xml");
  cursor.next(closeTagEnd + 1);

  return element;
}

void _skipHeader(_ParserCursor cursor) {
  int closeIndex = cursor.text.indexOf(">");
  if (closeIndex == -1)
    throw Exception("Invalid xml");
  cursor.next(closeIndex + 1);
}

void _skipWhitespace(_ParserCursor cursor) {
  var nextTag = cursor.text.indexOf("<");
  if (nextTag == -1)
    throw Exception("Invalid xml");
  cursor.next(nextTag);
}
