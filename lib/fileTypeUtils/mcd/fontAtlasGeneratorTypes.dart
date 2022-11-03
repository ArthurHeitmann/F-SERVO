
abstract class CliImgOperation {
  final int type;
  final int id;

  CliImgOperation(this.type, this.id);

  Map<String, dynamic> toJson();
}

class CliImgOperationDrawFromTexture extends CliImgOperation {
  final int srcTexId;
  final int srcX;
  final int srcY;
  final int width;
  final int height;

  CliImgOperationDrawFromTexture(int id, this.srcTexId, this.srcX, this.srcY, this.width, this.height) : super(0, id);

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "id": id.toString(),
      "srcTexId": srcTexId,
      "srcX": srcX,
      "srcY": srcY,
      "width": width,
      "height": height,
    };
  }
}

class CliImgOperationDrawFromFont extends CliImgOperation {
  final String drawChar;
  final int charFontId;

  CliImgOperationDrawFromFont(int id, this.drawChar, this.charFontId) : super(1, id);

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "id": id.toString(),
      "drawChar": drawChar,
      "charFontId": charFontId.toString(),
    };
  }
}

/*
class FontOptions:
	fontPath: str
	font: FreeTypeFont
	fontHeight: int
	fontScale: int
	letXOffset: int
	letYOffset: int
*/
class CliFontOptions {
  final String fontPath;
  final int fontHeight;
  final double fontScale;
  final double letXOffset;
  final double letYOffset;

  CliFontOptions(this.fontPath, this.fontHeight, this.fontScale, this.letXOffset, this.letYOffset);

  Map<String, dynamic> toJson() {
    return {
      "path": fontPath,
      "height": fontHeight,
      "scale": fontScale,
      "letXOffset": letXOffset,
      "letYOffset": letYOffset,
    };
  }
}

class FontAtlasGenCliOptions {
  final String dstTexPath;
  final List<String> srcTexPaths;
  final Map<int, CliFontOptions> fonts;
  final List<CliImgOperation> imgOperations;

  FontAtlasGenCliOptions(this.dstTexPath, this.srcTexPaths, this.fonts, this.imgOperations);

  Map<String, dynamic> toJson() {
    return {
      "dstTexPath": dstTexPath,
      "srcTexPaths": srcTexPaths,
      "fonts": { for (final entry in fonts.entries) entry.key.toString(): entry.value.toJson() },
      "operations": imgOperations.map((e) => e.toJson()).toList(),
    };
  }
}

class FontAtlasGenSymbol {
  final int x;
  final int y;
  final int width;
  final int height;

  FontAtlasGenSymbol.fromJson(Map<String, dynamic> map) :
    x = map["x"],
    y = map["y"],
    width = map["width"],
    height = map["height"];
}

class FontAtlasGenResult {
  final int texSize;
  final Map<int, FontAtlasGenSymbol> symbols;

  FontAtlasGenResult.fromJson(Map<String, dynamic> map) :
    texSize = map["size"],
    symbols = {
      for (final entry in (map["symbols"] as Map).entries)
        int.parse(entry.key): FontAtlasGenSymbol.fromJson(entry.value)
    };
}
