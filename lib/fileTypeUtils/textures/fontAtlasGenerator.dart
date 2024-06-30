

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import 'fontAtlasGeneratorTypes.dart';

Future<FontAtlasGenResult> runFontAtlasGenerator(FontAtlasGenCliOptions options) async {
  var cliJson = jsonEncode(options.toJson());
  cliJson = base64Encode(utf8.encode(cliJson));
  var cliToolPath = join(assetsDir!, "FontAtlasGenerator", "__init__.py");
  var cliToolProcess = await Process.start(pythonCmd!, [cliToolPath]);
  cliToolProcess.stdin.writeln(cliJson);
  await cliToolProcess.stdin.close();
  var stdout = cliToolProcess.stdout.transform(utf8.decoder).join();
  var stderr = cliToolProcess.stderr.transform(utf8.decoder).join();
  if (await cliToolProcess.exitCode != 0) {
    var stdoutStr = await stdout;
    var stderrStr = await stderr;
    messageLog.add("stdout: $stdoutStr");
    messageLog.add("stderr: $stderrStr");
    showToast("Font atlas generator failed");
    throw Exception("Font atlas generator failed for file ${options.dstTexPath}");
  }

  try {
    var atlasInfoJson = jsonDecode(await stdout);
    return FontAtlasGenResult.fromJson(atlasInfoJson);
  } catch (e) {
    showToast("Font atlas generator failed");
    print(e);
    print(await stdout);
    print(await stderr);
    throw Exception("Font atlas generator failed");
  }
}
