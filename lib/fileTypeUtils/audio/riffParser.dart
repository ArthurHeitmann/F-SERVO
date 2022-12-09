
import 'dart:math';

import '../utils/ByteDataWrapper.dart';

abstract class RiffChunk {
  final String chunkId;
  int size;

  RiffChunk(this.chunkId, this.size);

  RiffChunk.read(ByteDataWrapper bytes) :
    chunkId = bytes.readString(4),
    size = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeString(chunkId);
    bytes.writeUint32(size);
  }
}

class RiffHeader extends RiffChunk {
  late String riffType;

  RiffHeader(super.chunkId, super.size, this.riffType);

  RiffHeader.read(ByteDataWrapper bytes) : super.read(bytes) {
    riffType = bytes.readString(4);
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeString(riffType);
  }
}

mixin FormatChunk on RiffChunk {
  late int formatTag;
  late int channels;
  late int samplesPerSec;
  late int avgBytesPerSec;
  late int blockAlign;
  late int bitsPerSample;
}

class FormatChunkGeneric extends RiffChunk with FormatChunk {
  late int? cbSize;
  late int? samplesPerBlock;
  List<int>? unknown;

  FormatChunkGeneric.read(ByteDataWrapper bytes) : super.read(bytes) {
    int pos = bytes.position;
    formatTag = bytes.readUint16();
    channels = bytes.readUint16();
    samplesPerSec = bytes.readUint32();
    avgBytesPerSec = bytes.readUint32();
    blockAlign = bytes.readUint16();
    bitsPerSample = bytes.readUint16();
    if (formatTag == 17) {
      cbSize = bytes.readUint16();
      samplesPerBlock = bytes.readUint16();
    }
    if (size > bytes.position - pos) {
      unknown = bytes.readUint8List(size - (bytes.position - pos));
    }
    if (size & 1 == 1) {
      bytes.readUint8();
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint16(formatTag);
    bytes.writeUint16(channels);
    bytes.writeUint32(samplesPerSec);
    bytes.writeUint32(avgBytesPerSec);
    bytes.writeUint16(blockAlign);
    bytes.writeUint16(bitsPerSample);
    if (formatTag == 17) {
      bytes.writeUint16(cbSize!);
      bytes.writeUint16(samplesPerBlock!);
    }
    if (unknown != null) {
      for (int i = 0; i < unknown!.length; i++)
        bytes.writeUint8(unknown![i]);
    }
    if (size & 1 == 1) {
      bytes.writeUint8(0);
    }
  }
}

class WemFormatChunk extends RiffChunk with FormatChunk {
  late int extraSize;
  late int zeroMaybe;
  late int channelLayoutMask;
  late int numSamples;
  late List<int> extraUnknown;
  late int setupPacketOffset;
  late int firstAudioPacketOffset;
  late List<int> extraDataUnknown;
  late int uidMaybe;
  late int blockSize0Exp;
  late int blockSize1Exp;

  WemFormatChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    formatTag = bytes.readUint16();
    channels = bytes.readUint16();
    samplesPerSec = bytes.readUint32();
    avgBytesPerSec = bytes.readUint32();
    blockAlign = bytes.readUint16();
    bitsPerSample = bytes.readUint16();
    extraSize = bytes.readUint16();
    zeroMaybe = bytes.readUint16();
    channelLayoutMask = bytes.readUint32();
    numSamples = bytes.readInt32();
    extraUnknown = bytes.readUint8List(0x10 - 4);
    setupPacketOffset = bytes.readUint32();
    firstAudioPacketOffset = bytes.readUint32();
    extraDataUnknown = bytes.readUint8List(0x28 - 0x10 - 0x08 - 0x04);
    uidMaybe = bytes.readUint32();
    blockSize0Exp = bytes.readUint8();
    blockSize1Exp = bytes.readUint8();
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint16(formatTag);
    bytes.writeUint16(channels);
    bytes.writeUint32(samplesPerSec);
    bytes.writeUint32(avgBytesPerSec);
    bytes.writeUint16(blockAlign);
    bytes.writeUint16(bitsPerSample);
    bytes.writeUint16(extraSize);
    bytes.writeUint16(zeroMaybe);
    bytes.writeUint32(channelLayoutMask);
    bytes.writeInt32(numSamples);
    for (int i = 0; i < extraUnknown.length; i++)
      bytes.writeUint8(extraUnknown[i]);
    bytes.writeUint32(setupPacketOffset);
    bytes.writeUint32(firstAudioPacketOffset);
    for (int i = 0; i < extraDataUnknown.length; i++)
      bytes.writeUint8(extraDataUnknown[i]);
    bytes.writeUint32(uidMaybe);
    bytes.writeUint8(blockSize0Exp);
    bytes.writeUint8(blockSize1Exp);
  }
}

class AkdChunk extends RiffChunk {
  late double unknownFloat1;
  late double unknownFloat2;
  late int unknownZero1;
  late int unknownZero2;

  AkdChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    unknownFloat1 = bytes.readFloat32();
    unknownFloat2 = bytes.readFloat32();
    unknownZero1 = bytes.readUint32();
    unknownZero2 = bytes.readUint32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeFloat32(unknownFloat1);
    bytes.writeFloat32(unknownFloat2);
    bytes.writeUint32(unknownZero1);
    bytes.writeUint32(unknownZero2);
  }
}

typedef Sample = List<int>;
class DataChunk extends RiffChunk {
  late List<int> samples;
  FormatChunk format;

  DataChunk(super.chunkId, super.size, this.samples, this.format);

  DataChunk.read(ByteDataWrapper bytes, this.format) : super.read(bytes) {
    switch (format.bitsPerSample) {
      case 8:
        samples = bytes.asInt8List(size);
        break;
      case 16:
        if (bytes.position % 2 == 0)
          samples = bytes.asInt16List(size ~/ 2);
        else
          samples = List.generate(size ~/ 2, (i) => bytes.readInt16()); 
        break;
      case 32:
        if (bytes.position % 4 == 0)
            samples = bytes.asInt32List(size ~/ 4);
        else
          samples = List.generate(size ~/ 4, (i) => bytes.readInt32()); 
        break;
      default:
        samples = bytes.asInt8List(size);
    }
    if (size & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    switch (format.bitsPerSample) {
      case 8:
        for (int i = 0; i < samples.length; i++)
          bytes.writeInt8(samples[i]);
        break;
      case 16:
        for (int i = 0; i < samples.length; i++)
          bytes.writeInt16(samples[i]);
        break;
      case 32:
        for (int i = 0; i < samples.length; i++)
          bytes.writeInt32(samples[i]);
        break;
      default:
        for (int i = 0; i < samples.length; i++)
          bytes.writeInt8(samples[i]);
    }
    if (size & 1 == 1 && bytes.position < bytes.length) {
      bytes.writeUint8(0);
    }
  }

  List<Sample> asSamples(FormatChunk format)  {
    final bitsPerSample = format.bitsPerSample;
    final channels = format.channels;
    final blockAlign = format.blockAlign;
    if ((bitsPerSample != 8 && bitsPerSample != 16 && bitsPerSample != 32) ||
        (size % blockAlign != 0)) {
      return samples.map((e) => [e]).toList();
    } else if (channels == 1) {
      return samples.map((e) => [e]).toList();
    } else {
      var subSamples = List.generate(size ~/ blockAlign, (i) => samples.sublist(i, i + channels));
      return subSamples;
    }
  }
}

class CuePoint {
  late int identifier;
  late int position;
  late String fccChunk;
  late int chunkStart;
  late int blockStart;
  late int sampleOffset;

  CuePoint(this.identifier, this.position, this.fccChunk, this.chunkStart,
      this.blockStart, this.sampleOffset);

  CuePoint.read(ByteDataWrapper bytes) {
    identifier = bytes.readUint32();
    position = bytes.readUint32();
    fccChunk = bytes.readString(4);
    chunkStart = bytes.readUint32();
    blockStart = bytes.readUint32();
    sampleOffset = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(identifier);
    bytes.writeUint32(position);
    bytes.writeString(fccChunk);
    bytes.writeUint32(chunkStart);
    bytes.writeUint32(blockStart);
    bytes.writeUint32(sampleOffset);
  }
}

class CueChunk extends RiffChunk {
  late int cuePoints;
  late List<CuePoint> points;
  List<int>? extra;

  CueChunk(this.cuePoints, this.points, [this.extra])
    : super("cue ", 4 + 24 * points.length + (extra?.length ?? 0));

  CueChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    int pos = bytes.position;
    cuePoints = bytes.readUint32();
    points = List.generate(cuePoints, (_) => CuePoint.read(bytes));
    if (size > (bytes.position - pos)) {
      extra = bytes.readUint8List(size - (bytes.position - pos));
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint32(cuePoints);
    for (int i = 0; i < points.length; i++)
      points[i].write(bytes);
    if (extra != null) {
      for (int i = 0; i < extra!.length; i++)
        bytes.writeUint8(extra![i]);
    }
  }
}

abstract class RiffListSubChunk extends RiffChunk {
  RiffListSubChunk(String chunkId, int size) : super(chunkId, size);

  RiffListSubChunk.read(ByteDataWrapper bytes) : super.read(bytes);
}

class RiffListGenericSubChunk extends RiffListSubChunk {
  late List<int> data;

  RiffListGenericSubChunk(super.chunkID, super.size, this.data);

  RiffListGenericSubChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    data = bytes.readUint8List(size);
    if (size & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    for (int i = 0; i < data.length; i++)
      bytes.writeUint8(data[i]);
    if (size & 1 == 1) {
      bytes.writeUint8(0);
    }
  }
}

class RiffListLabelSubChunk extends RiffListSubChunk {
  late int cuePointIndex;
  late String label;

  RiffListLabelSubChunk(super.chunkID, super.size, this.cuePointIndex,
      this.label);
    
  RiffListLabelSubChunk.read(ByteDataWrapper bytes)
    : super(bytes.readString(4), bytes.readUint32()) {
    cuePointIndex = bytes.readUint32();
    label = bytes.readString(size - 4).replaceAll("\x00", "");
    if (size & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint32(cuePointIndex);
    bytes.writeString0P(label);
    if (size & 1 == 1) {
      bytes.writeUint8(0);
    }
  }
}

class RiffListChunk extends RiffChunk {
  late String chunkType;
  late List<RiffListSubChunk> subChunks;

  RiffListChunk(this.chunkType, this.subChunks, int size)
    : super("LIST", size);

  RiffListChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    int pos = bytes.position;
    chunkType = bytes.readString(4);
    subChunks = [];
    while (bytes.position - pos < size) {
      bytes.position += 4;
      int nextSize = bytes.readUint32();
      bytes.position -= 8;
      if (bytes.position - pos + nextSize <= size) {
        if (chunkType == "adtl")
          subChunks.add(RiffListLabelSubChunk.read(bytes));
        else
          subChunks.add(RiffListGenericSubChunk.read(bytes));
      } else {
        bytes.readUint8List(nextSize - (bytes.position - pos));
      }
    }
    if (size & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeString(chunkType);
    for (int i = 0; i < subChunks.length; i++)
      subChunks[i].write(bytes);
    if (size & 1 == 1) {
      bytes.writeUint8(0);
    }
  }
}

class RiffUnknownChunk extends RiffChunk {
  late List<int> unknownData;

  RiffUnknownChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    var bytesToRead = min(size, bytes.length - bytes.position);
    unknownData = bytes.readUint8List(bytesToRead);
    if (size & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    for (int i = 0; i < unknownData.length; i++)
      bytes.writeUint8(unknownData[i]);
    if (size & 1 == 1) {
      bytes.writeUint8(0);
    }
  }
}

class RiffFile {
  List<RiffChunk> chunks = [];
  RiffHeader get header => chunks[0] as RiffHeader;
  FormatChunk get format => chunks[1] as FormatChunk;
  DataChunk get data => chunks.whereType<DataChunk>().first;
  CueChunk? get cues {
    var cueChunks = chunks.whereType<CueChunk>();
    return cueChunks.isEmpty ? null : cueChunks.first;
  }
  RiffListChunk? get labelsList {
    var labelChunks = chunks.whereType<RiffListChunk>()
      .where((chunk) => chunk.chunkType == "adtl");
    return labelChunks.isEmpty ? null : labelChunks.first;
  }

  RiffFile(this.chunks);

  RiffFile.fromBytes(ByteDataWrapper bytes) {
    var header = RiffHeader.read(bytes);
    chunks.add(header);
    while (bytes.position < bytes.length) {
      String chunkID = bytes.readString(4);
      bytes.position -= 4;
      switch (chunkID) {
        case "fmt ":
          bytes.position += 4;
          var chunkSize = bytes.readUint32();
          bytes.position -= 8;
          if (chunkSize == 66)
            chunks.add(WemFormatChunk.read(bytes));
          else
            chunks.add(FormatChunkGeneric.read(bytes));
          break;
        case "data":
          chunks.add(DataChunk.read(bytes, format));
          break;
        case "cue ":
          chunks.add(CueChunk.read(bytes));
          break;
        case "LIST":
          chunks.add(RiffListChunk.read(bytes));
          break;
        default:
          chunks.add(RiffUnknownChunk.read(bytes));
          break;
      }
    }
  }

  RiffFile.onlyFormat(ByteDataWrapper bytes) {
    var header = RiffHeader.read(bytes);
    chunks.add(header);
    bytes.position += 4;
    var chunkSize = bytes.readUint32();
    bytes.position -= 8;
    if (chunkSize == 66)
      chunks.add(WemFormatChunk.read(bytes));
    else
      chunks.add(FormatChunkGeneric.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    for (int i = 0; i < chunks.length; i++)
      chunks[i].write(bytes);
  }

  static Future<RiffFile> fromFile(String path) async {
    var bytes = await ByteDataWrapper.fromFile(path);
    return RiffFile.fromBytes(bytes);
  }

  int get size => chunks.skip(1).fold<int>(0, (p, c) => p + c.size + 8) + 12;
}
