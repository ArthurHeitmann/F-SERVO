
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
    
    // update offsets of all following files
    int prevOffset = didx.files[wemIndex].offset + didx.files[wemIndex].size;
    for (int i = wemIndex + 1; i < didx.files.length; i++) {
      prevOffset = alignTo16Bytes(prevOffset);
      didx.files[i].offset = prevOffset;
      prevOffset += didx.files[i].size;
    }

    // update data chunk size
    int prevChunkSize = data.chunkSize;
    data.chunkSize = prevOffset;
    int sizeDiff = data.chunkSize - prevChunkSize;

    // write to file
    bnkBytes = ByteDataWrapper.allocate(bnkBytes.length + sizeDiff);
    bnk.write(bnkBytes);
    await bnkBytes.save(bnkPath);
  } finally {
    _patchLocks[bnkPath]!.release();
  }
}

int alignTo16Bytes(int pos) {
  return (pos + 15) & ~15;
}
