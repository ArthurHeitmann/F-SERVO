
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
  final double resolutionScale;

  CliImgOperationDrawFromTexture(int id, this.srcTexId, this.srcX, this.srcY, this.width, this.height, this.resolutionScale) : super(0, id);

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
      "resolutionScale": resolutionScale,
    };
  }
}

class CliImgOperationDrawFromFont extends CliImgOperation {
  final String drawChar;
  final int charFontId;
  final CliImgOperationDrawFromTexture? fallback;

  CliImgOperationDrawFromFont(int id, this.drawChar, this.charFontId, this.fallback) : super(1, id);

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "id": id.toString(),
      "drawChar": drawChar,
      "charFontId": charFontId.toString(),
      if (fallback != null)
        "fallback": fallback!.toJson(),
    };
  }
}

class CliFontOptions {
  final String fontPath;
  final int fontHeight;
  final int letXPadding;
  final int letYPadding;
  final double letXOffset;
  final double letYOffset;
  final double resolutionScale;
  final int strokeWidth;
  final double rgbBlurSize;

  CliFontOptions(this.fontPath, this.fontHeight, this.letXPadding, this.letYPadding, this.letXOffset, this.letYOffset, this.resolutionScale, this.strokeWidth, this.rgbBlurSize);

  Map<String, dynamic> toJson() {
    return {
      "path": fontPath,
      "height": fontHeight,
      "letXPadding": letXPadding,
      "letYPadding": letYPadding,
      "letXOffset": letXOffset,
      "letYOffset": letYOffset,
      "resolutionScale": resolutionScale,
      "strokeWidth": strokeWidth,
      "rgbBlurSize": rgbBlurSize,
    };
  }
}

class FontAtlasGenCliOptions {
  final String dstTexPath;
  final List<String> srcTexPaths;
  final int letterSpacing;
  final int minTexSize;
  final Map<int, CliFontOptions> fonts;
  final List<CliImgOperation> imgOperations;

  FontAtlasGenCliOptions(this.dstTexPath, this.srcTexPaths, this.letterSpacing, this.minTexSize, this.fonts, this.imgOperations);

  Map<String, dynamic> toJson() {
    return {
      "srcTexPaths": srcTexPaths,
      "dstTexPath": dstTexPath,
      "letterSpacing": letterSpacing,
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

class FontAtlasGenResultFontParams {
  final double scale;

  FontAtlasGenResultFontParams.fromJson(Map<String, dynamic> map) :
    scale = map["scale"];
}

class FontAtlasGenResult {
  final int texSize;
  final Map<int, FontAtlasGenResultFontParams> fonts;
  final Map<int, FontAtlasGenSymbol> symbols;

  FontAtlasGenResult.fromJson(Map<String, dynamic> map) :
    texSize = map["size"],
    fonts = {
      for (final entry in (map["fontParams"] as Map).entries)
        int.parse(entry.key): FontAtlasGenResultFontParams.fromJson(entry.value)
    },
    symbols = {
      for (final entry in (map["symbols"] as Map).entries)
        int.parse(entry.key): FontAtlasGenSymbol.fromJson(entry.value)
    };
}
