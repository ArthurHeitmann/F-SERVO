
import 'dart:math';

import '../../utils.dart';
import '../utils/ByteDataWrapper.dart';

int _significantBitsInInt(int i) {
  int bits = 0;
  while (i != 0) {
    i >>= 1;
    bits++;
  }
  return bits;
}

int _nextPowerOf2Bits(int x) {
  return x == 0 ? 1 : _significantBitsInInt(x - 1);
}

class HashData {
  int preHashShift;
  List<int> bucketOffsets;
  List<int> hashes;
  List<int> fileIndices;

  HashData(this.preHashShift) : bucketOffsets = [], hashes = [], fileIndices = [];

  int getStructSize() {
    return 4 + 2 * bucketOffsets.length + 4 * hashes.length + 4 * fileIndices.length;
  }

  void write(ByteDataWrapper bytes) {
    var bucketsOffset = 4 * 4;
    var hashesOffset = bucketsOffset + bucketOffsets.length * 2;
    var fileIndicesOffset = hashesOffset + hashes.length * 4;

    bytes.writeUint32(preHashShift);
    bytes.writeUint32(bucketsOffset);
    bytes.writeUint32(hashesOffset);
    bytes.writeUint32(fileIndicesOffset);

    for (var bucketOffset in bucketOffsets)
      bytes.writeInt16(bucketOffset);
    for (var hash in hashes)
      bytes.writeUint32(hash);
    for (var fileIndex in fileIndices)
      bytes.writeInt16(fileIndex);
  }
}

class _TripleList {
  final int hash;
  final int fileIndex;
  final String fileName;

  const _TripleList(this.hash, this.fileIndex, this.fileName);
}

HashData generateHashData(List<String> fileNames) {
  var preHashShift = _nextPowerOf2Bits(fileNames.length);
  preHashShift = min(31, 32 - preHashShift);
  var bucketOffsetsSize = 1 << (31 - preHashShift);
  var bucketOffsets = List<int>.filled(bucketOffsetsSize, -1);
  var hashes = List<int>.filled(fileNames.length, 0);
  var fileIndices = List<int>.generate(fileNames.length, (i) => i);

  // generate hashes
  for (var i = 0; i < fileNames.length; i++) {
    var fileName = fileNames[i];
    var hash = crc32(fileName.toLowerCase());
    var otherHash = hash & 0x7FFFFFFF;
    hashes[i] = otherHash;
  }
  // sort by first half byte (x & 0x70000000)
  // sort indices & hashes at the same time
  var hashesFileIndicesFileNames = List.generate(fileNames.length, (i) => _TripleList(hashes[i], fileIndices[i], fileNames[i]));
  hashesFileIndicesFileNames.sort((a, b) => (a.hash & 0x70000000).compareTo(b.hash & 0x70000000));
  hashes = hashesFileIndicesFileNames.map((e) => e.hash).toList();
  fileIndices = hashesFileIndicesFileNames.map((e) => e.fileIndex).toList();
  fileNames = hashesFileIndicesFileNames.map((e) => e.fileName).toList();
  // generate bucket list
  for (var i = 0; i < fileNames.length; i++) {
    var bucketOffsetsIndex = hashes[i] >> preHashShift;
    if (bucketOffsets[bucketOffsetsIndex] == -1) {
      bucketOffsets[bucketOffsetsIndex] = i;
    }
  }

  var hashData = HashData(preHashShift);
  hashData.bucketOffsets = bucketOffsets;
  hashData.hashes = hashes;
  hashData.fileIndices = fileIndices;
  return hashData;
}
