
import 'dart:io';

import 'package:mutex/mutex.dart';

import '../utils/ByteDataWrapper.dart';
import 'bnkIO.dart';

Map<String, Mutex> _patchLocks = {};

Future<void> patchBnk(String bnkPath, int wemId, String wemPath) async {
  if (!_patchLocks.containsKey(bnkPath))
    _patchLocks[bnkPath] = Mutex();
  await _patchLocks[bnkPath]!.acquire();

  try {
    var bnkBytes = await ByteDataWrapper.fromFile(bnkPath);
    var bnk = BnkFile.read(bnkBytes);
    var didx = bnk.chunks.whereType<BnkDidxChunk>().first;
    var data = bnk.chunks.whereType<BnkDataChunk>().first;
    assert(didx.files.length == data.wemFiles.length);

    var wemIndex = didx.files.indexWhere((f) => f.id == wemId);
    if (wemIndex == -1)
      throw Exception("Wem file with id $wemId not found in $bnkPath");
    
    // update bytes
    var wemBytes = await File(wemPath).readAsBytes();
    data.wemFiles[wemIndex] = wemBytes;
    didx.files[wemIndex].size = wemBytes.length;
    
    // update offsets
    data.updateOffsets(didx);

    // update data chunk size
    int prevChunkSize = data.chunkSize;
    data.updateChunkSize();
    int sizeDiff = data.chunkSize - prevChunkSize;

    // write to file
    bnkBytes = ByteDataWrapper.allocate(bnkBytes.length + sizeDiff);
    bnk.write(bnkBytes);
    await bnkBytes.save(bnkPath);
  } finally {
    _patchLocks[bnkPath]!.release();
  }
}
