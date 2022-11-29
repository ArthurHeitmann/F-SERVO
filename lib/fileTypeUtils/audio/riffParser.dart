
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../utils/ByteDataWrapper.dart';

class RiffHeader {
  late String groupID;
  late int size;
  late String riffType;

  RiffHeader(this.groupID, this.size, this.riffType);

  RiffHeader.fromBytes(ByteDataWrapper bytes) {
    groupID = bytes.readString(4);
    size = bytes.readUint32();
    riffType = bytes.readString(4);
  }
}

class FormatChunk {
  late String chunkID;
  late int chunkSize;
  late int formatTag;
  late int channels;
  late int samplesPerSec;
  late int avgBytesPerSec;
  late int blockAlign;
  late int bitsPerSample;
  late int? cbSize;
  late int? samplesPerBlock;
  List<int>? unknown;

  FormatChunk(this.chunkID, this.chunkSize, this.formatTag, this.channels,
      this.samplesPerSec, this.avgBytesPerSec, this.blockAlign,
      this.bitsPerSample, this.cbSize, this.samplesPerBlock);

  FormatChunk.fromBytes(ByteDataWrapper bytes) {
    chunkID = bytes.readString(4);
    chunkSize = bytes.readUint32();
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
    if (chunkSize > bytes.position - pos) {
      unknown = bytes.readUint8List(chunkSize - (bytes.position - pos));
    }
    if (chunkSize & 1 == 1) {
      bytes.readUint8();
    }
  }
}

typedef Sample = List<int>;
class DataChunk {
  late String chunkID;
  late int chunkSize;
  late List<int> samples;

  DataChunk(this.chunkID, this.chunkSize, this.samples);

  DataChunk.fromBytes(ByteDataWrapper bytes, FormatChunk format) {
    chunkID = bytes.readString(4);
    chunkSize = bytes.readUint32();
    switch (format.bitsPerSample) {
      case 8:
        samples = bytes.asInt8List(chunkSize);
        break;
      case 16:
        samples = bytes.asInt16List(chunkSize ~/ 2);
        break;
      case 32:
        samples = bytes.asInt32List(chunkSize ~/ 4);
        break;
      default:
        samples = bytes.asInt8List(chunkSize);
    }
    if (chunkSize & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }

  List<Sample> asSamples(FormatChunk format)  {
    final bitsPerSample = format.bitsPerSample;
    final channels = format.channels;
    final blockAlign = format.blockAlign;
    if ((bitsPerSample != 8 && bitsPerSample != 16 && bitsPerSample != 32) ||
        (chunkSize % blockAlign != 0)) {
      return samples.map((e) => [e]).toList();
    } else if (channels == 1) {
      return samples.map((e) => [e]).toList();
    } else {
      var subSamples = List.generate(chunkSize ~/ blockAlign, (i) => samples.sublist(i, i + channels));
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

  CuePoint.fromBytes(ByteDataWrapper bytes) {
    identifier = bytes.readUint32();
    position = bytes.readUint32();
    fccChunk = bytes.readString(4);
    chunkStart = bytes.readUint32();
    blockStart = bytes.readUint32();
    sampleOffset = bytes.readUint32();
  }
}

class CueChunk {
  late String chunkID;
  late int chunkSize;
  late int cuePoints;
  late List<CuePoint> points;

  CueChunk(this.chunkID, this.chunkSize, this.cuePoints, this.points);

  CueChunk.fromBytes(ByteDataWrapper bytes) {
    chunkID = bytes.readString(4);
    chunkSize = bytes.readUint32();
    int pos = bytes.position;
    cuePoints = bytes.readUint32();
    points = List.generate(cuePoints, (_) => CuePoint.fromBytes(bytes));
    if (chunkSize > (bytes.position - pos)) {
      bytes.readUint8List(chunkSize - (bytes.position - pos));
    }
  }
}

class RiffListSubChunk {
  late String chunkID;
  late int chunkSize;

  RiffListSubChunk(this.chunkID, this.chunkSize);
}

class RiffListGenericSubChunk extends RiffListSubChunk {
  late List<int> data;

  RiffListGenericSubChunk(super.chunkID, super.chunkSize, this.data);

  RiffListGenericSubChunk.fromBytes(ByteDataWrapper bytes)
    : super(bytes.readString(4), bytes.readUint32()) {
    data = bytes.readUint8List(chunkSize);
    if (chunkSize & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }
}

class RiffListLabelSubChunk extends RiffListSubChunk {
  late int cuePointIndex;
  late String label;

  RiffListLabelSubChunk(super.chunkID, super.chunkSize, this.cuePointIndex,
      this.label);
    
  RiffListLabelSubChunk.fromBytes(ByteDataWrapper bytes)
    : super(bytes.readString(4), bytes.readUint32()) {
    cuePointIndex = bytes.readUint32();
    label = bytes.readString(chunkSize - 4).replaceAll("\x00", "");
    if (chunkSize & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }
}

class RiffListChunk {
  late String chunkID;
  late int chunkSize;
  late String chunkType;
  late List<RiffListSubChunk> subChunks;

  RiffListChunk(this.chunkID, this.chunkSize, this.chunkType, this.subChunks);

  RiffListChunk.fromBytes(ByteDataWrapper bytes) {
    chunkID = bytes.readString(4);
    chunkSize = bytes.readUint32();
    int pos = bytes.position;
    chunkType = bytes.readString(4);
    subChunks = [];
    while (bytes.position - pos < chunkSize) {
      bytes.position += 4;
      int size = bytes.readUint32();
      bytes.position -= 8;
      if (bytes.position - pos + size <= chunkSize) {
        if (chunkType == "adtl")
          subChunks.add(RiffListLabelSubChunk.fromBytes(bytes));
        else
          subChunks.add(RiffListGenericSubChunk.fromBytes(bytes));
      } else {
        bytes.readUint8List(chunkSize - (bytes.position - pos));
      }
    }
    if (chunkSize & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }
}

class RiffUnknownChunk {
  late String chunkID;
  late int chunkSize;
  late List<int> unknownData;

  RiffUnknownChunk(this.chunkID, this.chunkSize, this.unknownData);

  RiffUnknownChunk.fromBytes(ByteDataWrapper bytes) {
    chunkID = bytes.readString(4);
    chunkSize = bytes.readUint32();
    var bytesToRead = min(chunkSize, bytes.length - bytes.position);
    unknownData = bytes.readUint8List(bytesToRead);
    if (chunkSize & 1 == 1 && bytes.position < bytes.length) {
      bytes.readUint8();
    }
  }
}

class RiffFile {
  late RiffHeader header;
  late FormatChunk formatChunk;
  late DataChunk dataChunk;
  CueChunk? cueChunk;
  List<RiffListChunk> listChunks = [];
  List<RiffUnknownChunk> unknownChunks = [];

  RiffFile(this.header, this.formatChunk, this.dataChunk,
      this.cueChunk, this.listChunks);

  RiffFile.fromBytes(ByteDataWrapper bytes) {
    header = RiffHeader.fromBytes(bytes);
    while (bytes.position < bytes.length) {
      String chunkID = bytes.readString(4);
      bytes.position -= 4;
      switch (chunkID) {
        case "fmt ":
          formatChunk = FormatChunk.fromBytes(bytes);
          break;
        case "data":
          dataChunk = DataChunk.fromBytes(bytes, formatChunk);
          break;
        case "cue ":
          cueChunk = CueChunk.fromBytes(bytes);
          break;
        case "LIST":
          listChunks.add(RiffListChunk.fromBytes(bytes));
          break;
        default:
          unknownChunks.add(RiffUnknownChunk.fromBytes(bytes));
          break;
      }
    }
  }

  static Future<RiffFile> fromFile(String wavPath) async {
    var bytes = await File(wavPath).readAsBytes();
    return RiffFile.fromBytes(ByteDataWrapper(bytes.buffer));
  }

  // static Future<void> _fromFileInIsolate(Tuple2<String, SendPort> args) async {
  //   print("Starting isolate");
  //   var res = await fromFile(args.item1);
  //   print("Sending result");
  //   args.item2.send(res);
  //   print("Isolate done");
  // }

  static Future<RiffFile> fromFileInIsolate(String wavPath) async {
    // var receivePort = ReceivePort();
    // await Isolate.spawn(_fromFileInIsolate, Tuple2(wavPath, receivePort.sendPort));
    // return await receivePort.first;
    var bytes = await File(wavPath).readAsBytes();
    return compute(RiffFile.fromBytes, ByteDataWrapper(bytes.buffer));
  }
}
