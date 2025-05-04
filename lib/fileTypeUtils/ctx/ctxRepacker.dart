

import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';
import '../../fileSystem/FileSystem.dart';

Future<void> repackCtx(String ctxPath, String extractDir) async {
  var files = await FS.i.listFiles(extractDir)
    .where((file) => file.endsWith(".wtb"))
    .toList();
  files.sort();
  if (files.isEmpty) {
    messageLog.add("No wtb files inside ${basename(extractDir)}");
    return;
  }
  var fileSizes = await Future.wait(files.map((file) => FS.i.getSize(file)));
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
    var fileBytes = await FS.i.read(files[i]);
    bytes.position = offsets[i];
    bytes.writeBytes(fileBytes);
  }
  
  await backupFile(ctxPath);
  await bytes.save(ctxPath);
  messageLog.add("Repacked ${basename(ctxPath)}");
}
