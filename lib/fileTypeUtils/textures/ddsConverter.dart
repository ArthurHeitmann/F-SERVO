
import 'dart:io';
import 'dart:typed_data';

import '../../fileSystem/FileSystem.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../../web/serviceWorker.dart';

Future<void> texToDds(String srcPath, String dstPath, { String compression = "dxt5", int mipmaps = 0 }) async {
  if (isDesktop) {
    await _texToDdsDesktop(srcPath, dstPath, compression, mipmaps);
  } else if (isWeb) {
    await _texToDdsWeb(srcPath, dstPath, compression, mipmaps);
  } else {
    throw Exception("texToDds: Unsupported platform");
  }
}

Future<void> _texToDdsDesktop(String srcPath, String dstPath, String compression, int mipmaps) async {
  var result = await Process.run(
    magickBinPath!,
    [
      srcPath,
      if (dstPath.endsWith(".dds")) ...[
        "-define",
        "dds:compression=$compression",
        "-define",
        "dds:mipmaps=$mipmaps",
      ],
      dstPath
      ]
  );
  if (result.exitCode != 0) {
    messageLog.add("stdout: ${result.stdout}");
    messageLog.add("stderr: ${result.stderr}");
    messageLog.add("Failed to convert texture to DDS: ${result.stderr}");
    throw Exception("Failed to convert texture to DDS: ${result.stderr}");
  }
}

Future<void> _texToDdsWeb(String srcPath, String dstPath, String compression, int mipmaps) async {
  var imgBytes = await FS.i.read(srcPath);
  var result = await ServiceWorkerHelper.i.imgToDds(imgBytes, compression, mipmaps);
  if (result.isOk) {
    if (!_hasDdsHeader(result.ok)) {
      messageLog.add("Failed to convert texture to DDS. Invalid header.");
      throw Exception("Failed to convert texture to DDS. Invalid header.");
    }
    await FS.i.write(dstPath, result.ok);
  } else {
    throw Exception("WemToWav: ${result.errorMessage}");
  }
}

Future<Uint8List?> texToPng(String ddsPath, {String? pngPath, int? maxHeight, bool verbose = true}) async {
  if (isDesktop) {
    return await _texToPngDesktop(ddsPath, pngPath, maxHeight, verbose);
  } else if (isWeb) {
    return await _texToPngWeb(ddsPath, pngPath, maxHeight, verbose);
  } else {
    throw Exception("texToPng: Unsupported platform");
  }
}

Future<Uint8List?> _texToPngDesktop(String ddsPath, String? pngPath, int? maxHeight, bool verbose) async {
  if (!await hasMagickBins()) {
    if (verbose)
      showToast("Can't load texture because ImageMagick is not found.");
    if (pngPath == null)
      return null;
    throw Exception("Can't load texture because ImageMagick is not found.");
  }
  var result = await Process.run(
    magickBinPath!,
    [
      ddsPath,
      if (maxHeight != null) ...[
        "-resize", "x$maxHeight",
      ],
      pngPath == null ? "PNG:-" : "PNG:$pngPath",
    ],
    stdoutEncoding: pngPath == null ? null : systemEncoding,
    stderrEncoding: systemEncoding,
  );
  if (result.exitCode != 0) {
    if (verbose)
      showToast("Can't load texture because ImageMagick failed to convert DDS to PNG.");
    print("stdout: ${result.stderr}");
    throw Exception("Can't load texture because ImageMagick failed to convert DDS to PNG.");
  }
  if (pngPath == null)
    return Uint8List.fromList(result.stdout as List<int>);
  return null;
}

Future<Uint8List?> _texToPngWeb(String ddsPath, String? pngPath, int? maxHeight, bool verbose) async {
  var imgBytes = await FS.i.read(ddsPath);
  var result = await ServiceWorkerHelper.i.imgToPng(imgBytes, maxHeight!);
  if (result.isOk) {
    if (pngPath != null) {
      await FS.i.write(pngPath, result.ok);
    }
    if (!_hasPngHeader(result.ok)) {
      if (verbose)
        showToast("Can't load texture because ImageMagick failed to convert DDS to PNG. Invalid header.");
      throw Exception("Can't load texture because ImageMagick failed to convert DDS to PNG.");
    }
    var hexBytes = result.ok.sublist(0, 50).map((e) => e.toRadixString(16).padLeft(2, "0")).join(" ");
    var asciiBytes = result.ok.sublist(0, 50).map((e) => e < 32 || e > 126 ? "." : String.fromCharCode(e)).join("");
    print("$ddsPath\n$hexBytes...\n$asciiBytes...");
    return result.ok;
  } else {
    if (verbose)
      showToast("Can't load texture because ImageMagick failed to convert DDS to PNG.");
    print("stdout: ${result.errorMessage}");
    throw Exception("Can't load texture because ImageMagick failed to convert DDS to PNG.");
  }
}

Future<Uint8List?> texToPngInMemory(Uint8List texBytes, {int? maxHeight, bool verbose = true}) async {
  if (isDesktop) {
    return await _texToPngInMemoryDesktop(texBytes, maxHeight, verbose);
  } else if (isWeb) {
    return await _texToPngInMemoryWeb(texBytes, maxHeight, verbose);
  } else {
    throw Exception("texToPng: Unsupported platform");
  }
}

Future<Uint8List?> _texToPngInMemoryDesktop(Uint8List texBytes, int? maxHeight, bool verbose) async {
  if (!await hasMagickBins()) {
    if (verbose)
      showToast("Can't load texture because ImageMagick is not found.");
    return null;
  }
  var process = await Process.start(
    magickBinPath!,
    [
      "DDS:-",
      if (maxHeight != null) ...[
        "-resize", "x$maxHeight",
      ],
      "PNG:-",
    ],
  );
  process.stdin.add(texBytes);
  await process.stdin.close();
  var result = await process.stdout.expand((e) => e).toList();
  if (await process.exitCode != 0) {
    if (verbose)
      showToast("Can't load texture because ImageMagick failed to convert DDS to PNG.");
    print("stdout: ${result}");
    throw Exception("Can't load texture because ImageMagick failed to convert DDS to PNG.");
  }
  return Uint8List.fromList(result);
}

Future<Uint8List?> _texToPngInMemoryWeb(Uint8List texBytes, int? maxHeight, bool verbose) async {
  var result = await ServiceWorkerHelper.i.imgToPng(texBytes, maxHeight!);
  if (result.isOk) {
    if (!_hasPngHeader(result.ok)) {
      if (verbose)
        showToast("Can't load texture because ImageMagick failed to convert DDS to PNG. Invalid header.");
      throw Exception("Can't load texture because ImageMagick failed to convert DDS to PNG.");
    }
    return result.ok;
  } else {
    if (verbose)
      showToast("Can't load texture because ImageMagick failed to convert DDS to PNG.");
    print("stdout: ${result.errorMessage}");
    throw Exception("Can't load texture because ImageMagick failed to convert DDS to PNG.");
  }
}

bool _hasPngHeader(Uint8List? bytes) {
  if (bytes == null || bytes.length < 8) {
    return false;
  }
  const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (int i = 0; i < magic.length; i++) {
    if (bytes[i] != magic[i]) {
      return false;
    }
  }
  return true;
}

bool _hasDdsHeader(Uint8List? bytes) {
  if (bytes == null || bytes.length < 4) {
    return false;
  }
  const magic = [0x44, 0x44, 0x53, 0x20]; // "DDS "
  for (int i = 0; i < magic.length; i++) {
    if (bytes[i] != magic[i]) {
      return false;
    }
  }
  return true;
}
