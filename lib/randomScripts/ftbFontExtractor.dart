
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';
import 'package:path/path.dart';

import '../fileTypeUtils/ftb/ftbIO.dart';
import '../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../fileTypeUtils/wta/wtaReader.dart';

const rootDir = r"D:\delete\mods\na\blender\extracted\data009.cpk_unpacked\font";
const magickPath = r"D:\Cloud\Documents\Programming\dart\nier_scripts_editor\assets\bins\magick.exe";
const extractPath = r"D:\Cloud\Documents\Programming\dart\nier_scripts_editor\extractedFonts";

// { fontId: processedLetterCodes[] }
Map<int, Set<int>> fontMap = {};
// {
//   fontId: {
//     id, width, height, below, horizontal,
//     usedBy: [mcdNames],
//     symbols: [
//       { fileName, code, char, idx, width, height, above, below, horizontal }
//     ]
//   }
// }
Map<int, Map<String, dynamic>> charsMeta = {};

const invalidFileCharacters = { "/", "\n", "\r", "\t", "\x00", "\f", "`", "?", "*", "\\", "<", ">", "|", "\"", ":" };
Future<bool> checkIfFileIsValid(String dir, String name) async {
  if (invalidFileCharacters.any((c) => name.contains(c)))
    return false;
  var file = File(join(dir, name));
  try {
    if (await file.exists())
      return true;
    await file.create();
    return true;
  } catch (e) {
    return false;
  }
}

Future<List<List<int>>> extractWtaWtpTextures(String wtaPath) async {
  var wta = await WtaFile.readFromFile(wtaPath);
  var wtpPath = wtaPath.replaceFirst(".wta", ".wtp");
  wtpPath = wtpPath.replaceFirst(".dat", ".dtt");
  var wtpFile = (await File(wtpPath).readAsBytes()).buffer;
  
  List<List<int>> textures = [];
  for (var i = 0; i < wta.header.numTex; i++) {
    var texOffset = wta.textureOffsets[i];
    var texSize = wta.textureSizes[i];
    var texData = wtpFile.asUint8List(texOffset, texSize);
    textures.add(texData);
  }
  return textures;
}

Future<void> processFile(String ftbPath) async {
  print("Processing $ftbPath");
  var t1 = DateTime.now();

  int fontId = int.parse(RegExp(r"_(\d+)\.dat").firstMatch(ftbPath)!.group(1)!);
  if (fontId == 0)
    return;
  if (!fontMap.containsKey(fontId))
    fontMap[fontId] = {};

  // get texture info
  var wtaPath = "${ftbPath.substring(0, ftbPath.length - 4)}.wta";
  if (!await File(wtaPath).exists())
    throw Exception("Texture file $wtaPath does not exist");

  // dds to png
  List<Image> pngFiles = [];
  var ddsBytes = await extractWtaWtpTextures(wtaPath);
  for (int i = 0; i < ddsBytes.length; i++) {
    var ddsEntry = ddsBytes[i];
    var tmpDdsPath = join(dirname(ftbPath), "$i.dds");
    var tmpPngPath = join(dirname(ftbPath), "$i.png");
    await File(tmpDdsPath).writeAsBytes(ddsEntry);
    var result = await Process.run(magickPath, [ tmpDdsPath, tmpPngPath ]);
    if (result.exitCode != 0)
      throw Exception("Failed to convert dds to png: ${result.stderr}");
    pngFiles.add(decodePng(await File(tmpPngPath).readAsBytes())!);
  }

  // get ftb data
  var ftbBytes = await ByteDataWrapper.fromFile(ftbPath);
  var ftb = FtbFile.read(ftbBytes);
  
  for (var i = 0; i < ftb.header.charsCount; i++) {
    var ftbChar = ftb.chars[i];
    // check if already processed
    var charCode = ftbChar.c;

    if (fontMap[fontId]!.contains(charCode)) {
      continue;
    }
    fontMap[fontId]!.add(charCode);

    // prepare for crop
    var cropU1 = ftbChar.u;
    var cropV1 = ftbChar.v;
    var width = ftbChar.width;
    var height = ftbChar.height;
    var below = charsMeta[fontId]!["symbols"][0]["below"];
    String char = ftbChar.char;
    var outDir = join(extractPath, fontId.toString());
    var outName = "${charCode}_$char.png";
    if (!await checkIfFileIsValid(outDir, outName))
      outName = "${charCode}_.png";
    var outFileName = join(outDir, outName);
    charsMeta[fontId]!["symbols"].add({
      "fileName": outName,
      "code": charCode,
      "char": char,
      "width": width,
      "height": height,
      "above": 0,
      "below": below,
      "horizontal": 0,
    });

    // crop and save
    var crop = copyCrop(pngFiles[ftbChar.texId], cropU1, cropV1, width, height);
    await File(outFileName).writeAsBytes(encodePng(crop));
  }

  var t2 = DateTime.now();
  print("Processed $ftbPath in ${t2.difference(t1).inSeconds}s");
}

void main(List<String> args) async {
  var existingJsonFiles = await Directory(extractPath)
    .list(recursive: true)
    .where((e) => e.path.endsWith("_meta.json"))
    .map((e) => e.path)
    .toList();
  for (var json in existingJsonFiles) {
    var fontId = int.parse(basename(dirname(json)));
    var jsonFile = File(json);
    var jsonContent = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
    charsMeta[fontId] = jsonContent;
    fontMap[fontId] = (jsonContent["symbols"] as List)
      .map((e) => e["code"] as int)
      .toSet();
  }
  var ftbFiles = await Directory(rootDir)
    .list(recursive: true)
    .where((e) => e.path.endsWith(".ftb"))
    .map((e) => e.path)
    .toList();
  
  // List<Future<void>> futures = [];
  for (var mcd in ftbFiles) {
    // futures.add(processFile(mcd));
    await processFile(mcd);
  }
  // await Future.wait(futures);

  for(var fontId in charsMeta.keys) {
    var meta = charsMeta[fontId]!;
    meta["usedBy"]!.sort();
    meta["symbols"].sort((a, b) => (a["code"] - b["code"]) as int);
    var outDir = join(extractPath, fontId.toString());
    var json = const JsonEncoder.withIndent("\t").convert(meta);
    await File(join(outDir, "_meta.json")).writeAsString(json);
  }
  print("Done");
}
