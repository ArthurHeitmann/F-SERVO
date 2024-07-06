
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../../../fileTypeUtils/ftb/ftbIO.dart';
import '../../../fileTypeUtils/mcd/fontAtlasGeneratorTypes.dart';
import '../../../fileTypeUtils/wta/wtaReader.dart';
import '../../../utils/assetDirFinder.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../changesExporter.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import 'McdFileData.dart';

class FtbFileData extends OpenFileData {
  FtbData? ftbData;

  FtbFileData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.ftb, icon: Icons.subtitles);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    ftbData?.dispose();
    ftbData = await FtbData.fromFtbFile(path);
    await ftbData!.extractTextures();

    await super.load();
  }

  @override
  Future<void> save() async {
    await ftbData?.save();
    var datDir = dirname(path);
    changedDatFiles.add(datDir);
    await super.save();
  }

  @override
  void dispose() {
    ftbData?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = FtbFileData(name.value, path, secondaryName: secondaryName.value);
    snapshot.ftbData = ftbData?.copy();
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var ftbSnapshot = snapshot as FtbFileData;
    name.value = ftbSnapshot.name.value;
    secondaryName.value = ftbSnapshot.secondaryName.value;
    ftbData = ftbSnapshot.ftbData?.copy();
    optionalInfo = ftbSnapshot.optionalInfo;
    loadingState.value = ftbSnapshot.loadingState.value;
    setHasUnsavedChanges(ftbSnapshot.hasUnsavedChanges.value);
    overrideUuid(ftbSnapshot.uuid);
  }
}

class FtbTexture {
  int width, height;
  int u_1, u_2;
  String? extractedPngPath;

  FtbTexture(this.width, this.height, this.u_1, this.u_2);
}

class FtbChar {
  String char;
  int texId;
  int width;
  int height;
  int u;
  int v;

  FtbChar(this.char, this.texId, this.width, this.height, this.u, this.v);
}

class FtbData extends ChangeNotifier {
  final List<int> _magic;
  List<FtbTexture> textures;
  List<FtbChar> chars;
  String path;
  String wtaPath;
  String wtpPath;
  WtaFile wtaFile;
  int fontId;

  FtbData(this._magic, this.textures, this.chars, this.path, this.wtaPath, this.wtpPath, this.wtaFile)
      : fontId = int.parse(basenameWithoutExtension(path).substring(5));

  static Future<FtbData> fromFtbFile(String path) async{
    var name = basenameWithoutExtension(path);
    var datDir = dirname(path);
    var wtaPath = join(datDir, "$name.wta");
    if (!await File(wtaPath).exists()) {
      showToast("WTA file not found");
      throw Exception("WTA file not found");
    }
    var dttDir = "${datDir.substring(0, datDir.length - 4)}.dtt";
    var wtpPath = join(dttDir, "$name.wtp");
    if (!await File(wtpPath).exists()) {
      showToast("WTP file not found");
      throw Exception("WTP file not found");
    }
    var wtaFile = await WtaFile.readFromFile(wtaPath);

    if (basenameWithoutExtension(path).contains("font_00"))
      showToast("font_00 is not used in-game and not supported");

    var ftbFile = await FtbFile.fromFile(path);
    var ftbData = FtbData(
      ftbFile.header.magic,
      ftbFile.textures.map((e) => FtbTexture(e.width, e.height, e.u2, e.u22)).toList(),
      ftbFile.chars.map((e) => FtbChar(e.char, e.texId, e.width, e.height, e.u, e.v)).toList(),
      path,
      wtaPath, wtpPath,
      wtaFile,
    );

    if (McdData.availableFonts.isEmpty)
      await McdData.loadAvailableFonts();

    if (!McdData.fontOverrides.any((fo) => fo.fontIds.contains(ftbData.fontId))) {
      var fontOverride = McdFontOverride(ftbData.fontId);
      McdData.fontOverrides.add(fontOverride);
    }

    return ftbData;
  }

  Future<Tuple2<List<FontAtlasGenSymbol>, int>> generateTextureBatch(int i, List<FtbChar> chars, CliFontOptions font, String ddsPath) async {
    List<CliImgOperation> imgOperations = [];
    var fallbackSymbols = McdData.availableFonts[fontId]?.supportedSymbols;
    for (int i = 0; i < chars.length; i++) {
      var char = chars[i];
      CliImgOperationDrawFromTexture? fallback;
      var fontSymbol = fallbackSymbols?[char.char.codeUnitAt(0)];
      if (fontSymbol != null) {
        fallback = CliImgOperationDrawFromTexture(
          i, 0,
          fontSymbol.x, fontSymbol.y,
          fontSymbol.width, fontSymbol.height,
        );
      }
      imgOperations.add(CliImgOperationDrawFromFont(
        i, char.char, fontId, fallback,
      ));
    }

    var fallbackTexPath = McdData.availableFonts[fontId]!.atlasTexturePath;
    var texPngPath = "${ddsPath.substring(0, ddsPath.length - 4)}.png";
    var cliArgs = FontAtlasGenCliOptions(
        texPngPath, [fallbackTexPath],
        McdData.fontAtlasLetterSpacing.value.toInt(),
        2048,
        { fontId: font }, imgOperations
    );
    var cliJson = jsonEncode(cliArgs.toJson());
    cliJson = base64Encode(utf8.encode(cliJson));

    // run cli tool
    var cliToolPath = join(assetsDir!, "FontAtlasGenerator", "__init__.py");
    var cliToolProcess = await Process.start(pythonCmd!, [cliToolPath]);
    cliToolProcess.stdin.writeln(cliJson);
    cliToolProcess.stdin.close();
    var stdout = cliToolProcess.stdout.transform(utf8.decoder).join();
    var stderr = cliToolProcess.stderr.transform(utf8.decoder).join();
    if (await cliToolProcess.exitCode != 0) {
      showToast("Font atlas generator failed");
      print(await stdout);
      print(await stderr);
      throw Exception("Font atlas generator failed for file $path");
    }
    // parse cli output
    FontAtlasGenResult atlasInfo;
    try {
      var atlasInfoJson = jsonDecode(await stdout);
      atlasInfo = FontAtlasGenResult.fromJson(atlasInfoJson);
    } catch (e) {
      showToast("Font atlas generator failed");
      print(e);
      print(await stdout);
      print(await stderr);
      throw Exception("Font atlas generator failed");
    }
    // convert png to dds (.wtp)
    var result = await Process.run(
      magickBinPath!,
      [texPngPath, "-define", "dds:mipmaps=0", ddsPath],
    );
    if (result.exitCode != 0) {
      showToast("ImageMagick failed");
      print(result.stdout);
      print(result.stderr);
      throw Exception("ImageMagick failed");
    }

    print("Generated font atlas $i with ${atlasInfo.symbols.length} symbols");

    return Tuple2(atlasInfo.symbols.values.toList(), atlasInfo.texSize);
  }

  Future<void> generateTexture() async {
    if (!await hasMagickBins()) {
      showToast("No ImageMagick binaries found");
      throw Exception("No ImageMagick binaries found");
    }
    if (!await hasPython()) {
      showToast("No Python found");
      throw Exception("No Python found");
    }
    if (!await hasPipDeps()) {
      showToast("Couldn't install Python dependencies");
      throw Exception("Couldn't install Python dependencies");
    }

    var fontOverrideRes = McdData.fontOverrides.where((fo) => fo.fontIds.contains(fontId));
    var fontOverride = fontOverrideRes.isNotEmpty ? fontOverrideRes.first : null;
    if (fontOverride == null) {
      showToast("No font override for font $fontId");
      throw Exception("No font override for font $fontId");
    }
    if (!await File(fontOverride.fontPath.value).exists()) {
      showToast("Font path is invalid");
      throw Exception("Font path is invalid");
    }

    // generate cli json args
    var heightScale = fontOverride.heightScale.value.toDouble();
    var fontHeight = McdData.availableFonts[fontId]!.fontHeight * heightScale;
    var scaleFact = 44 / fontHeight;
    CliFontOptions? font = CliFontOptions(
      fontOverride.fontPath.value,
      fontHeight.toInt(),
      fontOverride.scale.value.toDouble(),
      (fontOverride.letXPadding.value * scaleFact).toInt(),
      (fontOverride.letYPadding.value * scaleFact).toInt(),
      (fontOverride.xOffset.value * scaleFact).toDouble(),
      (fontOverride.yOffset.value * scaleFact).toDouble(),
    );
    const textureBatchesCount = 4;
    var charsPerBatch = (chars.length / textureBatchesCount).ceil();
    List<List<FtbChar>> charsBatches = [];
    for (int i = 0; i < chars.length; i += charsPerBatch) {
      var batch = chars.sublist(i, min(i + charsPerBatch, chars.length));
      charsBatches.add(batch);
    }
    var ddsPaths = List.generate(textureBatchesCount, (i) => join(dirname(wtpPath), "${basename(wtpPath)}_$i.dds"));
    var textureBatches = await Future.wait(List.generate(
        textureBatchesCount,
            (i) => generateTextureBatch(i, charsBatches[i], font, ddsPaths[i])
    ));
    var wtpSizes = await Future.wait(ddsPaths.map((e) => File(e).length()));

    // update .wta
    var textureOffsets = [0];
    for (int i = 1; i < wtpSizes.length; i++)
      textureOffsets.add(textureOffsets[i - 1] + wtpSizes[i - 1]);
    wtaFile.textureOffsets = textureOffsets;
    wtaFile.textureSizes = wtpSizes;
    // add new idx, flag info entries
    for (int i = wtaFile.header.numTex; i < textureBatches.length; i++) {
      wtaFile.header.numTex++;
      wtaFile.textureIdx.add(randomId());
      wtaFile.textureFlags.add(wtaFile.textureFlags.last);
      wtaFile.textureInfo.add(wtaFile.textureInfo.last);
    }
    wtaFile.updateHeader();
    await wtaFile.writeToFile(wtaPath);
    // update .wtp
    var wtpBytes = ByteData(textureOffsets.last + wtpSizes.last);
    for (int i = 0; i < ddsPaths.length; i++) {
      var ddsBytes = await File(ddsPaths[i]).readAsBytes();
      wtpBytes.buffer.asUint8List().setAll(textureOffsets[i], ddsBytes);
    }
    await File(wtpPath).writeAsBytes(wtpBytes.buffer.asUint8List());
    // export dtt
    var dttPath = dirname(wtpPath);
    await exportDat(dttPath);

    // update texture sizes
    for (int i = 0; i < textureBatches.length; i++) {
      var texSize = textureBatches[i].item2;
      if (i >= textures.length) {
        textures.add(FtbTexture(texSize, texSize, textures.last.u_1, textures.last.u_2));
      }
      var texture = textures[i];
      texture.width = texSize;
      texture.height = texSize;
      texture.extractedPngPath = "${ddsPaths[i].substring(0, ddsPaths[i].length - 4)}.png";
    }

    var batchI = 0;
    var batchJ = 0;
    for (var i = 0; i < chars.length; i++) {
      var char = chars[i];
      var symbol = textureBatches[batchI].item1[batchJ];
      char.u = symbol.x;
      char.v = symbol.y;
      char.width = symbol.width;
      char.height = symbol.height;
      char.texId = batchI;
      batchJ++;
      if (batchJ >= textureBatches[batchI].item1.length) {
        batchI++;
        batchJ = 0;
      }
    }

    notifyListeners();

    print("FTB font atlas generated");
  }

  Future<void> save() async {
    await generateTexture();

    var charsOffset = 0x88 + textures.length * 0x10;
    var ftbHeader = FtbFileHeader(_magic, textures.length, 0, chars.length, 0x88, charsOffset, charsOffset);

    var ftbTextures = textures.map((tex) => FtbFileTexture(0,
        tex.width, tex.height,
        0, tex.u_1, tex.u_2
    )).toList();

    var ftbChars = chars.map((e) => FtbFileChar(
        e.char.codeUnitAt(0), e.texId, e.width, e.height,
        e.u, e.v
    )).toList();

    var ftbFile = FtbFile(ftbHeader, ftbTextures, ftbChars);
    await ftbFile.writeToFile(path);

    McdData.fontChanges.notifyListeners();

    print("FTB saved");
  }

  Future<void> extractTextures() async {
    if (!await hasMagickBins()) {
      showToast("No ImageMagick binaries found");
      throw Exception("No ImageMagick binaries found");
    }

    var wtpBytes = await File(wtpPath).readAsBytes();
    var extractDir = join(dirname(wtpPath), "textures");
    await Directory(extractDir).create(recursive: true);
    for (var i = 0; i < textures.length; i++) {
      // extract dds
      var texStart = wtaFile.textureOffsets[i];
      var texEnd = texStart + wtaFile.textureSizes[i];
      var texBytes = wtpBytes.sublist(texStart, texEnd);
      var ddsSavePath = join(extractDir, "$i.dds");
      await File(ddsSavePath).writeAsBytes(texBytes);
      // convert dds to png
      var pngSavePath = join(extractDir, "$i.png");
      var result = await Process.run(magickBinPath!, [ddsSavePath, pngSavePath]);
      if (result.exitCode != 0) {
        showToast("Failed to convert dds to png");
        print(result.stdout);
        print(result.stderr);
        throw Exception("ImageMagick failed");
      }
      textures[i].extractedPngPath = pngSavePath;
    }
  }

  McdFont asMcdFont(int forTexIndex) {
    return McdFont(
      fontId,
      chars[0].width, chars[0].height, 0,
      {
        for (var c in chars.where((c) => c.texId == forTexIndex))
          c.char.codeUnitAt(0): McdFontSymbol(
              c.char.codeUnitAt(0), c.char,
              c.u, c.v,
              c.width, c.height,
              fontId
          )
      },
    );
  }

  FtbData copy() {
    return FtbData(
      _magic,
      textures.map((e) => FtbTexture(e.width, e.height, e.u_1, e.u_2)).toList(),
      chars.map((e) => FtbChar(e.char, e.texId, e.width, e.height, e.u, e.v)).toList(),
      path, wtaPath, wtpPath, wtaFile,
    );
  }
}

