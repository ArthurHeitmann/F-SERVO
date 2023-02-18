
// ignore_for_file: non_constant_identifier_names

import '../utils/ByteDataWrapper.dart';

/*
struct Header
{
	uint32 size1;
	uint32 size2;
	uint32 size3;
	uint32 offset1;
	uint32 offset2;
	uint32 offset3;
	float floatInverse<read=inverseToStr>;
	uint32 u_0;
	uint32 null0;
	uint32 null1;
	uint32 null2;
	uint32 null3;
};
*/
class UidHeader {
  final int size1;
  final int size2;
  final int size3;
  final int offset1;
  final int offset2;
  final int offset3;
  final double floatInverse;
  final int u_0;
  final int null0;
  final int null1;
  final int null2;
  final int null3;

  const UidHeader(this.size1, this.size2, this.size3, this.offset1, this.offset2,
      this.offset3, this.floatInverse, this.u_0, this.null0, this.null1,
      this.null2, this.null3);
  
  UidHeader.read(ByteDataWrapper bytes) :
    size1 = bytes.readUint32(),
    size2 = bytes.readUint32(),
    size3 = bytes.readUint32(),
    offset1 = bytes.readUint32(),
    offset2 = bytes.readUint32(),
    offset3 = bytes.readUint32(),
    floatInverse = bytes.readFloat32(),
    u_0 = bytes.readUint32(),
    null0 = bytes.readUint32(),
    null1 = bytes.readUint32(),
    null2 = bytes.readUint32(),
    null3 = bytes.readUint32();

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(size1);
    bytes.writeUint32(size2);
    bytes.writeUint32(size3);
    bytes.writeUint32(offset1);
    bytes.writeUint32(offset2);
    bytes.writeUint32(offset3);
    bytes.writeFloat32(floatInverse);
    bytes.writeUint32(u_0);
    bytes.writeUint32(null0);
    bytes.writeUint32(null1);
    bytes.writeUint32(null2);
    bytes.writeUint32(null3);
  }
}

/*
struct Data2
{
	uint32 u_0;
	uint32 u_1;
	uint32 u_2;
	uint32 u_3[3];
	float f_4;
	float f_5;
	float f_6;
	float f_7;
	float f_8;
	float f_9;
	float f_10;
	uint32 u_11;
};
*/
class Data2 {
  final int u_0;
  final int u_1;
  final int u_2;
  final List<int> u_3;
  final double f_4;
  final double f_5;
  final double f_6;
  final double f_7;
  final double f_8;
  final double f_9;
  final double f_10;
  final int u_11;

  const Data2(this.u_0, this.u_1, this.u_2, this.u_3, this.f_4, this.f_5,
      this.f_6, this.f_7, this.f_8, this.f_9, this.f_10, this.u_11);
  
  Data2.read(ByteDataWrapper bytes) :
    u_0 = bytes.readUint32(),
    u_1 = bytes.readUint32(),
    u_2 = bytes.readUint32(),
    u_3 = bytes.readUint32List(3),
    f_4 = bytes.readFloat32(),
    f_5 = bytes.readFloat32(),
    f_6 = bytes.readFloat32(),
    f_7 = bytes.readFloat32(),
    f_8 = bytes.readFloat32(),
    f_9 = bytes.readFloat32(),
    f_10 = bytes.readFloat32(),
    u_11 = bytes.readUint32();

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(u_0);
    bytes.writeUint32(u_1);
    bytes.writeUint32(u_2);
    for (int i = 0; i < 3; i++)
      bytes.writeUint32(u_3[i]);
    bytes.writeFloat32(f_4);
    bytes.writeFloat32(f_5);
    bytes.writeFloat32(f_6);
    bytes.writeFloat32(f_7);
    bytes.writeFloat32(f_8);
    bytes.writeFloat32(f_9);
    bytes.writeFloat32(f_10);
    bytes.writeUint32(u_11);
  }
}

/*
struct Data3
{
	local int firstOffset = ReadInt();
	local int entriesCount = (firstOffset - FTell()) / 32;
	Data3Header headers[entriesCount];
	local int i = 0;
	for (i = 0; i < entriesCount; i++) {
		struct {
			FSeek(headers[i].beginOffset);
			Data3Entry subEntries[headers[i].size1];
		} entries;
	}
};

struct Data3Header
{
	uint32 beginOffset;
	uint32 size1;
	uint32 size2;
	uint32 u_0;
	uint32 u_1;
	float f_2;
	float f_3;
	uint32 u_4;
};
struct Data3Entry
{
	float f_0;
	uint32 u_1;
};
*/
class AnimationData {
  late final List<AnimationDataHeader> headers;
  late final List<List<KeyFrame>> keyFrames;

  AnimationData(this.headers, this.keyFrames);

  AnimationData.read(ByteDataWrapper bytes) {
    int firstOffset = bytes.readUint32();
    bytes.position -= 4;
    int entriesCount = (firstOffset - bytes.position) ~/ 32;
    headers = List.generate(entriesCount, (i) => AnimationDataHeader.read(bytes));
    keyFrames = [];
    for (int i = 0; i < entriesCount; i++) {
      bytes.position = headers[i].beginOffset;
      keyFrames.add(List.generate(headers[i].size1, (i) => KeyFrame.read(bytes)));
    }
  }
}
class AnimationDataHeader {
  final int beginOffset;
  final int size1;
  final int u_0;
  final int u_1;
  final int u_2;
  final double f_2;
  final double f_3;
  final int u_4;

  const AnimationDataHeader(this.beginOffset, this.size1, this.u_0, this.u_1, this.u_2,
      this.f_2, this.f_3, this.u_4);
  
  AnimationDataHeader.read(ByteDataWrapper bytes) :
    beginOffset = bytes.readUint32(),
    size1 = bytes.readUint32(),
    u_0 = bytes.readUint32(),
    u_1 = bytes.readUint32(),
    u_2 = bytes.readUint32(),
    f_2 = bytes.readFloat32(),
    f_3 = bytes.readFloat32(),
    u_4 = bytes.readUint32();

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(beginOffset);
    bytes.writeUint32(size1);
    bytes.writeUint32(u_0);
    bytes.writeUint32(u_1);
    bytes.writeUint32(u_2);
    bytes.writeFloat32(f_2);
    bytes.writeFloat32(f_3);
    bytes.writeUint32(u_4);
  }
}

class KeyFrame {
  final double t;
  final int val;

  const KeyFrame(this.t, this.val);
  
  KeyFrame.read(ByteDataWrapper bytes) :
    t = bytes.readFloat32(),
    val = bytes.readUint32();

  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(t);
    bytes.writeUint32(val);
  }
}

/*
struct Entry1
{
	// uint32 bytes[109];
	float f_u_0;
	float f_u_1;
	uint32 null0;
	uint32 null1;
	uint32 null2;
	uint32 null3;
	float scaleX;
	float scaleY;
	float f_u_2;
	float R;
	float G;
	float B;
	float moreFloats[5];
	uint32 bytes_1[88];
	uint32 dataOffset1;
	if (dataOffset1 != 0)
		Printf("dataOffset1 = %d\n", dataOffset1);
	uint32 dataOffset2;
	if (dataOffset2 != 0)
		Printf("dataOffset2 = %d\n", dataOffset2);
	uint32 dataOffset3;
	if (dataOffset3 != 0)
		Printf("dataOffset3 = %d\n", dataOffset3);
	uint32 u_4;
	if (u_4 != 0)
		Printf("u_4 = %d\n", u_4);

	local int pos = FTell();
	if (dataOffset1 != 0) {
		FSeek(dataOffset1);
		Data1 data1<bgcolor=color4>;
	}
	if (dataOffset2 != 0) {
		FSeek(dataOffset2);
		Data2 data2<bgcolor=color5>;
	}
	if (dataOffset3 != 0) {
		FSeek(dataOffset3);
		Data3 data3<bgcolor=color6>;
	}
	FSeek(pos);
};
*/
class Entry1 {
  late final double f_u_0;
  late final double f_u_1;
  late final int null0;
  late final int null1;
  late final int null2;
  late final int null3;
  late final double scaleX;
  late final double scaleY;
  late final double f_u_2;
  late final double R;
  late final double G;
  late final double B;
  late final List<double> moreFloats;
  late final List<int> bytes_1;
  late final int dataOffset1;
  late final int dataOffset2;
  late final int dataOffset3;
  late final int u_4;
  // final Data1? data1;
  late final Data2? data2;
  late final AnimationData? data3;

  Entry1(this.f_u_0, this.f_u_1, this.null0, this.null1, this.null2, this.null3,
      this.scaleX, this.scaleY, this.f_u_2, this.R, this.G, this.B, this.moreFloats, this.bytes_1,
      this.dataOffset1, this.dataOffset2, this.dataOffset3, this.u_4, /*this.data1,*/ this.data2, this.data3);

  Entry1.read(ByteDataWrapper bytes) {
    f_u_0 = bytes.readFloat32();
    f_u_1 = bytes.readFloat32();
    null0 = bytes.readUint32();
    null1 = bytes.readUint32();
    null2 = bytes.readUint32();
    null3 = bytes.readUint32();
    scaleX = bytes.readFloat32();
    scaleY = bytes.readFloat32();
    f_u_2 = bytes.readFloat32();
    R = bytes.readFloat32();
    G = bytes.readFloat32();
    B = bytes.readFloat32();
    moreFloats = List.generate(5, (i) => bytes.readFloat32());
    bytes.readUint32();
    bytes_1 = List.generate(87, (i) => bytes.readUint32());
    dataOffset1 = bytes.readUint32();
    dataOffset2 = bytes.readUint32();
    dataOffset3 = bytes.readUint32();
    u_4 = bytes.readUint32();

    int pos = bytes.position;
    if (dataOffset1 != 0) {
      bytes.position = dataOffset1;
      // data1 = Data1.read(bytes);
    }
    if (dataOffset2 != 0) {
      bytes.position = dataOffset2;
      data2 = Data2.read(bytes);
    }
    if (dataOffset3 != 0) {
      bytes.position = dataOffset3;
      data3 = AnimationData.read(bytes);
    }
    bytes.position = pos;
  }
}

class UidFile {
  late UidHeader header;
  late List<Entry1> entries1;

  UidFile(this.header, this.entries1);

  UidFile.read(ByteDataWrapper bytes) {
    header = UidHeader.read(bytes);
    bytes.position = header.offset1;
    entries1 = List.generate(header.size1, (i) => Entry1.read(bytes));
  }
}
