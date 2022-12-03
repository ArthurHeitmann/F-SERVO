
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

import '../fileTypeUtils/audio/riffParser.dart';
import '../fileTypeUtils/utils/ByteDataWrapper.dart';

const testFile = r"D:\delete\mods\na\NieR-Audio-Tools\new\AP full\AmusementPark_looping_bg_wCue_E09CCBC3.wem";

void main(List<String> args) async {
  var newPath = join(dirname(testFile), "${basenameWithoutExtension(testFile)}_copy${extension(testFile)}");
  var riff = await RiffFile.fromFile(testFile);
  var newBytes = ByteData(riff.size);
  riff.write(ByteDataWrapper(newBytes.buffer));
  await File(newPath).writeAsBytes(newBytes.buffer.asUint8List());
  print("Done");
}
