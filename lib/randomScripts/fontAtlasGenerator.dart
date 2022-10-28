
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';
import 'package:path/path.dart';

const extractPath = r"D:\Cloud\Documents\Programming\dart\nier_scripts_editor\extractedFonts";

double readNum(num n) => n.toDouble();

Future<void> genAtlas(String fontDir) async {
  print("Generating atlas for $fontDir");
  var metaJson = jsonDecode(await File(join(fontDir, "_meta.json")).readAsString());
  var symbols = (metaJson["symbols"] as List).cast<Map<String, dynamic>>();
  
  // determine atlas size
  var fontHeight = readNum(metaJson["height"]);
  var allCharWidths = symbols.map((e) => readNum(e["width"])).toList();
  var totalWidth = allCharWidths.fold<double>(0, (a, b) => a + b);
  var avrWidth = totalWidth / allCharWidths.length;
  avrWidth *= 1.05; // for safety
  var allCharsArea = symbols.length * avrWidth * fontHeight * 1.025;
  double atlasWidth = 256;
  double atlasHeight = 256;
  while (atlasWidth * atlasHeight < allCharsArea) {
    if (atlasWidth == atlasHeight)
      atlasWidth *= 2;
    else
      atlasHeight *= 2;
  }

  // generate atlas
  // { code, char, x, y, width, height }[]
  List<Map<String, dynamic>> atlasSymbols = [];
  var atlas = Image(atlasWidth.toInt(), atlasHeight.toInt());
  double x = 0;
  double y = 0;
  for (var symbol in symbols) {
    var charCode = symbol["code"] as int;
    var char = symbol["char"] as String;
    var width = readNum(symbol["width"]);
    var height = readNum(symbol["height"]);
    var imgPath = join(fontDir, symbol["fileName"]);
    var charImage = decodePng(await File(imgPath).readAsBytes())!;
    if (charImage.width != width || charImage.height != height)
      print("Warning: $imgPath has wrong size ${charImage.width} x ${charImage.height} instead of $width x $height");
    copyInto(atlas, charImage, dstX: x.toInt(), dstY: y.toInt());
    atlasSymbols.add({
      "code": charCode,
      "char": char,
      "x": x,
      "y": y,
      "width": width.toInt(),
      "height": height.toInt(),
    });
    x += width.toInt();
    if (x + avrWidth > atlasWidth) {
      x = 0;
      y += fontHeight.toInt();
      if (y + fontHeight > atlasHeight)
        throw Exception("Atlas is too small");
    }
  }

  await File(join(fontDir, "_atlas.png")).writeAsBytes(encodePng(atlas));
  
  var atlasJsonObj = {
    "fontWidth": metaJson["width"].toInt(),
    "fontHeight": metaJson["height"].toInt(),
    "fontBelow": metaJson["below"].toInt(),
    "symbols": atlasSymbols,
  };
  var atlasJson = const JsonEncoder.withIndent("\t").convert(atlasJsonObj);
  await File(join(fontDir, "_atlas.json")).writeAsString(atlasJson);

  print("Generated atlas for $fontDir with ${atlasSymbols.length} symbols");
}

void main() async {
  var fontDirs = Directory(extractPath)
    .listSync()
    .whereType<Directory>();

  List<Future<void>> futures = [];
  for (var fontDir in fontDirs) {
    // await genAtlas(fontDir.path);
    futures.add(genAtlas(fontDir.path));
  }
  await Future.wait(futures);

  print("Done");
}
