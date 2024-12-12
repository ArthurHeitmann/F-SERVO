
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:path/path.dart';

import '../fileTypeUtils/mcd/mcdIO.dart';
import '../fileTypeUtils/textures/ddsConverter.dart';
import '../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../fileTypeUtils/wta/wtaReader.dart';
import '../utils/assetDirFinder.dart';

const rootDir = r"D:\delete\cpk_extracted";
const magickPath = r"D:\Cloud\Documents\Programming\dart\F-SERVO\assets\bins\magick.exe";
const extractPath = r"D:\Cloud\Documents\Programming\dart\F-SERVO\extractedFonts";

// const langs = { "de", "es", "fr", "it", "us" };
// final langMatcher = RegExp(r"(de|es|fr|it|us)\.dat");
const langPrio = [
  "us",
  "de",
  "fr",
  "it",
  "pt",
  "jp",
];

// { fontId: processedLetterCodes[] }
Map<int, Set<int>> fontMap = {};
// {
//   fontId: {
//     width, height, below, horiz,
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

class TimingArea {
  final String name;
  int millis = 0;
  DateTime? _start;
  int count = 0;

  TimingArea(this.name);

  void start() {
    _start = DateTime.now();
  }

  void stop() {
    if (_start == null)
      return;
    millis += DateTime.now().difference(_start!).inMilliseconds;
    count++;
    _start = null;
  }

  @override
  String toString() {
    return "$name x$count: ${millis}ms";
  }
}

final tTexInfo = TimingArea("texInfo");
final tMcdData = TimingArea("mcdData");
final tDupeCheck = TimingArea("dupeCheck");
final tCropPrep = TimingArea("cropPrep");
final tCrop = TimingArea("crop");

Future<void> processFile(String mcd) async {
  print("Processing $mcd");
  var t1 = DateTime.now();
  // var lang = langMatcher.firstMatch(mcd)?.group(1) ?? "jp";
  // if (!fontMap.containsKey(lang))
  //   fontMap[lang] = {};

  // get texture info
  tTexInfo.start();
  var textureFile = "${mcd.substring(0, mcd.length - 4)}.wtb";
  textureFile = textureFile.replaceFirst(".dat", ".dtt");
  if (!await File(textureFile).exists()) {
    print("Texture file not found: $textureFile");
    return;
  }
  var wtbBytes = await ByteDataWrapper.fromFile(textureFile);
  var wtb = WtaFile.read(wtbBytes);
  wtbBytes.position = wtb.textureOffsets[0];
  var texBytes = wtbBytes.makeSubView(wtb.textureSizes[0]);
  texBytes.position = 0xC;
  var texHeight = texBytes.readUint32();
  var texWidth = texBytes.readUint32();
  // dds to png
  // var pngPath = "$textureFile.png";
  var pngBytes = await texToPngInMemory(Uint8List.view(wtbBytes.buffer, wtb.textureOffsets[0]));
  var pngFile = decodePng(pngBytes!)!;
  tTexInfo.stop();

  // get mcd data
  tMcdData.start();
  var mcdBytes = await ByteDataWrapper.fromFile(mcd);
  var mcdHeader = McdFileHeader.read(mcdBytes);
  mcdBytes.position = mcdHeader.glyphsOffset;
  List<McdFileGlyph> glyphs = List.generate(
    mcdHeader.symbolsCount,
    (index) => McdFileGlyph.read(mcdBytes)
  );
  mcdBytes.position = mcdHeader.fontsOffset;
  List<McdFileFont> fonts = List.generate(
    mcdHeader.fontsCount,
    (index) => McdFileFont.read(mcdBytes)
  );
  mcdBytes.position = mcdHeader.symbolsOffset;
  List<McdFileSymbol> symbols = List.generate(
    mcdHeader.symbolsCount,
    (index) => McdFileSymbol.read(mcdBytes, fonts, glyphs)
  );
  tMcdData.stop();
  for (var i = 0; i < symbols.length; i++) {
    // check if already processed
    tDupeCheck.start();
    int fontId = symbols[i].fontId;
    var charCode = symbols[i].charCode;
    var glyph = glyphs[symbols[i].glyphId];

    var datName = basename(dirname(mcd));
    var mcdName = join(datName, basename(mcd));
    if (!fontMap.containsKey(fontId)) {
      fontMap[fontId] = {};
      var font = fonts.firstWhere((f) => f.id == fontId);
      charsMeta[fontId] = {
        "width": font.width,
        "height": font.height,
        "below": font.horizontalSpacing,
        "horizontal": font.verticalSpacing,
        "usedBy": [],
        "symbols": []
      };
    }
    if (!charsMeta[fontId]!["usedBy"]!.contains(mcdName))
      charsMeta[fontId]!["usedBy"]!.add(mcdName);
    if (fontMap[fontId]!.contains(charCode)) {
      continue;
    }
    fontMap[fontId]!.add(charCode);
    tDupeCheck.stop();

    // prepare for crop
    tCropPrep.start();
    var cropU1 = (texWidth * glyph.u1).round();
    var cropV1 = (texHeight * glyph.v1).round();
    String char = symbols[i].char;
    var outDir = join(extractPath, fontId.toString());
    var outName = "${charCode}_$char.png";
    if (!await checkIfFileIsValid(outDir, outName))
      outName = "${charCode}_.png";
    var outFileName = join(outDir, outName);
    await Directory(dirname(outFileName)).create(recursive: true);
    charsMeta[fontId]!["symbols"].add({
      "fileName": outName,
      "code": charCode,
      "char": String.fromCharCode(charCode),
      "width": glyph.width,
      "height": glyph.height,
      "above": glyph.null0,
      "below": glyph.horizontalSpacing,
      "horizontal": glyph.null1,
    });
    tCropPrep.stop();

    // crop and save
    tCrop.start();
    var crop = copyCrop(pngFile, x: cropU1, y: cropV1, width: glyph.width.toInt(), height: glyph.height.toInt());
    await File(outFileName).writeAsBytes(encodePng(crop));
    tCrop.stop();
  }

  var t2 = DateTime.now();
  print("Processed $mcd in ${t2.difference(t1).inSeconds}s");
}

void main(List<String> args) async {
  print("Starting");
  await findAssetsDir();
  var mcdFiles = await Directory(rootDir)
    .list(recursive: true)
    .where((e) => e.path.endsWith(".mcd"))
    .map((e) => e.path)
    .toList();
  var allMcdsAnnotated = mcdFiles.map((e) {
    var pathParts = e.split(RegExp(r"[/\\]"));
    var cpkName = pathParts.where((part) => part.contains(".cpk_extracted")).first;
    var datName = pathParts.where((part) => part.endsWith(".dat")).last;
    var lang = datName.split("_").skip(1).firstOrNull?.split(".").first ?? "jp.dat";
    var langId = langPrio.indexOf(lang);
    if (langId == -1)
      langId = langPrio.length;
    return (langId, cpkName, datName, e);
  }).toList();
  allMcdsAnnotated.sort((a, b) {
    var cmp = a.$1.compareTo(b.$1);
    if (cmp != 0)
      return cmp;
    cmp = a.$2.compareTo(b.$2);
    if (cmp != 0)
      return cmp;
    cmp = a.$3.compareTo(b.$3);
    if (cmp != 0)
      return cmp;
    return a.$4.compareTo(b.$4);
  });
  
  List<List<String>> mcdBatches = [];
  const batchSize = 12;
  for (int i = 0; i < allMcdsAnnotated.length; i += batchSize) {
    mcdBatches.add(allMcdsAnnotated.skip(i).take(batchSize).map((e) => e.$4).toList());
  }
  for (var batch in mcdBatches) {
    List<Future<void>> futures = [];
    for (var mcd in batch) {
      futures.add(processFile(mcd));
    }
    await Future.wait(futures);
  }

  // List<Future<void>> futures = [];
  // for (var mcd in allMcdsAnnotated) {
    // futures.add(processFile(mcd.$4));
  // }
  // await Future.wait(futures);

  for(var fontId in charsMeta.keys) {
    var meta = charsMeta[fontId]!;
    meta["usedBy"]!.sort();
    meta["symbols"].sort((a, b) => (a["code"] - b["code"]) as int);
    var outDir = join(extractPath, fontId.toString());
    var json = const JsonEncoder.withIndent("\t").convert(meta);
    await File(join(outDir, "_meta.json")).writeAsString(json);
  }

  print(tTexInfo);
  print(tMcdData);
  print(tDupeCheck);
  print(tCropPrep);
  print(tCrop);
  print("Done");
}
