
import 'dart:io';
import 'dart:typed_data';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';

Future<void> pngToDds(String ddsPath, String pngPath) async {
  var result = await Process.run(
    magickBinPath!,
    [pngPath, "-define", "dds:mipmaps=0", ddsPath]
  );
  if (result.exitCode != 0) {
    messageLog.add("stdout: ${result.stdout}");
    messageLog.add("stderr: ${result.stderr}");
    messageLog.add("Failed to convert texture to DDS: ${result.stderr}");
    throw Exception("Failed to convert texture to DDS: ${result.stderr}");
  }
}

Future<Uint8List?> ddsToPng(String ddsPath, [String? pngPath]) async {
  if (!await hasMagickBins()) {
    showToast("Can't load texture because ImageMagick is not found.");
    if (pngPath == null)
      return null;
    throw Exception("Can't load texture because ImageMagick is not found.");
  }
  var result = await Process.run(
    magickBinPath!,
    ["DDS:$ddsPath", pngPath == null ? "PNG:-" : "PNG:$pngPath"],
    stdoutEncoding: pngPath == null ? null : systemEncoding,
  );
  if (result.exitCode != 0) {
    showToast("Can't load texture because ImageMagick failed to convert DDS to PNG.");
    if (pngPath == null)
      return null;
    throw Exception("Can't load texture because ImageMagick failed to convert DDS to PNG.");
  }
  if (pngPath == null)
    return Uint8List.fromList(result.stdout as List<int>);
  return null;
}
