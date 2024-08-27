
// ignore_for_file: constant_identifier_names

import 'dart:math';
import 'dart:typed_data';

import '../utils/ByteDataWrapperRA.dart';

class CpkSection {
  late String id;
  late int flags;
  late int tableLength;
  late int unknown;
  late CpkTable table;

  CpkSection(this.id, this.flags, this.tableLength, this.unknown, this.table);

  static Future<CpkSection> read(ByteDataWrapperRA bytes) async {
    bytes.endian = Endian.little;
    var id = await bytes.readString(4);
    var flags = await bytes.readUint32();
    var tableLength = await bytes.readUint32();
    var unknown = await bytes.readUint32();
    var table = await CpkTable.read(bytes, tableLength);
    return CpkSection(id, flags, tableLength, unknown, table);
  }
}

class CpkTableHeader {
  final String id;
  final int length;
  final int unknown;
  final int encodingType;
  final int rowsPosition;
  final int stringPoolPosition;
  final int dataPoolPosition;
  final int tableNamePosition;
  final int fieldCount;
  final int rowLength;
  final int rowCount;
  final String tableName;
  final CpkTableDataPool dataPool;

  CpkTableHeader(this.id, this.length, this.unknown, this.encodingType, this.rowsPosition, this.stringPoolPosition, this.dataPoolPosition, this.tableNamePosition, this.fieldCount, this.rowLength, this.rowCount, this.tableName, this.dataPool);

  static Future<CpkTableHeader> read(ByteDataWrapperRA bytes) async {
    int startPos = bytes.position;
    var id = await bytes.readString(4);
    var length = await bytes.readUint32();
    var unknown = await bytes.readUint8();
    var encodingType = await bytes.readUint8();
    var rowsPosition = await bytes.readUint16();
    var stringPoolPosition = await bytes.readUint32();
    var dataPoolPosition = await bytes.readUint32();
    var tableNamePosition = await bytes.readUint32();
    var fieldCount = await bytes.readUint16();
    var rowLength = await bytes.readUint16();
    var rowCount = await bytes.readUint32();
    var dataPool = CpkTableDataPool(bytes, startPos, stringPoolPosition, dataPoolPosition, rowsPosition, rowLength);
    var tableName = await dataPool.readString(tableNamePosition);
    return CpkTableHeader(id, length, unknown, encodingType, rowsPosition, stringPoolPosition, dataPoolPosition, tableNamePosition, fieldCount, rowLength, rowCount, tableName, dataPool);
  }
}
class CpkTable {
  final CpkTableHeader header;
  final List<List<CpkField>> rows;
  
  CpkTable(this.header, this.rows);

  static Future<CpkTable> read(ByteDataWrapperRA bytes, int tableLength) async {
    bytes.endian = Endian.big;
    var header = await CpkTableHeader.read(bytes);
    int rowsStart = bytes.position;
    List<List<CpkField>> rows = [];
    for (var i = 0; i < header.rowCount; i++) {
      bytes.setPosition(rowsStart);
      List<CpkField> row = [];
      for (var j = 0; j < header.fieldCount; j++)
        row.add(await CpkField.read(bytes, header));
      header.dataPool.nextRow();
      rows.add(row);
    }
    return CpkTable(header, rows);
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
  final ByteDataWrapperRA bytes;
  final int tableStartOffset;
  final int stringPoolPosition;
  final int dataPoolPosition;
  final int rowsStoreOffset;
  final int rowsStoreRowLength;
  int row = 0;
  int offset = 0;

  CpkTableDataPool(this.bytes, this.tableStartOffset, int stringPoolPosition, int dataPoolPosition, int rowsPosition, rowLength) :
    stringPoolPosition = tableStartOffset + 8 + stringPoolPosition,
    dataPoolPosition = tableStartOffset + 8 + dataPoolPosition,
    rowsStoreOffset = rowsPosition,
    rowsStoreRowLength = rowLength;
  
  Future<String> readString(int offset) async {
    int pos = bytes.position;
    bytes.setPosition(stringPoolPosition + offset);
    String str = await bytes.readStringZeroTerminated();
    bytes.setPosition(pos);
    return str;
  }

  Future<List<int>> readData(int offset, int length) async {
    int pos = bytes.position;
    bytes.setPosition(dataPoolPosition + offset);
    List<int> data;
    if (offset > 0 && length == 0) {
      print("WARNING: Untested code (:");
      int subLength = 0;
      if (await bytes.readString(4) == "@UTF") {
        subLength = await bytes.readUint32();
        bytes.setPosition(bytes.position - 4);
      }
      bytes.setPosition(bytes.position - 4);
      data = await bytes.readUint8List(subLength);
    } else {
      data = await bytes.readUint8List(length);
    }
    bytes.setPosition(pos);
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
  
  static Future<CpkField> read(ByteDataWrapperRA bytes, CpkTableHeader header) async {
    var field = CpkField();
    field.flags = await bytes.readUint8();
    var dataPool = header.dataPool;

    if (field.flags & CpkFieldFlag.Name.value != 0) {
      field.namePosition = await bytes.readUint32();
      field.name = await dataPool.readString(field.namePosition!);
    }

    bool isDefaultValue = field.flags & CpkFieldFlag.DefaultValue.value != 0;
    bool isRowStorage = field.flags & CpkFieldFlag.RowStorage.value != 0;
    if (isDefaultValue && isRowStorage)
      throw Exception("Field cannot have both DefaultValue and RowStorage flags");

    Object? value;
    if (isDefaultValue) {
      value = await _readValue(field, bytes, dataPool, false);
    } else if (isRowStorage) {
      int pos = bytes.position;
      bytes.setPosition(dataPool.currentRowStorePos);
      value = await _readValue(field, bytes, dataPool, true);
      bytes.setPosition(pos);
    }
    field.value = value;
    
    return field;
  }

  static Future<Object?> _readValue(CpkField field, ByteDataWrapperRA bytes, CpkTableDataPool dataPool, bool isRowStore) async {
    var typeFlag = field.flags & CpkFieldFlag.TypeMask.value;
    Object? value;
    switch (CpkFieldType.values[typeFlag]) {
      case CpkFieldType.UInt8:
        value = await bytes.readUint8();
        if (isRowStore) dataPool.incrementOffset(1);
        break;
      case CpkFieldType.Int8:
        value = await bytes.readInt8();
        if (isRowStore) dataPool.incrementOffset(1);
        break;
      case CpkFieldType.UInt16:
        value = await bytes.readUint16();
        if (isRowStore) dataPool.incrementOffset(2);
        break;
      case CpkFieldType.Int16:
        value = await bytes.readInt16();
        if (isRowStore) dataPool.incrementOffset(2);
        break;
      case CpkFieldType.UInt32:
        value = await bytes.readUint32();
        if (isRowStore) dataPool.incrementOffset(4);
        break;
      case CpkFieldType.Int32:
        value = await bytes.readInt32();
        if (isRowStore) dataPool.incrementOffset(4);
        break;
      case CpkFieldType.UInt64:
        value = await bytes.readUint64();
        if (isRowStore) dataPool.incrementOffset(8);
        break;
      case CpkFieldType.Int64:
        value = await bytes.readInt64();
        if (isRowStore) dataPool.incrementOffset(8);
        break;
      case CpkFieldType.Float:
        value = await bytes.readFloat32();
        if (isRowStore) dataPool.incrementOffset(4);
        break;
      case CpkFieldType.Double:
        value = await bytes.readFloat64();
        if (isRowStore) dataPool.incrementOffset(8);
        break;
      case CpkFieldType.String:
        field.stringPosition = await bytes.readUint32();
        value = dataPool.readString(field.stringPosition!);
        if (isRowStore) dataPool.incrementOffset(4);
        break;
      case CpkFieldType.Data:
        field.dataPosition = await bytes.readUint32();
        field.dataLength = await bytes.readUint32();
        field.data = await dataPool.readData(field.dataPosition!, field.dataLength!);
        if (isRowStore) dataPool.incrementOffset(8);
        break;
      case CpkFieldType.Guid:
        value = await bytes.readUint8List(16);
        if (isRowStore) dataPool.incrementOffset(16);
        break;
    }
    return value;
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

abstract class CpkFile {
  final String path;
  final String name;

  CpkFile(this.path, this.name);

  Future<Uint8List> readData(ByteDataWrapperRA bytes);
}

class CpkFileUncompressed extends CpkFile {
  final int dataOffset;
  final int dataSize;

  CpkFileUncompressed(super.path, super.name, this.dataOffset, this.dataSize);

  @override
  Future<Uint8List> readData(ByteDataWrapperRA bytes) async {
    bytes.setPosition(dataOffset);
    return await bytes.readUint8List(dataSize);
  }
}

class CriLaylaBitInfo {
  int inputOffset;
  int bitPool;
  int bitsLeft;

  CriLaylaBitInfo(this.inputOffset, this.bitPool, this.bitsLeft);
}

class CpkFileCompressed extends CpkFile {
  final String id;
  final int uncompressedSize;
  final int compressedSize;
  final int compressedDataOffset;

  CpkFileCompressed(super.path, super.name, this.id, this.uncompressedSize, this.compressedSize, this.compressedDataOffset);

  static Future<CpkFileCompressed> read(String path, String name, ByteDataWrapperRA bytes, int compressedDataOffset) async {
    bytes.endian = Endian.little;
    bytes.setPosition(compressedDataOffset);
    var id = await bytes.readString(8);
    var uncompressedSize = await bytes.readUint32();
    var compressedSize = await bytes.readUint32();
    return CpkFileCompressed(path, name, id, uncompressedSize, compressedSize, bytes.position);
  }

  @override
  Future<Uint8List> readData(ByteDataWrapperRA bytes) async {
    bytes.setPosition(compressedDataOffset);
    var compressedData = await bytes.readUint8List(compressedSize);
    var uncompressedHeader = await bytes.readUint8List(0x100);
    return decompress(compressedData, uncompressedHeader);
  }

  Uint8List decompress(Uint8List compressedData, Uint8List uncompressedHeader) {
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
  CpkSection toc;
  List<CpkFile> files;

  Cpk(this.header, this.toc, this.files);

  static Future<Cpk> read(ByteDataWrapperRA bytes) async {
    var header = await CpkSection.read(bytes);
    var contentOffsetField = header.table.getField(0, "ContentOffset");
    if (contentOffsetField == null)
      throw Exception("ContentOffset field not found in header table");
    int contentOffset = contentOffsetField.value! as int;
    var tocOffsetField = header.table.getField(0, "TocOffset");
    if (tocOffsetField == null)
      throw Exception("TocOffset field not found in header table");
    int tocOffset = tocOffsetField.value! as int;

    bytes.setPosition(tocOffset);
    var toc = await CpkSection.read(bytes);

    int contentDelta = min(tocOffset, contentOffset);
    print("Reading ${toc.table.header.rowCount} files...");
    List<CpkFile> files = [];
    for (var i = 0; i < toc.table.header.rowCount; i++) {
      var fileOffset = toc.table.getField(i, "FileOffset")!.value! as int;
      var fileSize = toc.table.getField(i, "FileSize")!.value! as int;
      var extractedSize = toc.table.getField(i, "ExtractSize")!.value! as int;
      var dirName = toc.table.getField(i, "DirName")!.value! as String;
      var fileName = toc.table.getField(i, "FileName")!.value! as String;
      var isCompressed = fileSize != extractedSize;
      var dataOffset = fileOffset + contentDelta;
      try {
        if (isCompressed)
          files.add(await CpkFileCompressed.read(dirName, fileName, bytes, dataOffset));
        else
          files.add(CpkFileUncompressed(dirName, fileName, dataOffset, extractedSize));
      } catch (e) {
        print("Failed to read file $dirName/$fileName");
        rethrow;
      }
    }
    return Cpk(header, toc, files);
  }
}
