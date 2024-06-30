
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../../../fileTypeUtils/ftb/ftbIO.dart';
import '../../../fileTypeUtils/textures/fontAtlasGenerator.dart';
import '../../../fileTypeUtils/textures/fontAtlasGeneratorTypes.dart';
import '../../../fileTypeUtils/textures/ddsConverter.dart';
import '../../../fileTypeUtils/ttf/ttf.dart';
import '../../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../../fileTypeUtils/wta/wtaReader.dart';
import '../../../utils/assetDirFinder.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../changesExporter.dart';
import '../../events/statusInfo.dart';
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

    await super.load();
  }

  @override
  Future<void> save() async {
    await ftbData?.save();
    var datDir = dirname(path);
    changedDatFiles.add(datDir);
    await super.save();
    await processChangedFiles();
  }

  Future<void> addCharsFromFront(String fontPath) async {
    Iterable<String> fontChars;
    try {
      var bytes = await ByteDataWrapper.fromFile(fontPath);
      var ttf = TtfFile.read(bytes);
      fontChars = ttf.allChars();
    } catch (e) {
      showToast("Failed to read font file");
      rethrow;
    }
    ftbData!.pendingNewChars.clear();
    for (var char in fontChars) {
      if (ftbData!.chars.any((c) => c.char == char))
        continue;
      var code = char.codeUnitAt(0);
      if (code < 0x20 || code >= 0x7F && code < 0xA0 || code >= 0x7FFF)
        continue;
      ftbData!.pendingNewChars.add(FtbPendingChar(char, fontPath));
    }
    var newChars = ftbData!.pendingNewChars.map((c) => c.char).toList();
    if (newChars.isEmpty) {
      showToast("No new chars to add");
      return;
    }
    await save();
    showToast("Added ${newChars.length} new chars");
    messageLog.add("New chars: ${newChars.join(", ")}");
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
  String? extractedPngPath;

  FtbTexture(this.width, this.height);
}

abstract class FtbCharBase {
  final String char;

  FtbCharBase(this.char);

  CliImgOperation getImgOperation(int i, bool hasOverride, CliImgOperationDrawFromTexture? Function() getFallback);
}
class FtbChar extends FtbCharBase {
  int texId;
  int width;
  int height;
  int x;
  int y;

  FtbChar(super.char, this.texId, this.width, this.height, this.x, this.y);

  @override
  CliImgOperation getImgOperation(int i, bool hasOverride, CliImgOperationDrawFromTexture? Function() getFallback) {
    if (!hasOverride)
      return getFallback()!;
    return CliImgOperationDrawFromFont(
      i, char, 0, getFallback(),
    );
  }
}

class FtbPendingChar extends FtbCharBase {
  final String fontPath;

  FtbPendingChar(super.char, this.fontPath);

  @override
  CliImgOperation getImgOperation(int i, bool hasOverride, CliImgOperationDrawFromTexture? Function() getFallback) {
    return CliImgOperationDrawFromFont(
      i, char, 1, null,
    );
  }

  FtbChar toDefaultChar() {
    return FtbChar(char, 0, 0, 0, 0, 0);
  }
}

class FtbData extends ChangeNotifier {
  final List<int> _magic;
  final NumberProp kerning;
  List<FtbTexture> textures;
  List<FtbChar> chars;
  String path;
  String wtaPath;
  String wtpPath;
  WtaFile wtaFile;
  int fontId;
  List<FtbPendingChar> pendingNewChars = [];

  FtbData(this._magic, int kerning, this.textures, this.chars, this.path, this.wtaPath, this.wtpPath, this.wtaFile) :
    kerning = NumberProp(kerning, true, fileId: null),
    fontId = int.parse(basenameWithoutExtension(path).substring(5));

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

    var ftbFile = await FtbFile.fromFile(path);
    var ftbData = FtbData(
      ftbFile.header.start,
      ftbFile.header.globalKerning,
      ftbFile.textures.map((e) => FtbTexture(e.width, e.height)).toList(),
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

    await ftbData.extractTextures();

    return ftbData;
  }

  Future<Tuple2<List<FontAtlasGenSymbol>, int>> generateTextureBatch(int batchI, List<FtbCharBase> chars, CliFontOptions? fontOverride, CliFontOptions? newFont, List<String> textures, String ddsPath) async {
    List<CliImgOperation> imgOperations = [];
    var usedCharsMap = {
      for (var c in chars)
        if (c is FtbChar)
          c.char: c
    };
    var hasOverride = fontOverride != null;
    for (int i = 0; i < chars.length; i++) {
      var char = chars[i];
      imgOperations.add(char.getImgOperation(i, hasOverride, () {
        var currentChar = usedCharsMap[char.char];
        if (currentChar != null)
          return CliImgOperationDrawFromTexture(
            i, currentChar.texId,
            currentChar.x, currentChar.y,
            currentChar.width, currentChar.height,
            1.0,
          );
        return null;
      }));
    }

    var texPngPath = "${ddsPath.substring(0, ddsPath.length - 4)}.png";
    var fonts = {
      if (fontOverride != null) 0: fontOverride,
      if (newFont != null) 1: newFont,
    };
    var cliArgs = FontAtlasGenCliOptions(
        texPngPath, textures,
        McdData.fontAtlasLetterSpacing.value.toInt(),
        2048,
        fonts,
        imgOperations,
    );
    var atlasInfo = await runFontAtlasGenerator(cliArgs);
    await pngToDds(ddsPath, texPngPath);

    messageLog.add("Generated font atlas $batchI with ${atlasInfo.symbols.length} symbols");

    var generatedSymbolEntries = atlasInfo.symbols.entries.toList();
    generatedSymbolEntries.sort((a, b) => a.key.compareTo(b.key));
    var generatedSymbols = generatedSymbolEntries.map((e) => e.value).toList();
    return Tuple2(generatedSymbols, atlasInfo.texSize);
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
    var hasOverrideFont = await File(fontOverride.fontPath.value).exists();
    if (pendingNewChars.isEmpty && fontOverride.fontPath.value.isNotEmpty && !hasOverrideFont) {
      showToast("Font path is invalid");
      throw Exception("Font path is invalid");
    }

    // font settings
    var heightScale = fontOverride.heightScale.value.toDouble();
    var fontHeight = McdData.availableFonts[fontId]!.fontHeight * heightScale;
    CliFontOptions? overrideFont = hasOverrideFont ? CliFontOptions(
      fontOverride.fontPath.value,
      fontHeight.toInt(),
      (fontOverride.letXPadding.value * heightScale).toInt(),
      (fontOverride.letYPadding.value * heightScale).toInt(),
      (fontOverride.xOffset.value * heightScale).toDouble(),
      (fontOverride.yOffset.value * heightScale).toDouble(),
      1.0,
      fontOverride.strokeWidth.value.toInt(),
    ) : null;
    var newFonts = pendingNewChars.map((c) => c.fontPath).toSet();
    if (newFonts.length > 1)
      throw Exception("Multiple new fonts");
    CliFontOptions? newFont = newFonts.isNotEmpty ? CliFontOptions(
      newFonts.first,
      fontHeight.toInt(),
      (fontOverride.letXPadding.value * heightScale).toInt(),
      (fontOverride.letYPadding.value * heightScale).toInt(),
      (fontOverride.xOffset.value * heightScale).toDouble(),
      (fontOverride.yOffset.value * heightScale).toDouble(),
      1.0,
      fontOverride.strokeWidth.value.toInt(),
    ) : null;
    // temporary source texture copies
    List<String> sourceTextures = await Future.wait(textures.map((tex) async {
      var texPath = tex.extractedPngPath!;
      var copyPath = "${withoutExtension(texPath)}_copy.png";
      await File(texPath).copy(copyPath);
      return copyPath;
    }));
    // split chars into batches
    const textureBatchesCount = 4;
    var allChars = [...chars, ...pendingNewChars];
    var charsPerBatch = (allChars.length / textureBatchesCount).ceil();
    List<List<FtbCharBase>> charsBatches = [];
    for (int i = 0; i < allChars.length; i += charsPerBatch) {
      var batch = allChars.sublist(i, min(i + charsPerBatch, allChars.length));
      charsBatches.add(batch);
    }
    var ddsPaths = List.generate(textureBatchesCount, (i) => join(dirname(wtpPath), "${basename(wtpPath)}_extracted", "$i.dds"));
    var textureBatches = await Future.wait(List.generate(
      textureBatchesCount,
        (i) => generateTextureBatch(i, charsBatches[i], overrideFont, newFont, sourceTextures, ddsPaths[i])
    ));
    // cleanup
    await Future.wait(sourceTextures.map((e) => File(e).delete()));


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
        textures.add(FtbTexture(texSize, texSize));
      }
      var texture = textures[i];
      texture.width = texSize;
      texture.height = texSize;
      texture.extractedPngPath = "${ddsPaths[i].substring(0, ddsPaths[i].length - 4)}.png";
    }

    // add new chars
    for (var c in pendingNewChars) {
      chars.add(c.toDefaultChar());
    }
    pendingNewChars.clear();

    // update char data
    var batchI = 0;
    var batchJ = 0;
    for (var i = 0; i < chars.length; i++) {
      var char = chars[i];
      var symbol = textureBatches[batchI].item1[batchJ];
      char.x = symbol.x;
      char.y = symbol.y;
      char.width = symbol.width;
      char.height = symbol.height;
      char.texId = batchI;
      batchJ++;
      if (batchJ >= textureBatches[batchI].item1.length) {
        batchI++;
        batchJ = 0;
      }
    }
    chars.sort((a, b) => a.char.compareTo(b.char));

    notifyListeners();

    print("FTB font atlas generated");
  }

  Future<void> save() async {
    await generateTexture();

    var charsOffset = 0x88 + textures.length * 0x10;
    var ftbHeader = FtbFileHeader(_magic, kerning.value.toInt(), 0, textures.length, 0, chars.length, 0x88, charsOffset, charsOffset);

    var ftbTextures = textures.map((tex) => FtbFileTexture(0,
        tex.width, tex.height,
        0
    )).toList();

    var ftbChars = chars.map((e) => FtbFileChar(
        e.char.codeUnitAt(0), e.texId, e.width, e.height,
        e.x, e.y
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
    var extractDir = join(dirname(wtpPath), "${basename(wtpPath)}_extracted");
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
      await ddsToPng(ddsSavePath, pngSavePath);
      textures[i].extractedPngPath = pngSavePath;
    }
  }

  McdFont asMcdFont(int forTexIndex) {
    Map<int, McdFontSymbol> supportedSymbols = {};
    for (var c in chars.where((c) => c.texId == forTexIndex)) {
      var texture = textures[c.texId];
      supportedSymbols[c.char.codeUnitAt(0)] = McdFontSymbol(
        c.char.codeUnitAt(0), c.char,
        Offset(c.x / texture.width, c.y / texture.height),
        Offset((c.x + c.width) / texture.width, (c.y + c.height) / texture.height),
        Size(c.width.toDouble(), c.height.toDouble()),
        SizeInt(texture.width, texture.height),
        fontId,
        MappedKerningGetter({})
      );
    }
    return McdFont(
      fontId,
      chars[0].width.toDouble(), chars[0].height.toDouble(), 0,
      supportedSymbols,
    );
  }

  FtbData copy() {
    return FtbData(
      _magic,
      kerning.value.toInt(),
      textures.map((e) => FtbTexture(e.width, e.height)).toList(),
      chars.map((e) => FtbChar(e.char, e.texId, e.width, e.height, e.x, e.y)).toList(),
      path, wtaPath, wtpPath, wtaFile,
    );
  }
}

