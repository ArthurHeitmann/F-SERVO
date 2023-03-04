
// ignore_for_file: constant_identifier_names

import 'dart:math';
import 'dart:typed_data';

import '../utils/ByteDataWrapper.dart';

class CpkSection {
  late String id;
  late int flags;
  late int tableLength;
  late int unknown;
  late CpkTable table;

  CpkSection(this.id, this.flags, this.tableLength, this.unknown, this.table);

  CpkSection.read(ByteDataWrapper bytes) {
    bytes.endian = Endian.little;
    id = bytes.readString(4);
    flags = bytes.readUint32();
    tableLength = bytes.readUint32();
    unknown = bytes.readUint32();
    table = CpkTable.read(bytes, tableLength);
  }
}

class CpkTableHeader {
  late String id;
  late int length;
  late int unknown;
  late int encodingType;
  late int rowsPosition;
  late int stringPoolPosition;
  late int dataPoolPosition;
  late int tableNamePosition;
  late int fieldCount;
  late int rowLength;
  late int rowCount;
  late String tableName;
  late CpkTableDataPool dataPool;

  CpkTableHeader.read(ByteDataWrapper bytes) {
    int startPos = bytes.position;
    id = bytes.readString(4);
    length = bytes.readUint32();
    unknown = bytes.readUint8();
    encodingType = bytes.readUint8();
    rowsPosition = bytes.readUint16();
    stringPoolPosition = bytes.readUint32();
    dataPoolPosition = bytes.readUint32();
    tableNamePosition = bytes.readUint32();
    fieldCount = bytes.readUint16();
    rowLength = bytes.readUint16();
    rowCount = bytes.readUint32();
    dataPool = CpkTableDataPool(bytes, startPos, this);
    tableName = dataPool.readString(tableNamePosition);
  }
}
class CpkTable {
  late CpkTableHeader header;
  late List<List<CpkField>> rows;

  CpkTable.read(ByteDataWrapper bytes, int tableLength) {
    bytes.endian = Endian.big;
    header = CpkTableHeader.read(bytes);
    int rowsStart = bytes.position;
    rows = List.generate(
      header.rowCount,
      (index) {
        bytes.position = rowsStart;
        var row = List.generate(
          header.fieldCount,
          (index2) => CpkField.read(bytes, header),
        );
        header.dataPool.nextRow();
        return row;
      },
    );
  }

  CpkField? getField(int row, String name) {
    for (var field in rows[row]) {
      if (field.name == name) {
        return field;
      }
    }
    return null;
  }
}
class CpkTableDataPool {
  final ByteDataWrapper bytes;
  final int tableStartOffset;
  final int stringPoolPosition;
  final int dataPoolPosition;
  final int rowsStoreOffset;
  final int rowsStoreRowLength;
  int row = 0;
  int offset = 0;

  CpkTableDataPool(this.bytes, this.tableStartOffset, CpkTableHeader header) :
    stringPoolPosition = tableStartOffset + 8 + header.stringPoolPosition,
    dataPoolPosition = tableStartOffset + 8 + header.dataPoolPosition,
    rowsStoreOffset = header.rowsPosition,
    rowsStoreRowLength = header.rowLength;
  
  String readString(int offset) {
    int pos = bytes.position;
    bytes.position = stringPoolPosition + offset;
    String str = bytes.readStringZeroTerminated();
    bytes.position = pos;
    return str;
  }

  List<int> readData(int offset, int length) {
    int pos = bytes.position;
    bytes.position = dataPoolPosition + offset;
    List<int> data;
    if (offset > 0 && length == 0) {
      print("WARNING: Untested code (:");
      int subLength = 0;
      if (bytes.readString(4) == "@UTF") {
        subLength = bytes.readUint32();
        bytes.position -= 4;
      }
      bytes.position -= 4;
      data = bytes.asUint8List(subLength);
    } else {
      data = bytes.asUint8List(length);
    }
    bytes.position = pos;
    return data;
  }

  void nextRow() {
    row++;
    offset = 0;
  }

  void incrementOffset(int length) {
    offset += length;
  }

  int get currentRowStorePos => tableStartOffset + 8 + rowsStoreOffset + row * rowsStoreRowLength + offset;
}

class CpkField {
  late int flags;
  // Name flag
  int? namePosition;
  String? name;
  // DefaultValue flag
  Object? value;
  // String type
  int? stringPosition;
  // Data type
  int? dataPosition;
  int? dataLength;
  List<int>? data;

  CpkField.read(ByteDataWrapper bytes, CpkTableHeader header) {
    flags = bytes.readUint8();
    var dataPool = header.dataPool;

    if (flags & CpkFieldFlag.Name.value != 0) {
      namePosition = bytes.readUint32();
      name = dataPool.readString(namePosition!);
    }

    bool isDefaultValue = flags & CpkFieldFlag.DefaultValue.value != 0;
    bool isRowStorage = flags & CpkFieldFlag.RowStorage.value != 0;
    if (isDefaultValue && isRowStorage)
      throw Exception("Field cannot have both DefaultValue and RowStorage flags");
    
    if (isDefaultValue) {
      _readValue(bytes, dataPool, false);
    } else if (isRowStorage) {
      int pos = bytes.position;
      bytes.position = dataPool.currentRowStorePos;
      _readValue(bytes, dataPool, true);
      bytes.position = pos;
    }
  }

  void _readValue(ByteDataWrapper bytes, CpkTableDataPool dataPool, bool isRowStore) {
    var typeFlag = flags & CpkFieldFlag.TypeMask.value;
    switch (CpkFieldType.values[typeFlag]) {
      case CpkFieldType.UInt8:
        value = bytes.readUint8();
        if (isRowStore) dataPool.incrementOffset(1);
        break;
      case CpkFieldType.Int8:
        value = bytes.readInt8();
        if (isRowStore) dataPool.incrementOffset(1);
        break;
      case CpkFieldType.UInt16:
        value = bytes.readUint16();
        if (isRowStore) dataPool.incrementOffset(2);
        break;
      case CpkFieldType.Int16:
        value = bytes.readInt16();
        if (isRowStore) dataPool.incrementOffset(2);
        break;
      case CpkFieldType.UInt32:
        value = bytes.readUint32();
        if (isRowStore) dataPool.incrementOffset(4);
        break;
      case CpkFieldType.Int32:
        value = bytes.readInt32();
        if (isRowStore) dataPool.incrementOffset(4);
        break;
      case CpkFieldType.UInt64:
        value = bytes.readUint64();
        if (isRowStore) dataPool.incrementOffset(8);
        break;
      case CpkFieldType.Int64:
        value = bytes.readInt64();
        if (isRowStore) dataPool.incrementOffset(8);
        break;
      case CpkFieldType.Float:
        value = bytes.readFloat32();
        if (isRowStore) dataPool.incrementOffset(4);
        break;
      case CpkFieldType.Double:
        value = bytes.readFloat64();
        if (isRowStore) dataPool.incrementOffset(8);
        break;
      case CpkFieldType.String:
        stringPosition = bytes.readUint32();
        value = dataPool.readString(stringPosition!);
        if (isRowStore) dataPool.incrementOffset(4);
        break;
      case CpkFieldType.Data:
        dataPosition = bytes.readUint32();
        dataLength = bytes.readUint32();
        data = dataPool.readData(dataPosition!, dataLength!);
        if (isRowStore) dataPool.incrementOffset(8);
        break;
      case CpkFieldType.Guid:
        value = bytes.asUint8List(16);
        if (isRowStore) dataPool.incrementOffset(16);
        break;
    }
  }
}

enum CpkFieldType {
  UInt8,
  Int8,
  UInt16,
  Int16,
  UInt32,
  Int32,
  UInt64,
  Int64,
  Float,
  Double,
  String,
  Data,
  Guid;
}
enum CpkFieldFlag {
  TypeMask(0xf),
  Name(0x10),
  DefaultValue(0x20),
  RowStorage(0x40);

  final int value;

  const CpkFieldFlag(this.value);
}

class CpkFile {
  final String path;
  final String name;
  late Uint8List _data;

  CpkFile(this.path, this.name);

  CpkFile.read(this.path, this.name, ByteDataWrapper bytes, int size) {
    _data = bytes.asUint8List(size);
  }

  Uint8List getData() {
    return _data;
  }
}

class CriLaylaBitInfo {
  int inputOffset;
  int bitPool;
  int bitsLeft;

  CriLaylaBitInfo(this.inputOffset, this.bitPool, this.bitsLeft);
}

class CpkFileCompressed extends CpkFile {
  late final String id;
  late final int uncompressedSize;
  late final int compressedSize;
  late final Uint8List compressedData;
  late final Uint8List uncompressedHeader;

  CpkFileCompressed.read(super.path, super.name, ByteDataWrapper bytes) {
    bytes.endian = Endian.little;
    id = bytes.readString(8);
    uncompressedSize = bytes.readUint32();
    compressedSize = bytes.readUint32();
    compressedData = bytes.asUint8List(compressedSize);
    uncompressedHeader = bytes.asUint8List(0x100);
  }

  @override
  Uint8List getData() {
    return decompress();
  }

  Uint8List decompress() {
    print("Decompressing $name...");
    var result = Uint8List(uncompressedSize + 0x100);

    result.buffer.asUint8List().setRange(0, 0x100, uncompressedHeader);

    int inputEnd = compressedData.length - 1;
    int outputEnd = 0x100 + uncompressedSize - 1;
    CriLaylaBitInfo bitsInfo = CriLaylaBitInfo(inputEnd, 0, 0);
    int bytesOutput = 0;
    List<int> vleLens = [2, 3, 5, 8];

    while (bytesOutput < uncompressedSize)
    {
        if (getNextBits(compressedData, 1, bitsInfo) > 0)
        {
            int backReferenceOffset = outputEnd - bytesOutput + getNextBits(compressedData, 13, bitsInfo) + 3;
            int backReferenceLength = 3;
            int vleLevel;

            for (vleLevel = 0; vleLevel < vleLens.length; vleLevel++)
            {
                int thisLevel = getNextBits(compressedData, vleLens[vleLevel], bitsInfo);
                backReferenceLength += thisLevel;
                if (thisLevel != ((1 << vleLens[vleLevel]) - 1)) break;
            }

            if (vleLevel == vleLens.length)
            {
                int thisLevel;
                do
                {
                    thisLevel = getNextBits(compressedData, 8, bitsInfo);
                    backReferenceLength += thisLevel;
                } while (thisLevel == 255);
            }

            for (int i = 0; i < backReferenceLength; i++)
            {
                result[outputEnd - bytesOutput] = result[backReferenceOffset--];
                bytesOutput++;
            }
        }
        else
        {
            // verbatim byte
            result[outputEnd - bytesOutput] = getNextBits(compressedData, 8, bitsInfo);
            bytesOutput++;
        }
    }

    return result;
  }

  int getNextBits(Uint8List input, int bitCount, CriLaylaBitInfo bitsInfo) {
    int outBits = 0;
    int numBitsProduced = 0;
    int bitsThisRound;

    while (numBitsProduced < bitCount) {
      if (bitsInfo.bitsLeft == 0) {
        bitsInfo.bitPool = input[bitsInfo.inputOffset];
        bitsInfo.bitsLeft = 8;
        bitsInfo.inputOffset--;
      }

      if (bitsInfo.bitsLeft > (bitCount - numBitsProduced)) {
        bitsThisRound = bitCount - numBitsProduced;
      } else {
        bitsThisRound = bitsInfo.bitsLeft;
      }

      outBits <<= bitsThisRound;

      outBits |= (bitsInfo.bitPool >> (bitsInfo.bitsLeft - bitsThisRound)) & ((1 << bitsThisRound) - 1);

      bitsInfo.bitsLeft -= bitsThisRound;
      numBitsProduced += bitsThisRound;
    }

    return outBits;
  }
}

class Cpk {
  CpkSection header;
  CpkSection? toc;
  List<CpkFile> files = [];

  Cpk.read(ByteDataWrapper bytes)
    : header = CpkSection.read(bytes) {
    var contentOffsetField = header.table.getField(0, "ContentOffset");
    if (contentOffsetField == null)
      throw Exception("ContentOffset field not found in header table");
    int contentOffset = contentOffsetField.value! as int;
    var tocOffsetField = header.table.getField(0, "TocOffset");
    if (tocOffsetField == null)
      throw Exception("TocOffset field not found in header table");
    int tocOffset = tocOffsetField.value! as int;

    bytes.position = tocOffset;
    toc = CpkSection.read(bytes);

    int contentDelta = min(tocOffset, contentOffset);
    print("Reading ${toc!.table.header.rowCount} files...");
    for (var i = 0; i < toc!.table.header.rowCount; i++) {
      var fileOffset = toc!.table.getField(i, "FileOffset")!.value! as int;
      var fileSize = toc!.table.getField(i, "FileSize")!.value! as int;
      var extractedSize = toc!.table.getField(i, "ExtractSize")!.value! as int;
      var dirName = toc!.table.getField(i, "DirName")!.value! as String;
      var fileName = toc!.table.getField(i, "FileName")!.value! as String;
      var isCompressed = fileSize != extractedSize;
      bytes.position = fileOffset + contentDelta;
      try {
        if (isCompressed)
          files.add(CpkFileCompressed.read(dirName, fileName, bytes));
        else
          files.add(CpkFile.read(dirName, fileName, bytes, extractedSize));
      } catch (e) {
        print("Failed to read file $dirName/$fileName");
        rethrow;
      }
    }
  }
}
