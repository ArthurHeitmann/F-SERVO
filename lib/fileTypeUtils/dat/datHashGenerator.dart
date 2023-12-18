
import '../../utils/utils.dart';

// From https://github.com/xxk-i/DATrepacker
class HashInfo {
  List<String> inFiles;
  List<String> filenames = [];
  List<int> hashes = [];
  List<int> indices = [];
  List<int> bucketOffsets = [];
  int preHashShift = 0;
  int bucketsSize = 0;
  int hashesSize = 0;
  int indicesSize = 0;

  HashInfo(this.inFiles) {
    _generateInfo();
  }

  int _calculateShift() {
    for (int i = 0; i < 31; i++) {
      if (1 << i >= inFiles.length)
        return 31 - i;
    }

    return 0;
  }

  void _generateInfo() {
    preHashShift = _calculateShift();

    filenames = inFiles;

    bucketOffsets = List<int>.filled(1 << 31 - preHashShift, -1);

    if (preHashShift == 0)
      print("Hash shift is 0; does directory have more than 1 << 31 files?");

    List<(String, int, int)> namesIndicesHashes = [];
    for (int i = 0; i < filenames.length; i++)
      namesIndicesHashes.add((
      filenames[i],
      i,
      (crc32(filenames[i].toLowerCase()) & ~0x80000000)
    ));

    var namesIndicesHashesI = namesIndicesHashes.indexed.toList();
    namesIndicesHashesI.sort((a, b) {
      int kA = a.$2.$3 >> preHashShift;
      int kB = b.$2.$3 >> preHashShift;
      var comp = kA.compareTo(kB);
      if (comp == 0)
        return a.$1.compareTo(b.$1);
      return comp;
    });
    namesIndicesHashes = namesIndicesHashesI.map((e) => e.$2).toList();

    hashes = namesIndicesHashes
      .map((e) => e.$3)
      .toList();

    var hashesI = hashes.indexed.toList();
    hashesI.sort((a, b) {
      int kA = a.$2 >> preHashShift;
      int kB = b.$2 >> preHashShift;
      var comp = kA.compareTo(kB);
      if (comp == 0)
        return a.$1.compareTo(b.$1);
      return comp;
    });
    hashes = hashesI.map((e) => e.$2).toList();

    for (int i = 0; i < namesIndicesHashes.length; i++) {
      if (bucketOffsets[namesIndicesHashes[i].$3 >> preHashShift] == -1)
        bucketOffsets[namesIndicesHashes[i].$3 >> preHashShift] = i;
      indices.add(namesIndicesHashes[i].$2);
    }
  }

  int getTableSize() {
    bucketsSize = bucketOffsets.length * 2; // these are only shorts (uint16)
    hashesSize = hashes.length * 4; // uint32
    indicesSize = indices.length * 2; // shorts again (uint16)

    int size = 16 + bucketsSize + hashesSize + indicesSize; // 16 for pre_hash_shift and 3 table offsets (all uint32)

    return size;
  }
}
