
import '../audio/bnkPatcher.dart';
import '../utils/ByteDataWrapper.dart';
import 'estEntryTypes.dart';

class EstHeader {
  late String id;
  late int recordCount;
  late int recordOffsetsOffset;
  late int typesOffset;
  late int recordsOffset;
  late int typeSize;
  late int typeNumber;

  EstHeader();

  EstHeader.read(ByteDataWrapper bytes) {
    id = bytes.readString(4);
    recordCount = bytes.readUint32();
    recordOffsetsOffset = bytes.readUint32();
    typesOffset = bytes.readUint32();
    recordsOffset = bytes.readUint32();
    typeSize = bytes.readUint32();
    typeNumber = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeString(id);
    bytes.writeUint32(recordCount);
    bytes.writeUint32(recordOffsetsOffset);
    bytes.writeUint32(typesOffset);
    bytes.writeUint32(recordsOffset);
    bytes.writeUint32(typeSize);
    bytes.writeUint32(typeNumber);
  }

  static const structSize = 28;
}

class EstTypeHeader {
  late int u_a;
  late String id;
  late int size;
  late int localOffset;

  EstTypeHeader(this.u_a, this.id, this.size, this.localOffset);

  EstTypeHeader.read(ByteDataWrapper bytes) {
    u_a = bytes.readUint32();
    id = bytes.readString(4);
    size = bytes.readUint32();
    localOffset = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(u_a);
    bytes.writeString(id);
    bytes.writeUint32(size);
    bytes.writeUint32(localOffset);
  }

  static const structSize = 16;
}

abstract class EstTypeEntry {
  late EstTypeHeader header;

  static EstTypeEntry read(ByteDataWrapper bytes, EstTypeHeader header) {
    var makeEntryFunc = estTypeFactories[header.id];
    if (makeEntryFunc != null)
      return makeEntryFunc(bytes, header);
    return EstUnknownTypeEntry.read(bytes, header);
  }

  void write(ByteDataWrapper bytes);
}

class EstFile {
  late EstHeader header;
  late List<int> offsets;
  late List<List<EstTypeHeader>> typeHeaders;
  late List<List<EstTypeEntry>> records;
  List<String> typeNames = [];

  EstFile.read(ByteDataWrapper bytes) {
    header = EstHeader.read(bytes);

    bytes.position = header.recordOffsetsOffset;
    offsets = bytes.asUint32List(header.recordCount);
    
    bytes.position = header.typesOffset;
    typeHeaders = [];
    bytes.position = header.typesOffset;
    for (var i = 0; i < header.recordCount; i++) {
      List<EstTypeHeader> typeHeadersForRecord = [];
      for (var j = 0; j < header.typeNumber; j++) {
        typeHeadersForRecord.add(EstTypeHeader.read(bytes));
      }
      typeHeaders.add(typeHeadersForRecord);

      if (typeNames.isEmpty && typeHeadersForRecord.isNotEmpty) {
        typeNames = typeHeadersForRecord.map((e) => e.id).toList();
      }
    }

    records = [];
    for (var recordI = 0; recordI < header.recordCount; recordI++) {
      List<EstTypeEntry> record = [];
      for (var typeI = 0; typeI < header.typeNumber; typeI++) {
        if (typeHeaders[recordI][typeI].size == 0)
          continue;
        var localOffset = typeHeaders[recordI][typeI].localOffset;
        bytes.position = offsets[recordI] + localOffset;
        record.add(EstTypeEntry.read(
          bytes,
          typeHeaders[recordI][typeI]
        ));
      }
      records.add(record);
    }
  }

  EstFile.fromRecords(this.records, this.typeNames) {
    header = EstHeader();
    header.id = "EFF\x00";
    header.recordCount = records.length;
    header.recordsOffset = 0;
    header.typesOffset = 0;
    header.recordOffsetsOffset = 0;
    header.typeSize = EstTypeHeader.structSize;
    header.typeNumber = typeNames.length;

    typeHeaders = [];

    updateHeaders();
  }

  void write(ByteDataWrapper bytes) {
    updateHeaders();

    header.write(bytes);

    bytes.position = header.recordOffsetsOffset;
    for (var i = 0; i < offsets.length; i++) {
      bytes.writeUint32(offsets[i]);
    }

    bytes.position = header.typesOffset;
    for (var i = 0; i < typeHeaders.length; i++) {
      for (var j = 0; j < typeHeaders[i].length; j++) {
        typeHeaders[i][j].write(bytes);
      }
    }

    for (var i = 0; i < records.length; i++) {
      for (var j = 0; j < records[i].length; j++) {
        bytes.position = offsets[i] + records[i][j].header.localOffset;
        records[i][j].write(bytes);
      }
    }
  }

  void updateHeaders() {
    header.recordCount = records.length;
    header.recordOffsetsOffset = alignTo16Bytes(EstHeader.structSize);
    header.typesOffset = alignTo16Bytes(header.recordOffsetsOffset + 4 * header.recordCount);
    header.recordsOffset = alignTo16Bytes(header.typesOffset + header.recordCount * header.typeNumber * EstTypeHeader.structSize);

    offsets = List.filled(records.length, 0);
    offsets[0] = header.recordsOffset;
    for (var i = 0; i < offsets.length - 1; i++) {
      var recordSize = records[i].fold(0, (acc, cur) => acc + cur.header.size);
      offsets[i + 1] = offsets[i] + recordSize;
    }

    typeHeaders.clear();
    for (int recordI = 0; recordI < records.length; recordI++) {
      var record = records[recordI];
      if (record.isEmpty)
        continue;
      int localOffset = 0;
      typeHeaders.add([]);
      for (var type in record) {
        type.header.localOffset = localOffset;
        localOffset += type.header.size;
        typeHeaders[recordI].add(type.header);
      }
      for (int typeI = 0; typeI < typeNames.length; typeI++) {
        if (typeI < typeHeaders[recordI].length && typeNames[typeI] == typeHeaders[recordI][typeI].id)
          continue;
        typeHeaders[recordI].insert(typeI, EstTypeHeader(0, typeNames[typeI], 0, 0));
      }
    }
  }

  int calculateStructSize() {
    if (records.isEmpty)
      return EstHeader.structSize;
    if (records.last.isEmpty)
      return offsets.last;
    var lastEntry = records.last.last.header;
    return offsets.last + lastEntry.localOffset + lastEntry.size;
  }
}
