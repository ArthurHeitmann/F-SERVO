
import 'dart:io';
import 'dart:typed_data';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';

Future<void> texToDds(String srcPath, String dstPath, { String compression = "dxt5", int mipmaps = 0 }) async {
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

Future<Uint8List?> texToPng(String ddsPath, {String? pngPath, int? maxHeight, bool verbose = true}) async {
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

Future<Uint8List?> texToPngInMemory(Uint8List texBytes, {int? maxHeight, bool verbose = true}) async {
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


