
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';

Future<void> repackCtx(String ctxPath, String extractDir) async {
  var files = (await Directory(extractDir).list().toList())
    .whereType<File>()
    .where((file) => file.path.endsWith(".wtb"))
    .map((file) => file.path)
    .toList();
  files.sort();
  if (files.isEmpty) {
    messageLog.add("No wtb files inside ${basename(extractDir)}");
    return;
  }
  var fileSizes = await Future.wait(files.map((file) => File(file).length()));
  List<int> offsets = [4096];
  for (int i = 1; i < files.length; i++) {
    offsets.add(alignTo(offsets.last + fileSizes[i - 1], 4096));
  }
  var ctxSize = alignTo(offsets.last + fileSizes.last, 4096);
  var bytes = ByteDataWrapper.allocate(ctxSize);
  bytes.writeString("CT2\x00");
  bytes.writeUint32(files.length);
  for (var offset in offsets) {
    bytes.writeUint32(offset);
  }
  for (int i = 0; i < files.length; i++) {
    var fileBytes = await File(files[i]).readAsBytes();
    bytes.position = offsets[i];
    bytes.writeBytes(fileBytes);
  }
  
  await backupFile(ctxPath);
  await File(ctxPath).writeAsBytes(bytes.buffer.asUint8List());
  messageLog.add("Repacked ${basename(ctxPath)}");
}
