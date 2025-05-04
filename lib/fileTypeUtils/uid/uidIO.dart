
// ignore_for_file: non_constant_identifier_names

import 'dart:typed_data';

import '../utils/ByteDataWrapper.dart';

class UidFile {
  late UidHeader header;
  late List<UidEntry1> entries1;
  late List<UidEntry2> entries2;
  late List<UidEntry3> entries3;

  UidFile(this.header, this.entries1, this.entries2, this.entries3);

  UidFile.read(ByteDataWrapper bytes) {
    header = UidHeader.read(bytes);
    if (header.offset1 > 0) {
      bytes.position = header.offset1;
      entries1 = List.generate(header.size1, (_) => UidEntry1.read(bytes));
    } else {
      entries1 = [];
    }
    int endOffset = header.offset2;
    if (endOffset == 0)
      endOffset = header.offset3;
    if (endOffset == 0)
      endOffset = bytes.length;
    var allOffsets = entries1.expand((entry) => entry.getOffsets()).followedBy([endOffset]).toList();
    var offsetSizes = {
      for (var (i, offset) in allOffsets.indexed.take(allOffsets.length - 1))
        offset: allOffsets[i + 1] - offset
    };
    for (var entry in entries1)
      entry.readAdditionalData(bytes, offsetSizes);
    
    if (header.offset2 > 0) {
      bytes.position = header.offset2;
      entries2 = List.generate(header.size2, (_) => UidEntry2.read(bytes));
    } else {
      entries2 = [];
    }
    if (header.offset3 > 0) {
      bytes.position = header.offset3;
      entries3 = List.generate(header.size3, (_) => UidEntry3.read(bytes));
    } else {
      entries3 = [];
    }
  }

  void write(ByteDataWrapper bytes) {
    header.write(bytes);
    bytes.position = header.offset1;
    for (var entry in entries1)
      entry.write(bytes);
    for (var entry in entries1)
      entry.writeAdditionalData(bytes);
    bytes.position = header.offset2;
    for (var entry in entries2)
      entry.write(bytes);
    bytes.position = header.offset3;
    for (var entry in entries3)
      entry.write(bytes);
  }
}

class UidHeader {
  final int size1;
  final int size2;
  final int size3;
  final int u0;
  final int offset1;
  final int offset2;
  final int offset3;
  final int null0;
  final double frameDuration;
  final double width;
  final double height;
  final int null3;

  UidHeader(this.size1, this.size2, this.size3, this.u0, this.offset1, this.offset2, this.offset3, this.null0, this.frameDuration, this.width, this.height, this.null3);

  UidHeader.read(ByteDataWrapper bytes) :
    size1 = bytes.readUint32(),
    size2 = bytes.readUint32(),
    size3 = bytes.readUint32(),
    u0 = bytes.readUint32(),
    offset1 = bytes.readUint32(),
    offset2 = bytes.readUint32(),
    offset3 = bytes.readUint32(),
    null0 = bytes.readUint32(),
    frameDuration = bytes.readFloat32(),
    width = bytes.readFloat32(),
    height = bytes.readFloat32(),
    null3 = bytes.readUint32() {
    if (size1 > 0x10000) {
      throw Exception("Big endian UID not supported");
    }
  }
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(size1);
    bytes.writeUint32(size2);
    bytes.writeUint32(size3);
    bytes.writeUint32(u0);
    bytes.writeUint32(offset1);
    bytes.writeUint32(offset2);
    bytes.writeUint32(offset3);
    bytes.writeUint32(null0);
    bytes.writeFloat32(frameDuration);
    bytes.writeFloat32(width);
    bytes.writeFloat32(height);
    bytes.writeUint32(null3);
  }
}

class UidEntry1 {
  late Vector translation;
  late Vector rotation;
  late Vector scale;
  late Vector rgb;
  late double alpha;
  late List<double> moreFloats;
  late int entry2_index;
  late int entry2_id;
  late int uint_2;
  late int uint_3;
  late double float_4;
  late int uint_5;
  late double float_6;
  late int int_7;
  late int bool_8;
  late int bool_9;
  late int bool_10;
  late int bool_11;
  late int bool_12;
  late int bool_13;
  late int bool_14;
  late int bool_15;
  late int null_16;
  late int bool_17;
  late int bool_18;
  late double float_19;
  late int uint_20;
  late double float_21;
  late int bool_22;
  late double float_23;
  late int uint_24;
  late double float_25;
  late int bool_26;
  late double float_27;
  late int bool_28;
  late double float_29;
  late int bool_30;
  late double float_31;
  late int uint_32;
  late double float_33;
  late int bool_34;
  late double float_35;
  late int uint_36;
  late double float_37;
  late int bool_38;
  late double float_39;
  late int uint_40;
  late double float_41;
  late int null_42;
  late double float_43;
  late int uint_44;
  late double float_45;
  late int null_46;
  late double float_47;
  late int uint_48;
  late double float_49;
  late int bool_50;
  late int null_51;
  late int null_52;
  late int null_53;
  late int null_54;
  late int null_55;
  late int null_56;
  late int null_57;
  late int null_58;
  late int null_59;
  late int null_60;
  late int null_61;
  late int null_62;
  late double float_63;
  late int uint_64;
  late double float_65;
  late int bool_66;
  late int null_67;
  late int null_68;
  late int null_69;
  late int null_70;
  late double float_71;
  late int uint_72;
  late double float_73;
  late int bool_74;
  late double float_75;
  late int uint_76;
  late double float_77;
  late int bool_78;
  late double float_79;
  late int uint_80;
  late double float_81;
  late int bool_82;
  late int uint_83;
  late int uint_84;
  late int uint_85;
  late int uint_86;
  late int data1Offset;
  late int data2Offset;
  late int data3Offset;
  late int u4;
  UidData1? data1;
  UidData2? data2;
  UidData3? data3;

  UidEntry1.read(ByteDataWrapper bytes) {
    translation = Vector.read(bytes);
    rotation = Vector.read(bytes);
    scale = Vector.read(bytes);
    rgb = Vector.read(bytes);
    alpha = bytes.readFloat32();
    moreFloats = bytes.readFloat32List(4);
    entry2_index = bytes.readInt32();
    entry2_id = bytes.readUint32();
    uint_2 = bytes.readUint32();
    uint_3 = bytes.readUint32();
    float_4 = bytes.readFloat32();
    uint_5 = bytes.readUint32();
    float_6 = bytes.readFloat32();
    int_7 = bytes.readInt32();
    bool_8 = bytes.readUint32();
    bool_9 = bytes.readUint32();
    bool_10 = bytes.readUint32();
    bool_11 = bytes.readUint32();
    bool_12 = bytes.readUint32();
    bool_13 = bytes.readUint32();
    bool_14 = bytes.readUint32();
    bool_15 = bytes.readUint32();
    null_16 = bytes.readUint32();
    bool_17 = bytes.readUint32();
    bool_18 = bytes.readUint32();
    float_19 = bytes.readFloat32();
    uint_20 = bytes.readUint32();
    float_21 = bytes.readFloat32();
    bool_22 = bytes.readUint32();
    float_23 = bytes.readFloat32();
    uint_24 = bytes.readUint32();
    float_25 = bytes.readFloat32();
    bool_26 = bytes.readUint32();
    float_27 = bytes.readFloat32();
    bool_28 = bytes.readUint32();
    float_29 = bytes.readFloat32();
    bool_30 = bytes.readUint32();
    float_31 = bytes.readFloat32();
    uint_32 = bytes.readUint32();
    float_33 = bytes.readFloat32();
    bool_34 = bytes.readUint32();
    float_35 = bytes.readFloat32();
    uint_36 = bytes.readUint32();
    float_37 = bytes.readFloat32();
    bool_38 = bytes.readUint32();
    float_39 = bytes.readFloat32();
    uint_40 = bytes.readUint32();
    float_41 = bytes.readFloat32();
    null_42 = bytes.readUint32();
    float_43 = bytes.readFloat32();
    uint_44 = bytes.readUint32();
    float_45 = bytes.readFloat32();
    null_46 = bytes.readUint32();
    float_47 = bytes.readFloat32();
    uint_48 = bytes.readUint32();
    float_49 = bytes.readFloat32();
    bool_50 = bytes.readUint32();
    null_51 = bytes.readUint32();
    null_52 = bytes.readUint32();
    null_53 = bytes.readUint32();
    null_54 = bytes.readUint32();
    null_55 = bytes.readUint32();
    null_56 = bytes.readUint32();
    null_57 = bytes.readUint32();
    null_58 = bytes.readUint32();
    null_59 = bytes.readUint32();
    null_60 = bytes.readUint32();
    null_61 = bytes.readUint32();
    null_62 = bytes.readUint32();
    float_63 = bytes.readFloat32();
    uint_64 = bytes.readUint32();
    float_65 = bytes.readFloat32();
    bool_66 = bytes.readUint32();
    null_67 = bytes.readUint32();
    null_68 = bytes.readUint32();
    null_69 = bytes.readUint32();
    null_70 = bytes.readUint32();
    float_71 = bytes.readFloat32();
    uint_72 = bytes.readUint32();
    float_73 = bytes.readFloat32();
    bool_74 = bytes.readUint32();
    float_75 = bytes.readFloat32();
    uint_76 = bytes.readUint32();
    float_77 = bytes.readFloat32();
    bool_78 = bytes.readUint32();
    float_79 = bytes.readFloat32();
    uint_80 = bytes.readUint32();
    float_81 = bytes.readFloat32();
    bool_82 = bytes.readUint32();
    uint_83 = bytes.readUint32();
    uint_84 = bytes.readUint32();
    uint_85 = bytes.readUint32();
    uint_86 = bytes.readUint32();
    data1Offset = bytes.readUint32();
    data2Offset = bytes.readUint32();
    data3Offset = bytes.readUint32();
    u4 = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    translation.write(bytes);
    rotation.write(bytes);
    scale.write(bytes);
    rgb.write(bytes);
    bytes.writeFloat32(alpha);
    for (var f in moreFloats)
      bytes.writeFloat32(f);
    bytes.writeInt32(entry2_index);
    bytes.writeUint32(entry2_id);
    bytes.writeUint32(uint_2);
    bytes.writeUint32(uint_3);
    bytes.writeFloat32(float_4);
    bytes.writeUint32(uint_5);
    bytes.writeFloat32(float_6);
    bytes.writeInt32(int_7);
    bytes.writeUint32(bool_8);
    bytes.writeUint32(bool_9);
    bytes.writeUint32(bool_10);
    bytes.writeUint32(bool_11);
    bytes.writeUint32(bool_12);
    bytes.writeUint32(bool_13);
    bytes.writeUint32(bool_14);
    bytes.writeUint32(bool_15);
    bytes.writeUint32(null_16);
    bytes.writeUint32(bool_17);
    bytes.writeUint32(bool_18);
    bytes.writeFloat32(float_19);
    bytes.writeUint32(uint_20);
    bytes.writeFloat32(float_21);
    bytes.writeUint32(bool_22);
    bytes.writeFloat32(float_23);
    bytes.writeUint32(uint_24);
    bytes.writeFloat32(float_25);
    bytes.writeUint32(bool_26);
    bytes.writeFloat32(float_27);
    bytes.writeUint32(bool_28);
    bytes.writeFloat32(float_29);
    bytes.writeUint32(bool_30);
    bytes.writeFloat32(float_31);
    bytes.writeUint32(uint_32);
    bytes.writeFloat32(float_33);
    bytes.writeUint32(bool_34);
    bytes.writeFloat32(float_35);
    bytes.writeUint32(uint_36);
    bytes.writeFloat32(float_37);
    bytes.writeUint32(bool_38);
    bytes.writeFloat32(float_39);
    bytes.writeUint32(uint_40);
    bytes.writeFloat32(float_41);
    bytes.writeUint32(null_42);
    bytes.writeFloat32(float_43);
    bytes.writeUint32(uint_44);
    bytes.writeFloat32(float_45);
    bytes.writeUint32(null_46);
    bytes.writeFloat32(float_47);
    bytes.writeUint32(uint_48);
    bytes.writeFloat32(float_49);
    bytes.writeUint32(bool_50);
    bytes.writeUint32(null_51);
    bytes.writeUint32(null_52);
    bytes.writeUint32(null_53);
    bytes.writeUint32(null_54);
    bytes.writeUint32(null_55);
    bytes.writeUint32(null_56);
    bytes.writeUint32(null_57);
    bytes.writeUint32(null_58);
    bytes.writeUint32(null_59);
    bytes.writeUint32(null_60);
    bytes.writeUint32(null_61);
    bytes.writeUint32(null_62);
    bytes.writeFloat32(float_63);
    bytes.writeUint32(uint_64);
    bytes.writeFloat32(float_65);
    bytes.writeUint32(bool_66);
    bytes.writeUint32(null_67);
    bytes.writeUint32(null_68);
    bytes.writeUint32(null_69);
    bytes.writeUint32(null_70);
    bytes.writeFloat32(float_71);
    bytes.writeUint32(uint_72);
    bytes.writeFloat32(float_73);
    bytes.writeUint32(bool_74);
    bytes.writeFloat32(float_75);
    bytes.writeUint32(uint_76);
    bytes.writeFloat32(float_77);
    bytes.writeUint32(bool_78);
    bytes.writeFloat32(float_79);
    bytes.writeUint32(uint_80);
    bytes.writeFloat32(float_81);
    bytes.writeUint32(bool_82);
    bytes.writeUint32(uint_83);
    bytes.writeUint32(uint_84);
    bytes.writeUint32(uint_85);
    bytes.writeUint32(uint_86);
    bytes.writeUint32(data1Offset);
    bytes.writeUint32(data2Offset);
    bytes.writeUint32(data3Offset);
    bytes.writeUint32(u4);
  }

  List<int> getOffsets() => [data1Offset, data2Offset, data3Offset].where((offset) => offset != 0).toList();

  void readAdditionalData(ByteDataWrapper bytes, Map<int, int> offsetStructSizes) {
    if (data1Offset != 0) {
      bytes.position = data1Offset;
      data1 = UidData1.read(bytes, offsetStructSizes[data1Offset]!);
    }
    if (data2Offset != 0) {
      bytes.position = data2Offset;
      data2 = UidData2.read(bytes, offsetStructSizes[data2Offset]!);
    }
    if (data3Offset != 0) {
      bytes.position = data3Offset;
      data3 = UidData3.read(bytes, offsetStructSizes[data3Offset]!);
    }
  }

  void writeAdditionalData(ByteDataWrapper bytes) {
    if (data1 != null) {
      bytes.position = data1Offset;
      data1!.write(bytes);
    }
    if (data2 != null) {
      bytes.position = data2Offset;
      data2!.write(bytes);
    }
    if (data3 != null) {
      bytes.position = data3Offset;
      data3!.write(bytes);
    }
  }
}

class UidGenericData {
  List<int> data;

  UidGenericData(this.data);

  UidGenericData.read(ByteDataWrapper bytes, int size) :
    data = bytes.asUint8List(size);

  void write(ByteDataWrapper bytes) {
    for (var i in data)
      bytes.writeUint8(i);
  }

  int get size => data.length;

  int? _readUint32At(int offset) {
    if (data.length < offset + 4)
      return null;
    var list = Uint8List.fromList(data.sublist(offset, offset + 4));
    return list.buffer.asByteData().getUint32(0, Endian.little);
  }

  void _setUint32At(int offset, int value) {
    if (data.length < offset + 4)
      throw Exception("Data too small");
    var list = Uint8List(4);
    list.buffer.asByteData().setUint32(0, value, Endian.little);
    data.setRange(offset, offset + 4, list);
  }

  double? _readFloat32At(int offset) {
    if (data.length < offset + 4)
      return null;
    var list = Uint8List.fromList(data.sublist(offset, offset + 4));
    return list.buffer.asByteData().getFloat32(0, Endian.little);
  }

  void _setFloat32At(int offset, double value) {
    if (data.length < offset + 4)
      throw Exception("Data too small");
    var list = Uint8List(4);
    list.buffer.asByteData().setFloat32(0, value, Endian.little);
    data.setRange(offset, offset + 4, list);
  }
}

class UidData1 extends UidGenericData {
  UidData1(super.data);

  UidData1.read(super.bytes, super.size) : super.read();

  bool mightBeMcdData() {
    if (data.length < 36)
      return false;
    var nameBytes = data.sublist(16, 32);
    var isReadingName = true;
    for (int i = 0; i < 16; i++) {
      if (isReadingName) {
        if (nameBytes[i] == 0) {
          if (i < 2)
            return false;
          isReadingName = false;
        }
        else {
          var isAscii = nameBytes[i] >= 32 && nameBytes[i] < 127;
          if (!isAscii)
            return false;
        }
      }
      else {
        if (nameBytes[i] != 0)
          return false;
      }
    }
    
    var id = _readUint32At(32)!;
    if (id < 10 || id == 0xFFFFFFFF)
      return false;
    return true;
  }

  bool mightBeUvdData() {
    if (data.length < 36)
      return false;
    var bd = Uint8List.fromList(data).buffer.asByteData();
    var width = bd.getFloat32(0, Endian.little);
    var height = bd.getFloat32(4, Endian.little);
    var texId = bd.getUint32(28, Endian.little);
    var uvdId = bd.getUint32(32, Endian.little);

    var widthIsInt = width.floor() == width.ceil();
    var heightIsInt = height.floor() == height.ceil();
    var texIdIsId = texId > 10 && texId != 0xFFFFFFFF;
    var uvdIdIsId = uvdId > 10 && uvdId != 0xFFFFFFFF;
    return widthIsInt && heightIsInt && texIdIsId && uvdIdIsId;
  }

  String? getMcdFileName() {
    if (data.length < 36)
      return null;
    var nameBytes = data.sublist(16, 32);
    var name = String.fromCharCodes(nameBytes).replaceAll("\x00", "");
    return name;
  }

  void setMcdFileName(String name) {
    if (data.length < 36)
      throw Exception("Data too small");
    if (name.length > 16)
      throw Exception("Name too long");
    var nameBytes = name.codeUnits;
    data.setRange(16, 16 + nameBytes.length, nameBytes);
    data.fillRange(16 + nameBytes.length, 16 + 16, 0);
  }

  int? getMcdEntryId() {
    if (data.length < 36)
      return null;
    return _readUint32At(32);
  }

  void setMcdEntryId(int id) {
    _setUint32At(32, id);
  }

  double? getUvdWidth() {
    return _readFloat32At(0);
  }

  void setUvdWidth(double width) {
    _setFloat32At(0, width);
  }

  double? getUvdHeight() {
    return _readFloat32At(4);
  }

  void setUvdHeight(double height) {
    _setFloat32At(4, height);
  }

  int? getUvdTexId() {
    return _readUint32At(28);
  }

  void setUvdTexId(int id) {
    _setUint32At(28, id);
  }

  int? getUvdId() {
    return _readUint32At(32);
  }

  void setUvdId(int id) {
    _setUint32At(32, id);
  }
}

class UidData2 extends UidGenericData {
  UidData2(super.data);

  UidData2.read(super.bytes, super.size) : super.read();
}

class UidData3 extends UidGenericData {
  UidData3(super.data);

  UidData3.read(super.bytes, super.size) : super.read();
}

class Vector {
  final double x;
  final double y;
  final double z;

  Vector(this.x, this.y, this.z);

  Vector.fromList(List<double> list) :
    x = list[0],
    y = list[1],
    z = list[2];

  Vector.read(ByteDataWrapper bytes) :
    x = bytes.readFloat32(),
    y = bytes.readFloat32(),
    z = bytes.readFloat32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(x);
    bytes.writeFloat32(y);
    bytes.writeFloat32(z);
  }

  List<double> toList() => [x, y, z];

  @override
  String toString() => '($x, $y, $z)';
}



class UidEntry2 {
  final int id;
  final int entry1_index;

  UidEntry2(this.id, this.entry1_index);

  UidEntry2.read(ByteDataWrapper bytes) :
    id = bytes.readUint32(),
    entry1_index = bytes.readUint32();

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(id);
    bytes.writeUint32(entry1_index);
  }
}

class UidEntry3 {
  final int entry2_id_maybe;
  final double f0;
  final double f1;
  final List<int> u1;

  UidEntry3(this.entry2_id_maybe, this.f0, this.f1, this.u1);

  UidEntry3.read(ByteDataWrapper bytes) :
    entry2_id_maybe = bytes.readUint32(),
    f0 = bytes.readFloat32(),
    f1 = bytes.readFloat32(),
    u1 = bytes.readUint32List(13);

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(entry2_id_maybe);
    bytes.writeFloat32(f0);
    bytes.writeFloat32(f1);
    for (var i in u1)
      bytes.writeUint32(i);
  }
}