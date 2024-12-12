
import 'package:f_servo/fileTypeUtils/mcd/mcdIO.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

const _fontId = 7;

ParsedMcdChar _char(String char, [int fontId = _fontId]) => ParsedMcdChar(char, fontId);
List<ParsedMcdChar> _chars(String str, [int fontId = _fontId]) => str.split("").map((c) => _char(c, fontId)).toList();
ParsedMcdSpecialChar _special(int code, int char, [bool hasKerning = true]) => ParsedMcdSpecialChar("[c/0x${code.toRadixString(16)}:$char]", code, char, hasKerning);
ParsedMcdSpecialChar _space([int fontId = _fontId]) => ParsedMcdSpecialChar.space(fontId);

void _testLine(String line, List<ParsedMcdCharBase> expected) {
  test("Test MCD line parsing '$line'", () {
    var parsed = ParsedMcdCharBase.parseLine(line, _fontId);
    expect(parsed, equals(expected));
  });
}

void main() {
  _testLine(
    "X",
    [_char("X"),],
  );
  _testLine(
    "AB",
    [_char("A"),_char("B"),],
  );
  _testLine(
    " ",
    [_space(),],
  );
  _testLine(
    "A B",
    [_char("A"),_space(),_char("B"),],
  );
  _testLine(
    "[c/0x123:23]",
    [_special(0x123, 23)],
  );
  _testLine(
    "[c/0x123]",
    [_special(0x123, 0, false)],
  );
  _testLine(
    "[/0x1:2]",
    _chars("[/0x1:2]"),
  );
  _testLine(
    "[c0x1:2]",
    _chars("[c0x1:2]"),
  );
  _testLine(
    "[c/x1:2]",
    _chars("[c/x1:2]"),
  );
  _testLine(
    "[c/01:2]",
    _chars("[c/01:2]"),
  );
  _testLine(
    "[c/0x:2]",
    _chars("[c/0x:2]"),
  );
  _testLine(
    "[c/0x1:]",
    _chars("[c/0x1:]"),
  );
  _testLine(
    "[c/0x1:2",
    _chars("[c/0x1:2"),
  );
  _testLine(
    "ABC [c/0x123:23] DEF",
    [..._chars("ABC"), _space(), _special(0x123, 23), _space(), ..._chars("DEF")],
  );
  _testLine(
    "[b/K-Up]",
    [_special(0x8003, 34)],
  );
  _testLine(
    "[K-Up]",
    _chars("[K-Up]"),
  );
  _testLine(
    "[b/K-Up",
    _chars("[b/K-Up"),
  );
  _testLine(
    "-[b/B-] ",
    [_char("-"), _special(0x8003, 111), _space()],
  );
  _testLine(
    "[s/a/f:2]",
    [_char("a", 2)],
  );
  _testLine(
    "[s/abc/f:2]",
    _chars("abc", 2),
  );
  _testLine(
    "[s/abc/f:2]def",
    [..._chars("abc", 2), ..._chars("def")],
  );
  _testLine(
    "[s/abc/f:2][s/ def/f:5]",
    [..._chars("abc", 2), _space(5), ..._chars("def", 5)],
  );
}
