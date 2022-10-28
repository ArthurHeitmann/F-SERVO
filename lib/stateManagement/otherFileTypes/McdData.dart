
import '../../fileTypeUtils/mcd/mcdReader.dart';
import '../Property.dart';

class McdSymbol {
  String char;
  int fontId;
  NumberProp texId;
  VectorProp uv1;
  VectorProp uv2;
  VectorProp size;

  McdSymbol(this.char, this.fontId, this.texId, this.uv1, this.uv2, this.size);
}

class McdFont {
  NumberProp id;
  VectorProp size;
  VectorProp kerning;
  
  List<McdSymbol> symbols;

  McdFont(this.id, this.size, this.kerning, this.symbols);
}

class McdFontData {
  late final List<McdFont> fonts;
  late final List<McdSymbol> symbols;

  McdFontData(this.fonts, this.symbols);

  McdFontData.fromFile(McdFile file) {
    var sym = file.symbols;
    var glyphs = file.glyphs;
    symbols = List.generate(
      file.symbols.length,
      (i) => McdSymbol(
        sym[i].char,
        sym[i].fontId,
        NumberProp(glyphs[i].textureId, true),
        VectorProp([glyphs[i].u1, glyphs[i].v1]),
        VectorProp([glyphs[i].u2, glyphs[i].v2]),
        VectorProp([glyphs[i].width, glyphs[i].height])
      )
    );
    fonts = file.fonts
      .map((f) => McdFont(
        NumberProp(f.id, true),
        VectorProp([f.width, f.height]),
        VectorProp([f.below, f.horizontal]),
        symbols
          .where((s) => s.fontId == f.id)
          .toList()
      ))
      .toList();
  }
}

class McdLine {
  List<McdSymbol> symbols;

  McdLine(this.symbols);

  String toText() => symbols.map((s) => s.char).join();
}

class McdParagraph {
  NumberProp vpos;
  McdFont font;
  List<McdLine> lines;

  McdParagraph(this.vpos, this.font, this.lines);
}

// class McdData {
//   final McdFontData font;
// }
