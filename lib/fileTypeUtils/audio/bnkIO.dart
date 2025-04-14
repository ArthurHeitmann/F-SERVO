
// ignore_for_file: constant_identifier_names

import 'dart:typed_data';

import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';
import 'wemIdsToNames.dart';

abstract class ChunkWithSize {
  int calculateSize();
}
abstract class ChunkBase extends ChunkWithSize {
  void write(ByteDataWrapper bytes);
}
abstract class BnkChunkBase extends ChunkBase {
  String chunkId;
  int chunkSize;

  BnkChunkBase(this.chunkId, this.chunkSize);

  BnkChunkBase.read(ByteDataWrapper bytes) :
    chunkId = bytes.readString(4),
    chunkSize = bytes.readUint32();

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeString(chunkId);
    bytes.writeUint32(chunkSize);
  }

  void updateChunkSize() {
    chunkSize = calculateSize() - 8;
  }
}

const _supportedVersion = 72;
class BnkFile extends ChunkWithSize {
  List<BnkChunkBase> chunks = [];

  BnkFile(this.chunks);

  BnkFile.read(ByteDataWrapper bytes) {
    int unknownChunkCount = 0;
    while (bytes.position < bytes.length) {
      var chunk = _makeNextChunk(bytes);
      if (chunk is BnkHeader) {
        if (chunk.version != _supportedVersion) {
          showToast("Warning: BNK version ${chunk.version} is not supported. Expected $_supportedVersion");
          throw Exception("Unsupported BNK version ${chunk.version}");
        }
      }
      else if (chunk is BnkUnknownChunk) {
        unknownChunkCount++;
        if (unknownChunkCount > 10) {
          showToast("Warning: More than 10 unknown chunks found. Stopping parsing.");
          throw Exception("Too many unknown chunks");
        }
      }
      chunks.add(chunk);
    }
  }

  void write(ByteDataWrapper bytes) {
    for (var chunk in chunks) {
      chunk.write(bytes);
    }
  }

  BnkChunkBase _makeNextChunk(ByteDataWrapper bytes) {
    var type = bytes.readString(4);
    bytes.position -= 4;
    switch (type) {
      case "BKHD": return BnkHeader.read(bytes);
      case "DIDX": return BnkDidxChunk.read(bytes);
      case "DATA":
        if (!chunks.any((element) => element is BnkDidxChunk))
          return BnkUnknownChunk.read(bytes);
        var didxChunk = chunks.whereType<BnkDidxChunk>().first;
        return BnkDataChunk.read(bytes, didxChunk);
      case "HIRC": return BnkHircChunk.read(bytes);
      default: return BnkUnknownChunk.read(bytes);
    }
  }

  @override
  int calculateSize() {
    return chunks.fold(0, (prev, chunk) => prev + chunk.calculateSize());
  }
}

class BnkUnknownChunk extends BnkChunkBase {
  late List<int> data;

  BnkUnknownChunk(super.chunkId, super.chunkSize, this.data);

  BnkUnknownChunk.read(ByteDataWrapper bytes) :
    super.read(bytes) {
    data = bytes.readUint8List(chunkSize);
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    for (var i = 0; i < data.length; i++)
      bytes.writeUint8(data[i]);
  }

  @override
  int calculateSize() {
    return chunkSize + 8;
  }
}

class BnkHeader extends BnkChunkBase {
  late int version;
  late int bnkId;
  late int languageId;
  late int isFeedbackInBnk;
  // late int projectId;
  late List<int> padding;
  List<int>? unknown;

  BnkHeader(super.chunkId, super.chunkSize, this.version, this.bnkId, this.languageId, this.isFeedbackInBnk, this.padding, [this.unknown]);

  BnkHeader.read(ByteDataWrapper bytes) : super.read(bytes) {
    if (chunkSize > 32) {
      bytes.endian = Endian.big;
      bytes.position -= 4;
      chunkSize = bytes.readUint32();
    }
    if (chunkSize < 16) {
      print("Warning: BnkHeader chunk size is less than 20 ($chunkSize)");
      unknown = bytes.readUint8List(chunkSize);
      return;
    }
    version = bytes.readUint32();
    bnkId = bytes.readUint32();
    languageId = bytes.readUint32();
    isFeedbackInBnk = bytes.readUint32();
    // projectId = bytes.readUint32();
    padding = bytes.readUint8List(chunkSize - 0x10);
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    if (unknown != null) {
      for (var i = 0; i < unknown!.length; i++)
        bytes.writeUint8(unknown![i]);
      return;
    }
    bytes.writeUint32(version);
    bytes.writeUint32(bnkId);
    bytes.writeUint32(languageId);
    bytes.writeUint32(isFeedbackInBnk);
    // bytes.writeUint32(projectId);
    for (var i = 0; i < padding.length; i++)
      bytes.writeUint8(padding[i]);
  }

  @override
  int calculateSize() {
    return 8 + (unknown?.length ?? 4*4 + padding.length);
  }
}

class BnkDidxChunk extends BnkChunkBase {
  late List<BnkWemFileInfo> files;

  BnkDidxChunk(super.chunkId, super.chunkSize, this.files);

  BnkDidxChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    int childrenCount = chunkSize ~/ 12;
    files = List.generate(childrenCount, (index) => BnkWemFileInfo.read(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    for (var file in files) {
      file.write(bytes);
    }
  }

  @override
  int calculateSize() {
    return 8 + files.length * 12;
  }
}

class BnkWemFileInfo {
  late int id;
  late int offset;
  late int size;

  BnkWemFileInfo(this.id, this.offset, this.size);

  BnkWemFileInfo.read(ByteDataWrapper bytes) {
    id = bytes.readUint32();
    offset = bytes.readUint32();
    size = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(id);
    bytes.writeUint32(offset);
    bytes.writeUint32(size);
  }
}

class BnkDataChunk extends BnkChunkBase {
  List<Uint8List> wemFiles = [];

  BnkDataChunk(super.chunkId, super.chunkSize, this.wemFiles);

  BnkDataChunk.read(ByteDataWrapper bytes, BnkDidxChunk didx) : super.read(bytes) {
    int initialPosition = bytes.position;
    for (var file in didx.files) {
      bytes.position = initialPosition + file.offset;
      wemFiles.add(bytes.asUint8List(file.size));
    }
    int remaining = chunkSize - (bytes.position - initialPosition);
    if (remaining > 0) {
      bytes.position += remaining;
    }
  }

  void updateOffsets(BnkDidxChunk didx) {
    int offset = 0;
    for (var file in didx.files) {
      file.offset = offset;
      offset += file.size;
      offset = _alignOffset(offset);
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    int offset = 0;
    int initialPosition = bytes.position;
    for (var file in wemFiles) {
      bytes.position = initialPosition + offset;
      for (var i = 0; i < file.length; i++)
        bytes.writeUint8(file[i]);
      offset += file.length;
      offset = _alignOffset(offset);
    }
  }

  @override
  int calculateSize() {
    int size = 0;
    for (var file in wemFiles) {
      size = (size + 15) & ~15;
      size += file.length;
    }
    return 8 + size;
  }

  int _alignOffset(int offset) {
    return (offset + 15) & ~15;
  }
}

class BnkHircChunk extends BnkChunkBase {
  late List<BnkHircChunkBase> chunks;

  BnkHircChunk(super.chunkId, super.chunkSize, this.chunks);

  BnkHircChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    int childrenCount = bytes.readUint32();
    chunks = List.generate(childrenCount, (index) {
      return _makeNextHircChunk(bytes);
    });
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint32(chunks.length);
    for (var chunk in chunks) {
      chunk.write(bytes);
    }
  }

  @override
  int calculateSize() {
    return (
      8 + // chunk header
      4 + // children count
      chunks.fold(0, (prev, chunk) => prev + chunk.calculateSize() + 9)
    );
  }
}

enum BnkHircType {
  state(0x01),
  sound(0x02),
  action(0x03),
  event(0x04),
  randomSequence(0x05),
  soundSwitch(0x06),
  actorMixer(0x07),
  layerContainer(0x09),
  musicSegment(0x0A),
  musicTrack(0x0B),
  musicSwitch(0x0C),
  musicPlaylist(0x0D),
  attenuation(0x0E),
  fxCustom(0x12),
  fxShareSet(0x13),
  unknown(-1);

  final int value;

  const BnkHircType(this.value);
  static from(int value) => BnkHircType.values.firstWhere((e) => e.value == value, orElse: () => BnkHircType.unknown);
}

abstract class BnkHircChunkBase extends ChunkBase {
  int type;
  int size;
  int uid;

  BnkHircChunkBase(this.type, this.size, this.uid);

  BnkHircChunkBase.read(ByteDataWrapper bytes) :
    type = bytes.readUint8(),
    size = bytes.readUint32(),
    uid = bytes.readUint32();

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(type);
    bytes.writeUint32(size);
    bytes.writeUint32(uid);
  }
}

BnkHircChunkBase _makeNextHircChunk(ByteDataWrapper bytes) {
  var type = bytes.readUint8();
  bytes.position -= 1;
  switch (BnkHircType.from(type)) {
    case BnkHircType.state:
      return BnkState.read(bytes);
    case BnkHircType.sound:
      return BnkSound.read(bytes);
    case BnkHircType.event:
      return BnkEvent.read(bytes);
    case BnkHircType.randomSequence:
      return BnkRandomSequence.read(bytes);
    case BnkHircType.soundSwitch:
      return BnkSoundSwitch.read(bytes);
    case BnkHircType.actorMixer:
      return BnkActorMixer.read(bytes);
    case BnkHircType.action:
      return BnkAction.read(bytes);
    case BnkHircType.layerContainer:
      return BnkLayerContainer.read(bytes);
    case BnkHircType.musicSegment:
      return BnkMusicSegment.read(bytes);
    case BnkHircType.musicTrack:
      return BnkMusicTrack.read(bytes);
    case BnkHircType.musicSwitch:
      return BnkMusicSwitch.read(bytes);
    case BnkHircType.musicPlaylist:
      return BnkMusicPlaylist.read(bytes);
    case BnkHircType.attenuation:
      return BnkAttenuation.read(bytes);
    case BnkHircType.fxCustom:
    case BnkHircType.fxShareSet:
      return BnkFxCustom.read(bytes);
    default:
      return BnkHircUnknownChunk.read(bytes);
  }
}

class BnkHircUnknownChunk extends BnkHircChunkBase {
  late List<int> data;

  BnkHircUnknownChunk(super.type, super.size, super.uid, this.data);

  BnkHircUnknownChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    data = bytes.readUint8List(size - 4);
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    for (var i = 0; i < data.length; i++)
      bytes.writeUint8(data[i]);
  }

  @override
  int calculateSize() => data.length;
}

mixin BnkHircChunkWithBaseParamsGetter on BnkHircChunkBase {
  BnkNodeBaseParams getBaseParams();
}

mixin BnkHircChunkWithBaseParams implements BnkHircChunkWithBaseParamsGetter {
  late BnkNodeBaseParams baseParams;

  @override
  BnkNodeBaseParams getBaseParams() => baseParams;
}

mixin BnkHircChunkWithTransNodeParams {
  abstract BnkMusicTransNodeParams musicTransParams;
}

class BnkMusicTrack extends BnkHircChunkBase with BnkHircChunkWithBaseParams {
  // late int uFlags;
  late int numSources;
  late List<BnkSource> sources;
  late int numPlaylistItem;
  late List<BnkPlaylist> playlists;
  int? numSubTrack;
  late int numClipAutomationItem;
  late List<BnkClipAutomation> clipAutomations;
  late int eRSType;
  late int iLookAheadTime;

  BnkMusicTrack(super.type, super.size, super.uid, this.numSources, this.sources, this.numPlaylistItem, this.playlists, this.numSubTrack, this.numClipAutomationItem, this.clipAutomations, BnkNodeBaseParams baseParams, this.eRSType, this.iLookAheadTime) {
    this.baseParams = baseParams;
  }

  BnkMusicTrack.read(ByteDataWrapper bytes) : super.read(bytes) {
    // uFlags = bytes.readUint8();
    numSources = bytes.readUint32();
    sources = List.generate(numSources, (index) => BnkSource.read(bytes));
    numPlaylistItem = bytes.readUint32();
    playlists = List.generate(numPlaylistItem, (index) => BnkPlaylist.read(bytes));
    if (numPlaylistItem > 0)
      numSubTrack = bytes.readUint32();
    numClipAutomationItem = bytes.readUint32();
    clipAutomations = List.generate(numClipAutomationItem, (index) => BnkClipAutomation.read(bytes));
    baseParams = BnkNodeBaseParams.read(bytes);
    eRSType = bytes.readUint32();
    iLookAheadTime = bytes.readUint32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    // bytes.writeUint8(uFlags);
    bytes.writeUint32(numSources);
    for (var i = 0; i < numSources; i++)
      sources[i].write(bytes);
    bytes.writeUint32(numPlaylistItem);
    for (var i = 0; i < numPlaylistItem; i++)
      playlists[i].write(bytes);
    if (numPlaylistItem > 0)
      bytes.writeUint32(numSubTrack!);
    bytes.writeUint32(numClipAutomationItem);
    for (var i = 0; i < numClipAutomationItem; i++)
      clipAutomations[i].write(bytes);
    baseParams.write(bytes);
    bytes.writeUint32(eRSType);
    bytes.writeUint32(iLookAheadTime);
  }

  @override
  int calculateSize() {
    return (
      // 1 + // uFlags
      4 + // numSources
      sources.fold<int>(0, (sum, s) => sum + s.calcChunkSize()) +  // sources
      4 + // numPlaylistItem
      playlists.fold<int>(0, (sum, p) => sum + p.calcChunkSize()) +  // playlists
      (numPlaylistItem > 0 ? 4 : 0) + // numSubTrack
      4 + // numClipAutomationItem
      clipAutomations.fold<int>(0, (sum, c) => sum + c.calcChunkSize()) +  // clipAutomations
      baseParams.calcChunkSize() +  // baseParams
      4 + // eTrackType
      // (eRSType == 3 ? switchParam!.calcChunkSize() + transParam!.calcChunkSize() : 0) +  // switchParam, transParam
      4 // iLookAheadTime
    );
  }
}

class BnkLayerContainer extends BnkHircChunkBase with BnkHircChunkWithBaseParams {
  late BnkChildren childrenList;
  late int numLayers;
  late List<BnkLayer> layers;

  BnkLayerContainer(super.type, super.size, super.uid, this.childrenList, this.numLayers, this.layers, BnkNodeBaseParams baseParams) {
    this.baseParams = baseParams;
  }

  BnkLayerContainer.read(ByteDataWrapper bytes) : super.read(bytes) {
    baseParams = BnkNodeBaseParams.read(bytes);
    childrenList = BnkChildren.read(bytes);
    numLayers = bytes.readUint32();
    layers = List.generate(numLayers, (index) => BnkLayer.read(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    baseParams.write(bytes);
    childrenList.write(bytes);
    bytes.writeUint32(numLayers);
    for (var i = 0; i < numLayers; i++)
      layers[i].write(bytes);
  }

  @override
  int calculateSize() {
    return (
      baseParams.calcChunkSize() +  // baseParams
      childrenList.calcChunkSize() +  // childrenList
      4 + // numLayers
      layers.fold<int>(0, (sum, l) => sum + l.calcChunkSize())  // layers
    );
  }
}
class BnkLayer {
  late int layerId;
  late BnkInitialRTPC initialRtpc;
  late int rtpcId;
  late int rtpcType;
  late int numAssoc;
  late List<BnkAssociatedChildData> childData;

  BnkLayer(this.layerId, this.initialRtpc, this.rtpcId, this.rtpcType, this.numAssoc, this.childData);

  BnkLayer.read(ByteDataWrapper bytes) {
    layerId = bytes.readUint32();
    initialRtpc = BnkInitialRTPC.read(bytes);
    rtpcId = bytes.readUint32();
    rtpcType = bytes.readUint8();
    numAssoc = bytes.readUint32();
    childData = List.generate(numAssoc, (index) => BnkAssociatedChildData.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(layerId);
    initialRtpc.write(bytes);
    bytes.writeUint32(rtpcId);
    bytes.writeUint8(rtpcType);
    bytes.writeUint32(numAssoc);
    for (var i = 0; i < numAssoc; i++)
      childData[i].write(bytes);
  }

  int calcChunkSize() {
    return (
      4 + // layerId
      initialRtpc.calcChunkSize() + // initialRtpc
      4 + // rtpcId
      1 + // rtpcType
      4 + // numAssoc
      childData.fold<int>(0, (sum, c) => sum + c.calcChunkSize()) // childData
    );
  }
}
class BnkAssociatedChildData {
  late int associatedChildId;
  late int curveSize;
  late List<BnkRtpcGraphPoint> graphPoints;

  BnkAssociatedChildData(this.associatedChildId, this.curveSize, this.graphPoints);

  BnkAssociatedChildData.read(ByteDataWrapper bytes) {
    associatedChildId = bytes.readUint32();
    curveSize = bytes.readUint32();
    graphPoints = List.generate(curveSize, (index) => BnkRtpcGraphPoint.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(associatedChildId);
    bytes.writeUint32(curveSize);
    for (var i = 0; i < curveSize; i++)
      graphPoints[i].write(bytes);
  }

  int calcChunkSize() {
    return (
      4 + // associatedChildId
      4 + // curveSize
      graphPoints.fold<int>(0, (sum, g) => sum + g.calcChunkSize()) // graphPoints
    );
  }
}

class BnkMusicSegment extends BnkHircChunkBase with BnkHircChunkWithBaseParamsGetter {
  late BnkMusicNodeParams musicParams;
  late double fDuration;
  late int ulNumMarkers;
  late List<BnkMusicMarker> wwiseMarkers;

  BnkMusicSegment(super.type, super.size, super.uid, this.musicParams, this.fDuration, this.ulNumMarkers, this.wwiseMarkers);

  BnkMusicSegment.read(ByteDataWrapper bytes) : super.read(bytes) {
    musicParams = BnkMusicNodeParams.read(bytes);
    fDuration = bytes.readFloat64();
    ulNumMarkers = bytes.readUint32();
    wwiseMarkers = List.generate(ulNumMarkers, (index) => BnkMusicMarker.read(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    musicParams.write(bytes);
    bytes.writeFloat64(fDuration);
    bytes.writeUint32(ulNumMarkers);
    for (var i = 0; i < ulNumMarkers; i++)
      wwiseMarkers[i].write(bytes);
  }

  @override
  int calculateSize() {
    return (
      musicParams.calcChunkSize() +  // musicParams
      8 + // fDuration
      4 + // ulNumMarkers
      wwiseMarkers.fold<int>(0, (sum, m) => sum + m.calcChunkSize())  // wwiseMarkers
    );
  }

  @override
  BnkNodeBaseParams getBaseParams() {
    return musicParams.baseParams;
  }
}

class BnkMusicSwitch extends BnkHircChunkBase with BnkHircChunkWithBaseParamsGetter, BnkHircChunkWithTransNodeParams {
  @override
  late BnkMusicTransNodeParams musicTransParams;
  late int eGroupType;
  late int ulGroupID;
  late int ulDefaultSwitch;
  late int bIsContinuousValidation;
  late int numSwitchAssocs;
  late List<BnkAkMusicSwitchAssoc> pAssocs;

  BnkMusicSwitch(super.type, super.size, super.uid, this.musicTransParams, this.eGroupType, this.ulGroupID, this.ulDefaultSwitch, this.bIsContinuousValidation, this.numSwitchAssocs, this.pAssocs);

  BnkMusicSwitch.read(ByteDataWrapper bytes) : super.read(bytes) {
    musicTransParams = BnkMusicTransNodeParams.read(bytes);
    eGroupType = bytes.readUint32();
    ulGroupID = bytes.readUint32();
    ulDefaultSwitch = bytes.readUint32();
    bIsContinuousValidation = bytes.readUint8();
    numSwitchAssocs = bytes.readUint32();
    pAssocs = List.generate(numSwitchAssocs, (index) => BnkAkMusicSwitchAssoc.read(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    musicTransParams.write(bytes);
    bytes.writeUint32(eGroupType);
    bytes.writeUint32(ulGroupID);
    bytes.writeUint32(ulDefaultSwitch);
    bytes.writeUint8(bIsContinuousValidation);
    bytes.writeUint32(numSwitchAssocs);
    for (var i = 0; i < numSwitchAssocs; i++)
      pAssocs[i].write(bytes);
  }

  @override
  int calculateSize() {
    return (
      musicTransParams.calcChunkSize() +  // musicTransParams
      4 + // eGroupType
      4 + // ulGroupID
      4 + // ulDefaultSwitch
      1 + // bIsContinuousValidation
      4 + // numSwitchAssocs
      pAssocs.fold<int>(0, (sum, a) => sum + a.calcChunkSize())  // pAssocs
    );
  }

  @override
  BnkNodeBaseParams getBaseParams() {
    return musicTransParams.musicParams.baseParams;
  }
}


class BnkMusicPlaylist extends BnkHircChunkBase with BnkHircChunkWithBaseParamsGetter, BnkHircChunkWithTransNodeParams {
  @override
  late BnkMusicTransNodeParams musicTransParams;
  late int numPlaylistItems;
  late List<BnkPlaylistItem> playlistItems;

  BnkMusicPlaylist(super.type, super.size, super.uid, this.musicTransParams, this.numPlaylistItems, this.playlistItems);

  BnkMusicPlaylist.read(ByteDataWrapper bytes) : super.read(bytes) {
    musicTransParams = BnkMusicTransNodeParams.read(bytes);
    numPlaylistItems = bytes.readUint32();
    playlistItems = List.generate(numPlaylistItems, (index) => BnkPlaylistItem.read(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    musicTransParams.write(bytes);
    bytes.writeUint32(numPlaylistItems);
    for (var i = 0; i < numPlaylistItems; i++)
      playlistItems[i].write(bytes);
  }

  @override
  int calculateSize() {
    return (
      musicTransParams.calcChunkSize() +  // musicTransParams
      4 + // numPlaylistItems
      playlistItems.fold<int>(0, (sum, p) => sum + p.calcChunkSize())  // playlistItems
    );
  }

  @override
  BnkNodeBaseParams getBaseParams() {
    return musicTransParams.musicParams.baseParams;
  }
}

class BnkAkMusicSwitchAssoc {
  late int switchID;
  late int nodeID;

  BnkAkMusicSwitchAssoc(this.switchID, this.nodeID);

  BnkAkMusicSwitchAssoc.read(ByteDataWrapper bytes) {
    switchID = bytes.readUint32();
    nodeID = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(switchID);
    bytes.writeUint32(nodeID);
  }

  int calcChunkSize() {
    return 4 + 4;
  }
}

class BnkPlaylistItem {
  late int segmentId;
  late int playlistItemId;
  late int numChildren;
  late int eRSType;
  late int loop;
  // late int loopMin;
  // late int loopMax;
  late int weight;
  late int wAvoidRepeatCount;
  late int bIsUsingWeight;
  late int bIsShuffle;

  BnkPlaylistItem(this.segmentId, this.playlistItemId, this.numChildren, this.eRSType, this.loop, this.weight, this.wAvoidRepeatCount, this.bIsUsingWeight, this.bIsShuffle);

  BnkPlaylistItem.read(ByteDataWrapper bytes) {
    segmentId = bytes.readUint32();
    playlistItemId = bytes.readUint32();
    numChildren = bytes.readUint32();
    eRSType = bytes.readInt32();
    loop = bytes.readInt16();
    // loopMin = bytes.readInt16();
    // loopMax = bytes.readInt16();
    weight = bytes.readUint32();
    wAvoidRepeatCount = bytes.readUint16();
    bIsUsingWeight = bytes.readUint8();
    bIsShuffle = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(segmentId);
    bytes.writeUint32(playlistItemId);
    bytes.writeUint32(numChildren);
    bytes.writeInt32(eRSType);
    bytes.writeInt16(loop);
    // bytes.writeInt16(loopMin);
    // bytes.writeInt16(loopMax);
    bytes.writeUint32(weight);
    bytes.writeUint16(wAvoidRepeatCount);
    bytes.writeUint8(bIsUsingWeight);
    bytes.writeUint8(bIsShuffle);
  }

  int calcChunkSize() {
    return (
      4 + // segmentId
      4 + // playlistItemId
      4 + // numChildren
      4 + // eRSType
      2 + // loop
      // 2 + // loopMin
      // 2 + // loopMax
      4 + // weight
      2 + // wAvoidRepeatCount
      1 + // bIsUsingWeight
      1   // bIsShuffle
    );
  }
}

class BnkMusicTransNodeParams {
  late BnkMusicNodeParams musicParams;
  late int numRules;
  late List<BnkMusicTransitionRule> rules;

  BnkMusicTransNodeParams(this.musicParams, this.numRules, this.rules);

  BnkMusicTransNodeParams.read(ByteDataWrapper bytes) {
    musicParams = BnkMusicNodeParams.read(bytes);
    numRules = bytes.readUint32();
    rules = List.generate(numRules, (index) => BnkMusicTransitionRule.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    musicParams.write(bytes);
    bytes.writeUint32(numRules);
    for (var i = 0; i < numRules; i++)
      rules[i].write(bytes);
  }

  int calcChunkSize() {
    return (
      musicParams.calcChunkSize() +  // musicParams
      4 + // numRules
      rules.fold<int>(0, (sum, r) => sum + r.calcChunkSize())  // rules
    );
  }
}

class BnkMusicTransitionRule {
  late int srcID;
  late int dstID;
  late BnkMusicTransSrcRule srcRule;
  late BnkMusicTransDstRule dstRule;
  late int bIsTransObjectEnabled;
  late BnkMusicTransitionObject musicTransition;

  BnkMusicTransitionRule(this.srcID, this.dstID, this.srcRule, this.dstRule, this.bIsTransObjectEnabled, this.musicTransition);

  BnkMusicTransitionRule.read(ByteDataWrapper bytes) {
    srcID = bytes.readInt32();
    dstID = bytes.readInt32();
    srcRule = BnkMusicTransSrcRule.read(bytes);
    dstRule = BnkMusicTransDstRule.read(bytes);
    bIsTransObjectEnabled = bytes.readUint8();
    musicTransition = BnkMusicTransitionObject.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeInt32(srcID);
    bytes.writeInt32(dstID);
    srcRule.write(bytes);
    dstRule.write(bytes);
    bytes.writeUint8(bIsTransObjectEnabled);
    musicTransition.write(bytes);
  }

  int calcChunkSize() {
    return (
      4 + // srcID
      4 + // dstID
      srcRule.calcChunkSize() + // srcRule
      dstRule.calcChunkSize() + // dstRule
      1 + // allocTransObjectFlag
      musicTransition.calcChunkSize() // musicTransition
    );
  }
}

class BnkMusicTransSrcRule {
  late BnkFadeParams fadeParam;
  late int eSyncType;
  late int uMarkerID;
  late int bPlayPostExit;

  BnkMusicTransSrcRule(this.fadeParam, this.eSyncType, this.uMarkerID, this.bPlayPostExit);

  BnkMusicTransSrcRule.read(ByteDataWrapper bytes) {
    fadeParam = BnkFadeParams.read(bytes);
    eSyncType = bytes.readUint32();
    uMarkerID = bytes.readUint32();
    bPlayPostExit = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    fadeParam.write(bytes);
    bytes.writeUint32(eSyncType);
    bytes.writeUint32(uMarkerID);
    bytes.writeUint8(bPlayPostExit);
  }

  int calcChunkSize() {
    return (
      fadeParam.calcChunkSize() + // fadeParam
      4 + // eSyncType
      4 + // uMarkerID
      1 // bPlayPostExit
    );
  }
}

class BnkMusicTransDstRule {
  late BnkFadeParams fadeParam;
  late int uMarkerID;
  late int uJumpToID;
  late int eEntryType;
  late int bPlayPreEntry;
  late int bDestMatchSourceCueName;

  BnkMusicTransDstRule(this.fadeParam, this.uMarkerID, this.uJumpToID, this.eEntryType, this.bPlayPreEntry, this.bDestMatchSourceCueName);

  BnkMusicTransDstRule.read(ByteDataWrapper bytes) {
    fadeParam = BnkFadeParams.read(bytes);
    uMarkerID = bytes.readUint32();
    uJumpToID = bytes.readUint32();
    eEntryType = bytes.readUint16();
    bPlayPreEntry = bytes.readUint8();
    bDestMatchSourceCueName = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    fadeParam.write(bytes);
    bytes.writeUint32(uMarkerID);
    bytes.writeUint32(uJumpToID);
    bytes.writeUint16(eEntryType);
    bytes.writeUint8(bPlayPreEntry);
    bytes.writeUint8(bDestMatchSourceCueName);
  }

  int calcChunkSize() {
    return (
      fadeParam.calcChunkSize() + // fadeParam
      4 + // uMarkerID
      4 + // uJumpToID
      2 + // eEntryType
      1 + // bPlayPreEntry
      1 // bDestMatchSourceCueName
    );
  }
}

class BnkMusicTransitionObject {
  late int segmentID;
  late BnkFadeParams fadeInParams;
  late BnkFadeParams fadeOutParams;
  late int playPreEntry;
  late int playPostExit;

  BnkMusicTransitionObject(this.segmentID, this.fadeInParams, this.fadeOutParams, this.playPreEntry, this.playPostExit);

  BnkMusicTransitionObject.read(ByteDataWrapper bytes) {
    segmentID = bytes.readUint32();
    fadeInParams = BnkFadeParams.read(bytes);
    fadeOutParams = BnkFadeParams.read(bytes);
    playPreEntry = bytes.readUint8();
    playPostExit = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(segmentID);
    fadeInParams.write(bytes);
    fadeOutParams.write(bytes);
    bytes.writeUint8(playPreEntry);
    bytes.writeUint8(playPostExit);
  }

  int calcChunkSize() {
    return (
      4 + // segmentID
      fadeInParams.calcChunkSize() + // fadeInParams
      fadeOutParams.calcChunkSize() + // fadeOutParams
      1 + // playPreEntry
      1 // playPostExit
    );
  }
}

class BnkMusicMarker {
  late int id;
  late double fPosition;
  late int uStringSize;
  String? pMarkerName;

  BnkMusicMarker(this.id, this.fPosition, this.uStringSize, this.pMarkerName);

  BnkMusicMarker.read(ByteDataWrapper bytes) {
    id = bytes.readUint32();
    fPosition = bytes.readFloat64();
    uStringSize = bytes.readUint32();
    if (uStringSize > 0)
      pMarkerName = bytes.readString(uStringSize);
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(id);
    bytes.writeFloat64(fPosition);
    bytes.writeUint32(uStringSize);
    if (uStringSize > 0)
      bytes.writeString(pMarkerName!);
  }

  int calcChunkSize() {
    return 4 + 8 + 4 + uStringSize;
  }
}

class BnkMusicNodeParams {
  // late int uFlags;
  late BnkNodeBaseParams baseParams;
  late BnkChildren childrenList;
  late BnkAkMeterInfo meterInfo;
  late int bMeterInfoFlag;
  late int uNumStingers;
  late List<BnkAkStinger> stingers;

  BnkMusicNodeParams(this.baseParams, this.childrenList, this.meterInfo, this.bMeterInfoFlag, this.uNumStingers, this.stingers);

  BnkMusicNodeParams.read(ByteDataWrapper bytes) {
    // uFlags = bytes.readUint8();
    baseParams = BnkNodeBaseParams.read(bytes);
    childrenList = BnkChildren.read(bytes);
    meterInfo = BnkAkMeterInfo.read(bytes);
    bMeterInfoFlag = bytes.readUint8();
    uNumStingers = bytes.readUint32();
    stingers = List.generate(uNumStingers, (index) => BnkAkStinger.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    // bytes.writeUint8(uFlags);
    baseParams.write(bytes);
    childrenList.write(bytes);
    meterInfo.write(bytes);
    bytes.writeUint8(bMeterInfoFlag);
    bytes.writeUint32(uNumStingers);
    for (var i = 0; i < uNumStingers; i++)
      stingers[i].write(bytes);
  }

  int calcChunkSize() {
    return (
      // 1 + // uFlags
      baseParams.calcChunkSize() +
      childrenList.calcChunkSize() +
      meterInfo.calcChunkSize() +
      1 + // bMeterInfoFlag
      4 + // uNumStingers
      stingers.fold(0, (prev, s) => prev + s.calcChunkSize())
    );
  }
}

class BnkChildren {
  late int uNumChildren;
  late List<int> ulChildIDs;

  BnkChildren(this.uNumChildren, this.ulChildIDs);

  BnkChildren.read(ByteDataWrapper bytes) {
    uNumChildren = bytes.readUint32();
    ulChildIDs = List.generate(uNumChildren, (index) => bytes.readUint32());
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(uNumChildren);
    for (var i = 0; i < uNumChildren; i++)
      bytes.writeUint32(ulChildIDs[i]);
  }

  int calcChunkSize() {
    return 4 + uNumChildren * 4;
  }
}

class BnkAkMeterInfo {
  late double fGridPeriod;
  late double fGridOffset;
  late double fTempo;
  late int uNumBeatsPerBar;
  late int uBeatValue;

  BnkAkMeterInfo(this.fGridPeriod, this.fGridOffset, this.fTempo, this.uNumBeatsPerBar, this.uBeatValue);

  BnkAkMeterInfo.read(ByteDataWrapper bytes) {
    fGridPeriod = bytes.readFloat64();
    fGridOffset = bytes.readFloat64();
    fTempo = bytes.readFloat32();
    uNumBeatsPerBar = bytes.readUint8();
    uBeatValue = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeFloat64(fGridPeriod);
    bytes.writeFloat64(fGridOffset);
    bytes.writeFloat32(fTempo);
    bytes.writeUint8(uNumBeatsPerBar);
    bytes.writeUint8(uBeatValue);
  }

  int calcChunkSize() {
    return 8 + 8 + 4 + 1 + 1;
  }
}

class BnkAkStinger {
  late int triggerID;
  late int segmentID;
  late int syncPlayAt;
  late int uCueFilterHash;
  late int noRepeatTime;
  late int numSegmentLookAhead;

  BnkAkStinger(this.triggerID, this.segmentID, this.syncPlayAt, this.uCueFilterHash, this.noRepeatTime, this.numSegmentLookAhead);

  BnkAkStinger.read(ByteDataWrapper bytes) {
    triggerID = bytes.readUint32();
    segmentID = bytes.readUint32();
    syncPlayAt = bytes.readUint32();
    uCueFilterHash = bytes.readUint32();
    noRepeatTime = bytes.readInt32();
    numSegmentLookAhead = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(triggerID);
    bytes.writeUint32(segmentID);
    bytes.writeUint32(syncPlayAt);
    bytes.writeUint32(uCueFilterHash);
    bytes.writeInt32(noRepeatTime);
    bytes.writeUint32(numSegmentLookAhead);
  }

  int calcChunkSize() {
    return 4 + 4 + 4 + 4 + 4 + 4;
  }
}

class BnkSource {
  late int ulPluginID;
  late int streamType;
  late int sourceID;
  late int fileID;
  int? uFileOffset;
  int? uInMemorySize;
  late int uSourceBits;
  int? gapSize;
  List<int>? gap;

  BnkSource(this.ulPluginID, this.streamType, this.sourceID, this.uFileOffset, this.uInMemorySize, this.uSourceBits, this.gap);

  BnkSource.read(ByteDataWrapper bytes) {
    ulPluginID = bytes.readUint32();
    streamType = bytes.readUint32();
    sourceID = bytes.readUint32();
    fileID = bytes.readUint32();
    if (streamType != 1) {
      uFileOffset = bytes.readUint32();
      uInMemorySize = bytes.readUint32();
    }
    uSourceBits = bytes.readUint8();
    var pluginType = ulPluginID & 0x0F;
    if (pluginType == 2 || pluginType == 5) {
      gapSize = bytes.readUint32();
      gap = bytes.readUint8List(gapSize!);
    }
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulPluginID);
    bytes.writeUint32(streamType);
    bytes.writeUint32(sourceID);
    bytes.writeUint32(fileID);
    if (streamType != 1) {
      bytes.writeUint32(uFileOffset!);
      bytes.writeUint32(uInMemorySize!);
    }
    bytes.writeUint8(uSourceBits);
    var pluginType = ulPluginID & 0x0F;
    if (pluginType == 2 || pluginType == 5) {
      bytes.writeUint32(gapSize!);
      for (var i = 0; i < gapSize!; i++)
        bytes.writeUint8(gap![i]);
    }
  }

  int calcChunkSize() {
    return
      4 + // ulPluginID
      4 + // streamType
      4 + // sourceID
      4 + // fileID
      (streamType != 1 ? 4 + 4 : 0) + // uFileOffset, uInMemorySize
      1 + // uSourceBits
      (gapSize != null && gap != null ? 4 + gapSize! : 0); // gapSize, gap
  }
}

class BnkPlaylist {
  late int trackID;
  late int sourceID;
  late double fPlayAt;
  late double fBeginTrimOffset;
  late double fEndTrimOffset;
  late double fSrcDuration;

  BnkPlaylist(this.trackID, this.sourceID, this.fPlayAt, this.fBeginTrimOffset, this.fEndTrimOffset, this.fSrcDuration);

  BnkPlaylist.read(ByteDataWrapper bytes) {
    trackID = bytes.readUint32();
    sourceID = bytes.readUint32();
    fPlayAt = bytes.readFloat64();
    fBeginTrimOffset = bytes.readFloat64();
    fEndTrimOffset = bytes.readFloat64();
    fSrcDuration = bytes.readFloat64();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(trackID);
    bytes.writeUint32(sourceID);
    bytes.writeFloat64(fPlayAt);
    bytes.writeFloat64(fBeginTrimOffset);
    bytes.writeFloat64(fEndTrimOffset);
    bytes.writeFloat64(fSrcDuration);
  }

  int calcChunkSize() {
    return 40;
  }
}

class BnkSwitchParams {
  late int eGroupType;
  late int uGroupID;
  late int uDefaultSwitch;
  late int numSwitchAssoc;
  late List<int> ulSwitchAssoc;

  BnkSwitchParams(this.eGroupType, this.uGroupID, this.uDefaultSwitch, this.numSwitchAssoc, this.ulSwitchAssoc);

  BnkSwitchParams.read(ByteDataWrapper bytes) {
    eGroupType = bytes.readUint8();
    uGroupID = bytes.readUint32();
    uDefaultSwitch = bytes.readUint32();
    numSwitchAssoc = bytes.readUint32();
    ulSwitchAssoc = List.generate(numSwitchAssoc, (index) => bytes.readUint32());
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(eGroupType);
    bytes.writeUint32(uGroupID);
    bytes.writeUint32(uDefaultSwitch);
    bytes.writeUint32(numSwitchAssoc);
    for (var i = 0; i < numSwitchAssoc; i++)
      bytes.writeUint32(ulSwitchAssoc[i]);
  }

  int calcChunkSize() {
    return 13 + numSwitchAssoc * 4;
  }
}

class BnkTransParams {
  late BnkFadeParams srcFadeParams;
  late int eSyncType;
  late int uCueHashFilter;
  late BnkFadeParams destFadeParams;

  BnkTransParams(this.srcFadeParams, this.eSyncType, this.uCueHashFilter, this.destFadeParams);

  BnkTransParams.read(ByteDataWrapper bytes) {
    srcFadeParams = BnkFadeParams.read(bytes);
    eSyncType = bytes.readUint32();
    uCueHashFilter = bytes.readUint32();
    destFadeParams = BnkFadeParams.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    srcFadeParams.write(bytes);
    bytes.writeUint32(eSyncType);
    bytes.writeUint32(uCueHashFilter);
    destFadeParams.write(bytes);
  }

  int calcChunkSize() {
    return 12 + 4 + 4 + 12;
  }
}

class BnkFadeParams {
  late int transitionTime;
  late int eFadeCurve;
  late int iFadeOffset;

  BnkFadeParams(this.transitionTime, this.eFadeCurve, this.iFadeOffset);

  BnkFadeParams.read(ByteDataWrapper bytes) {
    transitionTime = bytes.readInt32();
    eFadeCurve = bytes.readUint32();
    iFadeOffset = bytes.readInt32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeInt32(transitionTime);
    bytes.writeUint32(eFadeCurve);
    bytes.writeInt32(iFadeOffset);
  }

  int calcChunkSize() {
    return 4 + 4 + 4;
  }
}

class BnkRtpcGraphPoint {
  late double x;
  late double y;
  late int interpolation;

  BnkRtpcGraphPoint(this.x, this.y, this.interpolation);

  BnkRtpcGraphPoint.read(ByteDataWrapper bytes) {
    x = bytes.readFloat32();
    y = bytes.readFloat32();
    interpolation = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(x);
    bytes.writeFloat32(y);
    bytes.writeUint32(interpolation);
  }

  int calcChunkSize() {
    return 4 + 4 + 4;
  }
}


class BnkClipAutomation {
  late int uClipIndex;
  late int eAutoType;
  late int uNumPoints;
  late List<BnkRtpcGraphPoint> rtpcGraphPoint;

  BnkClipAutomation(this.uClipIndex, this.eAutoType, this.uNumPoints, this.rtpcGraphPoint);

  BnkClipAutomation.read(ByteDataWrapper bytes) {
    uClipIndex = bytes.readUint32();
    eAutoType = bytes.readUint32();
    uNumPoints = bytes.readUint32();
    rtpcGraphPoint = List.generate(uNumPoints, (index) => BnkRtpcGraphPoint.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(uClipIndex);
    bytes.writeUint32(eAutoType);
    bytes.writeUint32(uNumPoints);
    for (var i = 0; i < uNumPoints; i++)
      rtpcGraphPoint[i].write(bytes);
  }

  int calcChunkSize() {
    return 12 + uNumPoints * 12;
  }
}

const BnkPropIds = {
  0x00: "Volume",
  0x01: "LFE",
  0x02: "Pitch",
  0x03: "LPF",
  0x04: "BusVolume",
  0x05: "Priority",
  0x06: "PriorityDistanceOffset",
  0x07: "Loop",
  0x08: "FeedbackVolume",
  0x09: "FeedbackLPF",
  0x0A: "MuteRatio",
  0x0B: "PAN_LR",
  0x0C: "PAN_FR",
  0x0D: "CenterPCT",
  0x0E: "DelayTime",
  0x0F: "TransitionTime",
  0x10: "Probability",
  0x11: "DialogueMode",
  0x12: "UserAuxSendVolume0",
  0x13: "UserAuxSendVolume1",
  0x14: "UserAuxSendVolume2",
  0x15: "UserAuxSendVolume3",
  0x16: "GameAuxSendVolume",
  0x17: "OutputBusVolume",
  0x18: "OutputBusLPF",
  0x19: "InitialDelay",
  0x1A: "HDRBusThreshold",
  0x1B: "HDRBusRatio",
  0x1C: "HDRBusReleaseTime",
  0x1D: "HDRBusGameParam",
  0x1E: "HDRBusGameParamMin",
  0x1F: "HDRBusGameParamMax",
  0x20: "HDRActiveRange",
  0x21: "MakeUpGain",
  0x22: "LoopStart",
  0x23: "LoopEnd",
  0x24: "TrimInTime",
  0x25: "TrimOutTime",
  0x26: "FadeInTime",
  0x27: "FadeOutTime",
  0x28: "FadeInCurve",
  0x29: "FadeOutCurve",
  0x2A: "LoopCrossfadeDuration",
  0x2B: "CrossfadeUpCurve",
  0x2C: "CrossfadeDownCurve",
};

class UnionUint32Float32 {
  late bool isInt;
  int? i;
  double? f;

  UnionUint32Float32(this.isInt, { this.i, this.f });

  UnionUint32Float32.read(ByteDataWrapper bytes) {
    var uint32 = bytes.readUint32();
    if (uint32 > 0x10000000) {
      isInt = false;
      bytes.position -= 4;
      f = bytes.readFloat32();
    } else {
      isInt = true;
      i = uint32;
    }
  }

  void write(ByteDataWrapper bytes) {
    if (isInt)
      bytes.writeUint32(i!);
    else {
      bytes.writeFloat32(f!);
    }
  }

  num get number => isInt ? i! : f!;

  @override
  String toString() {
    if (isInt)
      return wemIdsToNames[i] ?? i.toString();
    else
      return f.toString();
  }
}

class BnkPropValue {
  late int cProps;
  late List<int> pID;
  late List<UnionUint32Float32> values;

  BnkPropValue(this.cProps, this.pID, this.values);

  // void addPropBundle(int id, int value) {
  //   var bytes = ByteData(4);
  //   bytes.setInt32(0, value, Endian.little);
  //   pID.add(id);
  //   pValueBytes.addAll(bytes.buffer.asUint8List());
  //   cProps++;
  // }
  //
  // void addPropBundleF(int id, double value) {
  //   var bytes = ByteData(4);
  //   bytes.setFloat32(0, value, Endian.little);
  //   pID.add(id);
  //   pValueBytes.addAll(bytes.buffer.asUint8List());
  //   cProps++;
  // }

  BnkPropValue.read(ByteDataWrapper bytes) {
    cProps = bytes.readUint8();
    pID = List.generate(cProps, (index) => bytes.readUint8());
    values = List.generate(cProps, (index) => UnionUint32Float32.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(cProps);
    for (var i = 0; i < cProps; i++)
      bytes.writeUint8(pID[i]);
    for (var v in values)
      v.write(bytes);
  }

  int calcChunkSize() {
    return 1 + cProps + cProps * 4;
  }

  Iterable<(int, num)> get props => Iterable.generate(cProps, (i) => (pID[i], values[i].number));
}

class BnkPropRangedValue {
  late int cProps;
  late List<int> pID;
  late List<(UnionUint32Float32, UnionUint32Float32)> minMax;

  BnkPropRangedValue(this.cProps, this.pID, this.minMax);

  BnkPropRangedValue.read(ByteDataWrapper bytes) {
    cProps = bytes.readUint8();
    pID = List.generate(cProps, (index) => bytes.readUint8());
    minMax = List.generate(cProps, (index) => (UnionUint32Float32.read(bytes), UnionUint32Float32.read(bytes)));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(cProps);
    for (var i = 0; i < cProps; i++)
      bytes.writeUint8(pID[i]);
    for (var i = 0; i < cProps; i++) {
      minMax[i].$1.write(bytes);
      minMax[i].$2.write(bytes);
    }
  }

  int calcChunkSize() {
    return 1 + cProps + cProps * 8;
  }
}


class BnkNodeInitialParams {
  late BnkPropValue propValues;
  late BnkPropRangedValue rangedPropValues;

  BnkNodeInitialParams(this.propValues, this.rangedPropValues);

  BnkNodeInitialParams.read(ByteDataWrapper bytes) {
    propValues = BnkPropValue.read(bytes);
    rangedPropValues = BnkPropRangedValue.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    propValues.write(bytes);
    rangedPropValues.write(bytes);
  }

  int calcChunkSize() {
    return propValues.calcChunkSize() + rangedPropValues.calcChunkSize();
  }
}

class BnkFxChunk {
  late int uFXIndex;
  late int fxID;
  late int bIsShareSet;
  late int bIsRendered;

  BnkFxChunk(this.uFXIndex, this.fxID, this.bIsShareSet, this.bIsRendered);

  BnkFxChunk.read(ByteDataWrapper bytes) {
    uFXIndex = bytes.readUint8();
    fxID = bytes.readUint32();
    bIsShareSet = bytes.readUint8();
    bIsRendered = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(uFXIndex);
    bytes.writeUint32(fxID);
    bytes.writeUint8(bIsShareSet);
    bytes.writeUint8(bIsRendered);
  }
}

class BnkNodeInitialFXParams {
  late int bIsOverrideParentFX;
  late int uNumFX;
  int? bitsFXBypass;
  late List<BnkFxChunk> effect;

  BnkNodeInitialFXParams(this.bIsOverrideParentFX, this.uNumFX, this.bitsFXBypass, this.effect);

  BnkNodeInitialFXParams.read(ByteDataWrapper bytes) {
    bIsOverrideParentFX = bytes.readUint8();
    uNumFX = bytes.readUint8();
    if (uNumFX > 0)
      bitsFXBypass = bytes.readUint8();
    effect = List.generate(uNumFX, (index) => BnkFxChunk.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(bIsOverrideParentFX);
    bytes.writeUint8(uNumFX);
    if (uNumFX > 0)
      bytes.writeUint8(bitsFXBypass!);
    for (var i = 0; i < uNumFX; i++)
      effect[i].write(bytes);
  }

  int calcChunkSize() {
    return 2 + (uNumFX > 0 ? 1 : 0) + uNumFX * 7;
  }
}

class BnkPathVertex {
  late double x, y, z;
  late int duration;

  BnkPathVertex(this.x, this.y, this.z, this.duration);

  BnkPathVertex.read(ByteDataWrapper bytes) {
    x = bytes.readFloat32();
    y = bytes.readFloat32();
    z = bytes.readFloat32();
    duration = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(x);
    bytes.writeFloat32(y);
    bytes.writeFloat32(z);
    bytes.writeUint32(duration);
  }
}

class PathListItemOffset {
  late int verticesOffset;
  late int verticesCount;

  PathListItemOffset(this.verticesOffset, this.verticesCount);

  PathListItemOffset.read(ByteDataWrapper bytes) {
    verticesOffset = bytes.readUint32();
    verticesCount = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(verticesOffset);
    bytes.writeUint32(verticesCount);
  }
}

class Bnk3DAutomationParams {
  late double xRange, yRange/*, zRange*/;

  Bnk3DAutomationParams(this.xRange, this.yRange);

  Bnk3DAutomationParams.read(ByteDataWrapper bytes) {
    xRange = bytes.readFloat32();
    yRange = bytes.readFloat32();
    // zRange = bytes.readFloat32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(xRange);
    bytes.writeFloat32(yRange);
    // bytes.writeFloat32(zRange);
  }
}

class BnkPositioningParams {
  late int uByVector;
  int? cbIs3DPositioningAvailable;
  int? bIsPannerEnabled;
  int? eType_;
  int? attenuationID;
  int? bIsSpatialized;
  int? bIsDynamic;
  int? ePathMode;
  int? bIsLooping;
  int? transitionTime;
  int? bFollowOrientation;
  int? ulNumVertices;
  List<BnkPathVertex>? pVertices;
  int? ulNumPlayListItem;
  List<PathListItemOffset>? pPlayListItems;
  List<Bnk3DAutomationParams>? params;

  BnkPositioningParams.read(ByteDataWrapper bytes) {
    uByVector = bytes.readInt8();
    bool hasPositioning = (uByVector & 1) != 0;
    bool has3D = false;
    if (hasPositioning) {
      cbIs3DPositioningAvailable = bytes.readUint8();
      has3D = cbIs3DPositioningAvailable != 0;
      if (!has3D)
        bIsPannerEnabled = bytes.readInt8();
    }
    if (has3D) {
      eType_ = bytes.readUint32();
      attenuationID = bytes.readUint32();
      bIsSpatialized = bytes.readInt8();
      bool hasAutomation = eType_ == 2;
      bool hasDynamic = eType_ == 3;
      if (hasDynamic)
        bIsDynamic = bytes.readUint8();
      if (hasAutomation) {
        ePathMode = bytes.readUint32();
        bIsLooping = bytes.readUint8();
        transitionTime = bytes.readInt32();
        bFollowOrientation = bytes.readUint8();

        ulNumVertices = bytes.readUint32();
        pVertices = List.generate(ulNumVertices!, (_) => BnkPathVertex.read(bytes));
        ulNumPlayListItem = bytes.readUint32();
        pPlayListItems = List.generate(ulNumPlayListItem!, (_) => PathListItemOffset.read(bytes));
        params = List.generate(ulNumPlayListItem!, (_) => Bnk3DAutomationParams.read(bytes));
      }
    }
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeInt8(uByVector);
    if (cbIs3DPositioningAvailable != null)
      bytes.writeUint8(cbIs3DPositioningAvailable!);
    if (bIsPannerEnabled != null)
      bytes.writeInt8(bIsPannerEnabled!);
    if (eType_ != null)
      bytes.writeUint32(eType_!);
    if (attenuationID != null)
      bytes.writeUint32(attenuationID!);
    if (bIsSpatialized != null)
      bytes.writeInt8(bIsSpatialized!);
    if (bIsDynamic != null)
      bytes.writeUint8(bIsDynamic!);
    if (ePathMode != null)
      bytes.writeUint32(ePathMode!);
    if (bIsLooping != null)
      bytes.writeUint8(bIsLooping!);
    if (transitionTime != null)
      bytes.writeInt32(transitionTime!);
    if (bFollowOrientation != null)
      bytes.writeUint8(bFollowOrientation!);
    if (ulNumVertices != null)
      bytes.writeUint32(ulNumVertices!);
    if (pVertices != null)
      for (var i = 0; i < ulNumVertices!; i++)
        pVertices![i].write(bytes);
    if (ulNumPlayListItem != null)
      bytes.writeUint32(ulNumPlayListItem!);
    if (pPlayListItems != null)
      for (var i = 0; i < ulNumPlayListItem!; i++)
        pPlayListItems![i].write(bytes);
    if (params != null)
      for (var i = 0; i < ulNumPlayListItem!; i++)
        params![i].write(bytes);
  }

  int calcChunkSize() {
    return
      1 + // uByVector
      (cbIs3DPositioningAvailable != null ? 1 : 0) + // cbIs3DPositioningAvailable
      (bIsPannerEnabled != null ? 1 : 0) + // bIsPannerEnabled
      (eType_ != null ? 4 : 0) + // eType_
      (attenuationID != null ? 4 : 0) + // attenuationID
      (bIsSpatialized != null ? 1 : 0) + // bIsSpatialized
      (bIsDynamic != null ? 1 : 0) + // bIsDynamic
      (ePathMode != null ? 4 : 0) + // ePathMode
      (bIsLooping != null ? 1 : 0) + // bIsLooping
      (transitionTime != null ? 4 : 0) + // transitionTime
      (bFollowOrientation != null ? 1 : 0) + // bFollowOrientation
      (ulNumVertices != null ? 4 : 0) + // ulNumVertices
      (pVertices != null ? ulNumVertices! * 16 : 0) + // pVertices
      (ulNumPlayListItem != null ? 4 : 0) + // ulNumPlayListItem
      (pPlayListItems != null ? ulNumPlayListItem! * 8 : 0) + // pPlayListItems
      (params != null ? ulNumPlayListItem! * 8 : 0); // params
  }
}

class BnkAuxParams {
  late int bOverrideGameAuxSends;
  late int bUseGameAuxSends;
  late int bOverrideUserAuxSends;
  late int bHasAux;
  int? auxID1;
  int? auxID2;
  int? auxID3;
  int? auxID4;

  BnkAuxParams.read(ByteDataWrapper bytes) {
    bOverrideGameAuxSends = bytes.readUint8();
    bUseGameAuxSends = bytes.readUint8();
    bOverrideUserAuxSends = bytes.readUint8();
    bHasAux = bytes.readUint8();
    if (bHasAux != 0) {
      auxID1 = bytes.readUint32();
      auxID2 = bytes.readUint32();
      auxID3 = bytes.readUint32();
      auxID4 = bytes.readUint32();
    }
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(bOverrideGameAuxSends);
    bytes.writeUint8(bUseGameAuxSends);
    bytes.writeUint8(bOverrideUserAuxSends);
    bytes.writeUint8(bHasAux);
    if (bHasAux != 0) {
      bytes.writeUint32(auxID1!);
      bytes.writeUint32(auxID2!);
      bytes.writeUint32(auxID3!);
      bytes.writeUint32(auxID4!);
    }
  }

  int calcChunkSize() {
    return
      1 + // bOverrideGameAuxSends
      1 + // bUseGameAuxSends
      1 + // bOverrideUserAuxSends
      1 + // bHasAux
      (bHasAux != 0 ? 4 + 4 + 4 + 4 : 0); // auxID1, auxID2, auxID3, auxID4
  }
}

class BnkAdvSettingsParams {
  late int eVirtualQueueBehavior;
  late int bKillNewest;
  late int bUseVirtualBehavior;
  late int u16MaxNumInstance;
  late int bIsGlobalLimit;
  late int eBelowThresholdBehavior;
  late int bIsMaxNumInstOverrideParent;
  late int bIsVVoicesOptOverrideParent;

  BnkAdvSettingsParams.read(ByteDataWrapper bytes) {
    eVirtualQueueBehavior = bytes.readUint8();
    bKillNewest = bytes.readUint8();
    bUseVirtualBehavior = bytes.readUint8();
    u16MaxNumInstance = bytes.readUint16();
    bIsGlobalLimit = bytes.readUint8();
    eBelowThresholdBehavior = bytes.readUint8();
    bIsMaxNumInstOverrideParent = bytes.readUint8();
    bIsVVoicesOptOverrideParent = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(eVirtualQueueBehavior);
    bytes.writeUint8(bKillNewest);
    bytes.writeUint8(bUseVirtualBehavior);
    bytes.writeUint16(u16MaxNumInstance);
    bytes.writeUint8(bIsGlobalLimit);
    bytes.writeUint8(eBelowThresholdBehavior);
    bytes.writeUint8(bIsMaxNumInstOverrideParent);
    bytes.writeUint8(bIsVVoicesOptOverrideParent);
  }

  int calcChunkSize() {
    return 1 + 1 + 1 + 2 + 1 + 1 + 1 + 1;
  }
}

class BnkStateChunk {
  late int ulNumStateGroups;
  late List<BnkStateChunkGroup> stateGroup;

  BnkStateChunk(this.ulNumStateGroups, this.stateGroup);

  BnkStateChunk.read(ByteDataWrapper bytes) {
    ulNumStateGroups = bytes.readUint32();
    stateGroup = List.generate(ulNumStateGroups, (index) => BnkStateChunkGroup.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulNumStateGroups);
    for (var i = 0; i < ulNumStateGroups; i++)
      stateGroup[i].write(bytes);
  }

  int calcChunkSize() {
    return 4 + stateGroup.fold<int>(0, (prev, group) => prev + group.calcChunkSize());
  }
}
class BnkStateChunkGroup {
  late int ulStateGroupID;
  late int eStateSyncType;
  late int ulNumStates;
  late List<BnkStateChunkGroupState> state;

  BnkStateChunkGroup(this.ulStateGroupID, this.eStateSyncType, this.ulNumStates, this.state);

  BnkStateChunkGroup.read(ByteDataWrapper bytes) {
    ulStateGroupID = bytes.readUint32();
    eStateSyncType = bytes.readUint8();
    ulNumStates = bytes.readUint16();
    state = List.generate(ulNumStates, (index) => BnkStateChunkGroupState.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulStateGroupID);
    bytes.writeUint8(eStateSyncType);
    bytes.writeUint16(ulNumStates);
    for (var i = 0; i < ulNumStates; i++)
      state[i].write(bytes);
  }

  int calcChunkSize() {
    return 7 + state.fold<int>(0, (prev, group) => prev + group.calcChunkSize());
  }
}
class BnkStateChunkGroupState {
  late int ulStateID;
  late int ulStateInstanceID;

  BnkStateChunkGroupState(this.ulStateID, this.ulStateInstanceID);

  BnkStateChunkGroupState.read(ByteDataWrapper bytes) {
    ulStateID = bytes.readUint32();
    ulStateInstanceID = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulStateID);
    bytes.writeUint32(ulStateInstanceID);
  }

  int calcChunkSize() {
    return 8;
  }
}

class BnkInitialRTPC {
  late int ulInitialRTPC;
  late List<BnkRtpc> rtpc;

  BnkInitialRTPC(this.ulInitialRTPC, this.rtpc);

  BnkInitialRTPC.read(ByteDataWrapper bytes) {
    ulInitialRTPC = bytes.readUint16();
    rtpc = List.generate(ulInitialRTPC, (index) => BnkRtpc.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint16(ulInitialRTPC);
    for (var i = 0; i < ulInitialRTPC; i++)
      rtpc[i].write(bytes);
  }

  int calcChunkSize() {
    return 2 + rtpc.fold<int>(0, (prev, r) => prev + r.calcChunkSize());
  }
}
class BnkRtpc {
  late int rtpcId;
  // late int rtpcType;
  // late int rtpcAcc;
  late int paramID;
  late int rtpcCurveID;
  late int eScaling;
  late int ulSize;
  late List<BnkRtpcGraphPoint> rtpcGraphPoint;

  BnkRtpc(this.rtpcId, this.paramID, this.rtpcCurveID, this.eScaling, this.ulSize, this.rtpcGraphPoint);

  BnkRtpc.read(ByteDataWrapper bytes) {
    rtpcId = bytes.readUint32();
    // rtpcType = bytes.readUint8();
    // rtpcAcc = bytes.readUint8();
    paramID = bytes.readUint32();
    rtpcCurveID = bytes.readUint32();
    eScaling = bytes.readUint8();
    ulSize = bytes.readUint16();
    rtpcGraphPoint = List.generate(ulSize, (index) => BnkRtpcGraphPoint.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(rtpcId);
    // bytes.writeUint8(rtpcType);
    // bytes.writeUint8(rtpcAcc);
    bytes.writeUint32(paramID);
    bytes.writeUint32(rtpcCurveID);
    bytes.writeUint8(eScaling);
    bytes.writeUint16(ulSize);
    for (var i = 0; i < ulSize; i++)
      rtpcGraphPoint[i].write(bytes);
  }

  int calcChunkSize() {
    return
      4 + // rtpcId
      // 1 + // rtpcType
      // 1 + // rtpcAcc
      4 + // paramID
      4 + // rtpcCurveID
      1 + // eScaling
      2 + // ulSize
      ulSize * 12; // rtpcGraphPoint
  }
}

class BnkNodeBaseParams {
  late BnkNodeInitialFXParams fxParams;
  // late int bOverrideAttachmentParams;
  late int overrideBusID;
  late int directParentID;
  late int bPriorityOverrideParent;
  late int bPriorityApplyDistFactor;
  late BnkNodeInitialParams iniParams;
  late BnkPositioningParams positioning;
  late BnkAuxParams auxParam;
  late BnkAdvSettingsParams advSettings;
  late BnkStateChunk states;
  late BnkInitialRTPC rtpc;

  BnkNodeBaseParams(this.fxParams, this.overrideBusID, this.directParentID, this.bPriorityOverrideParent, this.bPriorityApplyDistFactor, this.iniParams, this.positioning, this.auxParam, this.advSettings, this.states, this.rtpc);

  BnkNodeBaseParams.read(ByteDataWrapper bytes) {
    fxParams = BnkNodeInitialFXParams.read(bytes);
    // bOverrideAttachmentParams = bytes.readUint8();
    overrideBusID = bytes.readUint32();
    directParentID = bytes.readUint32();
    bPriorityOverrideParent = bytes.readUint8();
    bPriorityApplyDistFactor = bytes.readUint8();
    iniParams = BnkNodeInitialParams.read(bytes);
    positioning = BnkPositioningParams.read(bytes);
    auxParam = BnkAuxParams.read(bytes);
    advSettings = BnkAdvSettingsParams.read(bytes);
    states = BnkStateChunk.read(bytes);
    rtpc = BnkInitialRTPC.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    fxParams.write(bytes);
    // bytes.writeUint8(bOverrideAttachmentParams);
    bytes.writeUint32(overrideBusID);
    bytes.writeUint32(directParentID);
    bytes.writeUint8(bPriorityOverrideParent);
    bytes.writeUint8(bPriorityApplyDistFactor);
    iniParams.write(bytes);
    positioning.write(bytes);
    auxParam.write(bytes);
    advSettings.write(bytes);
    states.write(bytes);
    rtpc.write(bytes);
  }

  int calcChunkSize() {
    return (
      fxParams.calcChunkSize() +
      // 1 +
      4 +
      4 +
      1 +
      1 +
      iniParams.calcChunkSize() +
      positioning.calcChunkSize() +
      auxParam.calcChunkSize() +
      advSettings.calcChunkSize() +
      states.calcChunkSize() +
      rtpc.calcChunkSize()
    );
  }
}

class BnkAttenuation extends BnkHircChunkBase {
  late int bIsConeEnabled;
  late BnkConeParams? coneParams;
  late List<int> curveToUse;
  late int numCurves;
  late List<BnkConversionTable> curves;
  late int ulNumRTPC;
  late List<BnkRtpc> rtpcs;

  BnkAttenuation(super.type, super.size, super.uid, this.bIsConeEnabled, this.coneParams, this.curveToUse, this.numCurves, this.curves, this.ulNumRTPC, this.rtpcs);

  BnkAttenuation.read(ByteDataWrapper bytes) : super.read(bytes) {
    bIsConeEnabled = bytes.readUint8();
    if (bIsConeEnabled != 0)
      coneParams = BnkConeParams.read(bytes);
    curveToUse = List.generate(4, (index) => bytes.readInt8());
    numCurves = bytes.readUint8();
    curves = List.generate(numCurves, (index) => BnkConversionTable.read(bytes));
    ulNumRTPC = bytes.readUint16();
    rtpcs = List.generate(ulNumRTPC, (index) => BnkRtpc.read(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint8(bIsConeEnabled);
    if (bIsConeEnabled != 0)
      coneParams!.write(bytes);
    for (var i = 0; i < 4; i++)
      bytes.writeInt8(curveToUse[i]);
    bytes.writeUint8(numCurves);
    for (var i = 0; i < numCurves; i++)
      curves[i].write(bytes);
    bytes.writeUint16(ulNumRTPC);
    for (var i = 0; i < ulNumRTPC; i++)
      rtpcs[i].write(bytes);
  }

  @override
  int calculateSize() {
    return (
      1 +
      (bIsConeEnabled != 0 ? coneParams!.calcChunkSize() : 0) +
      4 +
      1 +
      curves.fold<int>(0, (prev, c) => prev + c.calcChunkSize()) +
      2 +
      rtpcs.fold<int>(0, (prev, r) => prev + r.calcChunkSize())
    ) ;
  }
}

class BnkConeParams {
  late double fInsideDegrees;
  late double fOUtsideDegrees;
  late double fOutsideVolume;
  late double fLoPass;

  BnkConeParams(this.fInsideDegrees, this.fOUtsideDegrees, this.fOutsideVolume, this.fLoPass);

  BnkConeParams.read(ByteDataWrapper bytes) {
    fInsideDegrees = bytes.readFloat32();
    fOUtsideDegrees = bytes.readFloat32();
    fOutsideVolume = bytes.readFloat32();
    fLoPass = bytes.readFloat32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(fInsideDegrees);
    bytes.writeFloat32(fOUtsideDegrees);
    bytes.writeFloat32(fOutsideVolume);
    bytes.writeFloat32(fLoPass);
  }

  int calcChunkSize() {
    return 16;
  }
}

class BnkConversionTable {
  late int eScaling;
  late int ulSize;
  late List<BnkRtpcGraphPoint> rtpcGraphPoint;

  BnkConversionTable(this.eScaling, this.ulSize, this.rtpcGraphPoint);

  BnkConversionTable.read(ByteDataWrapper bytes) {
    eScaling = bytes.readUint8();
    ulSize = bytes.readUint16();
    rtpcGraphPoint = List.generate(ulSize, (index) => BnkRtpcGraphPoint.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(eScaling);
    bytes.writeUint16(ulSize);
    for (var i = 0; i < ulSize; i++)
      rtpcGraphPoint[i].write(bytes);
  }

  int calcChunkSize() {
    return 3 + rtpcGraphPoint.fold<int>(0, (prev, r) => prev + r.calcChunkSize());
  }
}

class BnkFxCustom extends BnkHircChunkBase {
  late int fxId;
  late int uSize;
  late BnkPluginData pluginData;
  late int uNumBankData;
  late List<BnkMediaMap> media;
  late BnkInitialRTPC rtpc;

  BnkFxCustom(super.type, super.size, super.uid, this.fxId, this.uSize, this.pluginData, this.uNumBankData, this.media, this.rtpc);

  BnkFxCustom.read(ByteDataWrapper bytes) : super.read(bytes) {
    fxId = bytes.readUint32();
    uSize = bytes.readUint32();
    pluginData = BnkPluginData.fromId(bytes, fxId, uSize);
    uNumBankData = bytes.readUint8();
    media = List.generate(uNumBankData, (index) => BnkMediaMap.read(bytes));
    rtpc = BnkInitialRTPC.read(bytes);
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint32(fxId);
    bytes.writeUint32(uSize);
    pluginData.write(bytes);
    bytes.writeUint8(uNumBankData);
    for (var i = 0; i < uNumBankData; i++)
      media[i].write(bytes);
    rtpc.write(bytes);
  }

  @override
  int calculateSize() {
    return 8 + pluginData.calcChunkSize() + 1 + media.fold<int>(0, (prev, m) => prev + m.calcChunkSize()) + rtpc.calcChunkSize();
  }

  bool get isShareSet => type == BnkHircType.fxShareSet.index;
}

abstract class BnkPluginData {
  void write(ByteDataWrapper bytes);

  int calcChunkSize();

  static BnkPluginData fromId(ByteDataWrapper bytes, int fxId, int size) {
    switch (fxId) {
      case 0x00640002:
        return BnkFxSineParams.read(bytes, size);
      case 0x00650002:
        return BnkFxSilenceParams.read(bytes, size);
      case 0x00760003:
        return BnkRoomVerbFXParams.read(bytes, size);
      default:
        return BnkPluginDataUnknown.read(bytes, size);
    }
  }
}

class BnkFxSineParams extends BnkPluginData {
  late double fFrequency;
  late double fGain;
  late double fDuration;
  late int uChannelMask;

  BnkFxSineParams(this.fFrequency, this.fGain, this.fDuration, this.uChannelMask);

  BnkFxSineParams.read(ByteDataWrapper bytes, int size) {
    if (size != 16)
      throw Exception('Invalid size $size for BnkFxSrcSilenceParams');
    fFrequency = bytes.readFloat32();
    fGain = bytes.readFloat32();
    fDuration = bytes.readFloat32();
    uChannelMask = bytes.readUint32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(fFrequency);
    bytes.writeFloat32(fGain);
    bytes.writeFloat32(fDuration);
    bytes.writeUint32(uChannelMask);
  }

  @override
  int calcChunkSize() {
    return 16;
  }
}

class BnkFxSilenceParams extends BnkPluginData {
  late double fDuration;
  late double fRandomizedLengthMinus;
  late double fRandomizedLengthPlus;

  BnkFxSilenceParams(this.fDuration, this.fRandomizedLengthMinus, this.fRandomizedLengthPlus);

  BnkFxSilenceParams.read(ByteDataWrapper bytes, int size) {
    if (size != 12)
      throw Exception('Invalid size $size for BnkFxSrcSilenceParams');
    fDuration = bytes.readFloat32();
    fRandomizedLengthMinus = bytes.readFloat32();
    fRandomizedLengthPlus = bytes.readFloat32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(fDuration);
    bytes.writeFloat32(fRandomizedLengthMinus);
    bytes.writeFloat32(fRandomizedLengthPlus);
  }

  @override
  int calcChunkSize() {
    return 12;
  }
}

class BnkRoomVerbFXParams extends BnkPluginData {
  late double fDecayTime;
  late double fHFDamping;
  late double fDiffusion;
  late double fStereoWidth;
  late double fFilter1Gain;
  late double fFilter1Freq;
  late double fFilter1Q;
  late double fFilter2Gain;
  late double fFilter2Freq;
  late double fFilter2Q;
  late double fFilter3Gain;
  late double fFilter3Freq;
  late double fFilter3Q;
  late double fFrontLevel;
  late double fRearLevel;
  late double fCenterLevel;
  late double fLFELevel;
  late double fDryLevel;
  late double fERLevel;
  late double fReverbLevel;
  late int bEnableEarlyReflections;
  late int uERPattern;
  late double fReverbDelay;
  late double fRoomSize;
  late double fERFrontBackDelay;
  late double fDensity;
  late double fRoomShape;
  late int uNumReverbUnits;
  late int bEnableToneControls;
  late int eFilter1Pos;
  late int eFilter1Curve;
  late int eFilter2Pos;
  late int eFilter2Curve;
  late int eFilter3Pos;
  late int eFilter3Curve;
  late double fInputCenterLevel;
  late double fInputLFELevel;
  late double fDensityDelayMin;
  late double fDensityDelayMax;
  late double fDensityDelayRdmPerc;
  late double fRoomShapeMin;
  late double fRoomShapeMax;
  late double fDiffusionDelayScalePerc;
  late double fDiffusionDelayMax;
  late double fDiffusionDelayRdmPerc;
  late double fDCFilterCutFreq;
  late double fReverbUnitInputDelay;
  late double fReverbUnitInputDelayRmdPerc;

  BnkRoomVerbFXParams(
    this.fDecayTime, this.fHFDamping, this.fDiffusion, this.fStereoWidth,
    this.fFilter1Gain, this.fFilter1Freq, this.fFilter1Q,
    this.fFilter2Gain, this.fFilter2Freq, this.fFilter2Q,
    this.fFilter3Gain, this.fFilter3Freq, this.fFilter3Q,
    this.fFrontLevel, this.fRearLevel, this.fCenterLevel, this.fLFELevel,
    this.fDryLevel, this.fERLevel, this.fReverbLevel,
    this.bEnableEarlyReflections, this.uERPattern, this.fReverbDelay,
    this.fRoomSize, this.fERFrontBackDelay, this.fDensity, this.fRoomShape,
    this.uNumReverbUnits, this.bEnableToneControls, this.eFilter1Pos, this.eFilter1Curve,
    this.eFilter2Pos, this.eFilter2Curve, this.eFilter3Pos, this.eFilter3Curve,
    this.fInputCenterLevel, this.fInputLFELevel,
    this.fDensityDelayMin, this.fDensityDelayMax, this.fDensityDelayRdmPerc,
    this.fRoomShapeMin, this.fRoomShapeMax, this.fDiffusionDelayScalePerc,
    this.fDiffusionDelayMax, this.fDiffusionDelayRdmPerc, this.fDCFilterCutFreq,
    this.fReverbUnitInputDelay, this.fReverbUnitInputDelayRmdPerc
  );

  BnkRoomVerbFXParams.read(ByteDataWrapper bytes, int size) {
    if (size != 186)
      throw Exception('Invalid size $size for BnkRoomVerbFXParams');
    fDecayTime = bytes.readFloat32();
    fHFDamping = bytes.readFloat32();
    fDiffusion = bytes.readFloat32();
    fStereoWidth = bytes.readFloat32();
    fFilter1Gain = bytes.readFloat32();
    fFilter1Freq = bytes.readFloat32();
    fFilter1Q = bytes.readFloat32();
    fFilter2Gain = bytes.readFloat32();
    fFilter2Freq = bytes.readFloat32();
    fFilter2Q = bytes.readFloat32();
    fFilter3Gain = bytes.readFloat32();
    fFilter3Freq = bytes.readFloat32();
    fFilter3Q = bytes.readFloat32();
    fFrontLevel = bytes.readFloat32();
    fRearLevel = bytes.readFloat32();
    fCenterLevel = bytes.readFloat32();
    fLFELevel = bytes.readFloat32();
    fDryLevel = bytes.readFloat32();
    fERLevel = bytes.readFloat32();
    fReverbLevel = bytes.readFloat32();
    bEnableEarlyReflections = bytes.readUint8();
    uERPattern = bytes.readUint32();
    fReverbDelay = bytes.readFloat32();
    fRoomSize = bytes.readFloat32();
    fERFrontBackDelay = bytes.readFloat32();
    fDensity = bytes.readFloat32();
    fRoomShape = bytes.readFloat32();
    uNumReverbUnits = bytes.readUint32();
    bEnableToneControls = bytes.readUint8();
    eFilter1Pos = bytes.readUint32();
    eFilter1Curve = bytes.readUint32();
    eFilter2Pos = bytes.readUint32();
    eFilter2Curve = bytes.readUint32();
    eFilter3Pos = bytes.readUint32();
    eFilter3Curve = bytes.readUint32();
    fInputCenterLevel = bytes.readFloat32();
    fInputLFELevel = bytes.readFloat32();
    fDensityDelayMin = bytes.readFloat32();
    fDensityDelayMax = bytes.readFloat32();
    fDensityDelayRdmPerc = bytes.readFloat32();
    fRoomShapeMin = bytes.readFloat32();
    fRoomShapeMax = bytes.readFloat32();
    fDiffusionDelayScalePerc = bytes.readFloat32();
    fDiffusionDelayMax = bytes.readFloat32();
    fDiffusionDelayRdmPerc = bytes.readFloat32();
    fDCFilterCutFreq = bytes.readFloat32();
    fReverbUnitInputDelay = bytes.readFloat32();
    fReverbUnitInputDelayRmdPerc = bytes.readFloat32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(fDecayTime);
    bytes.writeFloat32(fHFDamping);
    bytes.writeFloat32(fDiffusion);
    bytes.writeFloat32(fStereoWidth);
    bytes.writeFloat32(fFilter1Gain);
    bytes.writeFloat32(fFilter1Freq);
    bytes.writeFloat32(fFilter1Q);
    bytes.writeFloat32(fFilter2Gain);
    bytes.writeFloat32(fFilter2Freq);
    bytes.writeFloat32(fFilter2Q);
    bytes.writeFloat32(fFilter3Gain);
    bytes.writeFloat32(fFilter3Freq);
    bytes.writeFloat32(fFilter3Q);
    bytes.writeFloat32(fFrontLevel);
    bytes.writeFloat32(fRearLevel);
    bytes.writeFloat32(fCenterLevel);
    bytes.writeFloat32(fLFELevel);
    bytes.writeFloat32(fDryLevel);
    bytes.writeFloat32(fERLevel);
    bytes.writeFloat32(fReverbLevel);
    bytes.writeUint8(bEnableEarlyReflections);
    bytes.writeUint32(uERPattern);
    bytes.writeFloat32(fReverbDelay);
    bytes.writeFloat32(fRoomSize);
    bytes.writeFloat32(fERFrontBackDelay);
    bytes.writeFloat32(fDensity);
    bytes.writeFloat32(fRoomShape);
    bytes.writeUint32(uNumReverbUnits);
    bytes.writeUint8(bEnableToneControls);
    bytes.writeUint32(eFilter1Pos);
    bytes.writeUint32(eFilter1Curve);
    bytes.writeUint32(eFilter2Pos);
    bytes.writeUint32(eFilter2Curve);
    bytes.writeUint32(eFilter3Pos);
    bytes.writeUint32(eFilter3Curve);
    bytes.writeFloat32(fInputCenterLevel);
    bytes.writeFloat32(fInputLFELevel);
    bytes.writeFloat32(fDensityDelayMin);
    bytes.writeFloat32(fDensityDelayMax);
    bytes.writeFloat32(fDensityDelayRdmPerc);
    bytes.writeFloat32(fRoomShapeMin);
    bytes.writeFloat32(fRoomShapeMax);
    bytes.writeFloat32(fDiffusionDelayScalePerc);
    bytes.writeFloat32(fDiffusionDelayMax);
    bytes.writeFloat32(fDiffusionDelayRdmPerc);
    bytes.writeFloat32(fDCFilterCutFreq);
    bytes.writeFloat32(fReverbUnitInputDelay);
    bytes.writeFloat32(fReverbUnitInputDelayRmdPerc);
  }

  @override
  int calcChunkSize() {
    return 186;
  }
}
class BnkPluginDataUnknown extends BnkPluginData {
  late List<int> data;

  BnkPluginDataUnknown(this.data);

  BnkPluginDataUnknown.read(ByteDataWrapper bytes, int size) {
    data = List.generate(size, (index) => bytes.readUint8());
  }

  @override
  void write(ByteDataWrapper bytes) {
    for (var i = 0; i < data.length; i++)
      bytes.writeUint8(data[i]);
  }

  @override
  int calcChunkSize() {
    return data.length;
  }
}

class BnkMediaMap {
  late int index;
  late int sourceId;

  BnkMediaMap(this.index, this.sourceId);

  BnkMediaMap.read(ByteDataWrapper bytes) {
    index = bytes.readUint8();
    sourceId = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(index);
    bytes.writeUint32(sourceId);
  }

  int calcChunkSize() {
    return 5;
  }
}

class BnkEvent extends BnkHircChunkBase {
  late int ulActionListSize;
  late List<int> ids;

  BnkEvent(super.type, super.size, super.uid, this.ulActionListSize, this.ids);

  BnkEvent.read(ByteDataWrapper bytes) : super.read(bytes) {
    ulActionListSize = bytes.readUint32();
    ids = List.generate(ulActionListSize, (index) => bytes.readUint32());
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint32(ulActionListSize);
    for (var i = 0; i < ulActionListSize; i++)
      bytes.writeUint32(ids[i]);
  }

  @override
  int calculateSize() {
    return 4 + ulActionListSize * 4;
  }
}

class BnkRandomSequence extends BnkHircChunkBase with BnkHircChunkWithBaseParams {
  late int sLoopCount;
  late double fTransitionTime;
  late double fTransitionTimeModMin;
  late double fTransitionTimeModMax;
  late int wAvoidRepeatCount;
  late int eTransitionMode;
  late int eRandomMode;
  late int eMode;
  late int _bIsUsingWeight;
  late int bResetPlayListAtEachPlay;
  late int bIsRestartBackward;
  late int bIsContinuous;
  late int bIsGlobal;
  late BnkChildren childrenList;
  late int ulNumPlaylistItem;
  late List<BnkRandomSequencePlaylistItem> playlistItems;

  BnkRandomSequence(super.type, super.size, super.uid, BnkNodeBaseParams baseParams, this.sLoopCount, this.fTransitionTime, this.fTransitionTimeModMin, this.fTransitionTimeModMax, this.wAvoidRepeatCount, this.eTransitionMode, this.eRandomMode, this.eMode, this._bIsUsingWeight, this.bResetPlayListAtEachPlay, this.bIsRestartBackward, this.bIsContinuous, this.bIsGlobal, this.childrenList, this.ulNumPlaylistItem, this.playlistItems) {
    this.baseParams = baseParams;
  }

  BnkRandomSequence.read(ByteDataWrapper bytes) : super.read(bytes) {
    baseParams = BnkNodeBaseParams.read(bytes);
    sLoopCount = bytes.readUint16();
    fTransitionTime = bytes.readFloat32();
    fTransitionTimeModMin = bytes.readFloat32();
    fTransitionTimeModMax = bytes.readFloat32();
    wAvoidRepeatCount = bytes.readUint16();
    eTransitionMode = bytes.readUint8();
    eRandomMode = bytes.readUint8();
    eMode = bytes.readUint8();
    _bIsUsingWeight = bytes.readUint8();
    bResetPlayListAtEachPlay = bytes.readUint8();
    bIsRestartBackward = bytes.readUint8();
    bIsContinuous = bytes.readUint8();
    bIsGlobal = bytes.readUint8();
    childrenList = BnkChildren.read(bytes);
    ulNumPlaylistItem = bytes.readUint16();
    playlistItems = List.generate(ulNumPlaylistItem, (index) => BnkRandomSequencePlaylistItem.read(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    baseParams.write(bytes);
    bytes.writeUint16(sLoopCount);
    bytes.writeFloat32(fTransitionTime);
    bytes.writeFloat32(fTransitionTimeModMin);
    bytes.writeFloat32(fTransitionTimeModMax);
    bytes.writeUint16(wAvoidRepeatCount);
    bytes.writeUint8(eTransitionMode);
    bytes.writeUint8(eRandomMode);
    bytes.writeUint8(eMode);
    bytes.writeUint8(_bIsUsingWeight);
    bytes.writeUint8(bResetPlayListAtEachPlay);
    bytes.writeUint8(bIsRestartBackward);
    bytes.writeUint8(bIsContinuous);
    bytes.writeUint8(bIsGlobal);
    childrenList.write(bytes);
    bytes.writeUint16(ulNumPlaylistItem);
    for (var i = 0; i < ulNumPlaylistItem; i++)
      playlistItems[i].write(bytes);
  }

  @override
  int calculateSize() {
    return (
      baseParams.calcChunkSize() +
      2 + 4 + 4 + 4 + 2 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 +
      childrenList.calcChunkSize() +
      2 + ulNumPlaylistItem * 8
    );
  }
}
class BnkRandomSequencePlaylistItem {
  late int ulPlayID;
  late int weight;

  BnkRandomSequencePlaylistItem(this.ulPlayID, this.weight);

  BnkRandomSequencePlaylistItem.read(ByteDataWrapper bytes) {
    ulPlayID = bytes.readUint32();
    weight = bytes.readInt32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulPlayID);
    bytes.writeInt32(weight);
  }
}

class BnkSoundSwitch extends BnkHircChunkBase with BnkHircChunkWithBaseParams {
  late int eGroupType;
  late int ulGroupID;
  late int ulDefaultSwitch;
  late int bIsContinuousValidation;
  late BnkChildren childList;
  late int ulNumSwitchGroups;
  late List<BnkSwitchPackage> switches;
  late int ulNumSwitchParams;
  late List<BnkSwitchNodeParam> switchParams;

  BnkSoundSwitch(super.type, super.size, super.uid, BnkNodeBaseParams baseParams, this.eGroupType, this.ulGroupID, this.ulDefaultSwitch, this.bIsContinuousValidation, this.childList, this.ulNumSwitchGroups, this.switches, this.ulNumSwitchParams, this.switchParams) {
    this.baseParams = baseParams;
  }

  BnkSoundSwitch.read(ByteDataWrapper bytes) : super.read(bytes) {
    baseParams = BnkNodeBaseParams.read(bytes);
    eGroupType = bytes.readUint32();
    ulGroupID = bytes.readUint32();
    ulDefaultSwitch = bytes.readUint32();
    bIsContinuousValidation = bytes.readUint8();
    childList = BnkChildren.read(bytes);
    ulNumSwitchGroups = bytes.readUint32();
    switches = List.generate(ulNumSwitchGroups, (index) => BnkSwitchPackage.read(bytes));
    ulNumSwitchParams = bytes.readUint32();
    switchParams = List.generate(ulNumSwitchParams, (index) => BnkSwitchNodeParam.read(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    baseParams.write(bytes);
    bytes.writeUint32(eGroupType);
    bytes.writeUint32(ulGroupID);
    bytes.writeUint32(ulDefaultSwitch);
    bytes.writeUint8(bIsContinuousValidation);
    childList.write(bytes);
    bytes.writeUint32(ulNumSwitchGroups);
    for (var i = 0; i < ulNumSwitchGroups; i++)
      switches[i].write(bytes);
    bytes.writeUint32(ulNumSwitchParams);
    for (var i = 0; i < ulNumSwitchParams; i++)
      switchParams[i].write(bytes);
  }

  @override
  int calculateSize() {
    return (
      baseParams.calcChunkSize() +
      4 + 4 + 4 + 1 +
      childList.calcChunkSize() +
      4 + switches.fold<int>(0, (prev, s) => prev + s.calcChunkSize()) +
      4 + switchParams.fold<int>(0, (prev, s) => prev + s.calcChunkSize())
    );
  }
}
class BnkSwitchPackage {
  late int ulSwitchID;
  late int ulNumItems;
  late List<int> nodeIDs;

  BnkSwitchPackage(this.ulSwitchID, this.ulNumItems, this.nodeIDs);

  BnkSwitchPackage.read(ByteDataWrapper bytes) {
    ulSwitchID = bytes.readUint32();
    ulNumItems = bytes.readUint32();
    nodeIDs = List.generate(ulNumItems, (index) => bytes.readUint32());
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulSwitchID);
    bytes.writeUint32(ulNumItems);
    for (var i = 0; i < ulNumItems; i++)
      bytes.writeUint32(nodeIDs[i]);
  }

  int calcChunkSize() {
    return 8 + ulNumItems * 4;
  }
}
class BnkSwitchNodeParam {
  late int ulNodeID;
  late int bIsFirstOnly;
  late int bContinuePlayback;
  late int eOnSwitchMod;
  late int fadeOutTime;
  late int fadeInTime;

  BnkSwitchNodeParam(this.ulNodeID, this.bIsFirstOnly, this.bContinuePlayback, this.eOnSwitchMod, this.fadeOutTime, this.fadeInTime);

  BnkSwitchNodeParam.read(ByteDataWrapper bytes) {
    ulNodeID = bytes.readUint32();
    bIsFirstOnly = bytes.readUint8();
    bContinuePlayback = bytes.readUint8();
    eOnSwitchMod = bytes.readUint32();
    fadeOutTime = bytes.readInt32();
    fadeInTime = bytes.readInt32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulNodeID);
    bytes.writeUint8(bIsFirstOnly);
    bytes.writeUint8(bContinuePlayback);
    bytes.writeUint32(eOnSwitchMod);
    bytes.writeInt32(fadeOutTime);
    bytes.writeInt32(fadeInTime);
  }

  int calcChunkSize() {
    return 4 + 1 + 1 + 4 + 4 + 4;
  }
}

class BnkActorMixer extends BnkHircChunkBase with BnkHircChunkWithBaseParams {
  late List<int> childIDs;

  BnkActorMixer(super.type, super.size, super.uid, BnkNodeBaseParams baseParams, this.childIDs) {
    this.baseParams = baseParams;
  }

  BnkActorMixer.read(ByteDataWrapper bytes) : super.read(bytes) {
    baseParams = BnkNodeBaseParams.read(bytes);
    int ulNumChildren = bytes.readUint32();
    childIDs = List.generate(ulNumChildren, (index) => bytes.readUint32());
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    baseParams.write(bytes);
    bytes.writeUint32(childIDs.length);
    for (var i = 0; i < childIDs.length; i++)
      bytes.writeUint32(childIDs[i]);
  }

  @override
  int calculateSize() {
    return baseParams.calcChunkSize() + 4 + childIDs.length * 4;
  }
}

class BnkSound extends BnkHircChunkBase with BnkHircChunkWithBaseParams {
  late BnkSourceData bankData;

  BnkSound(super.type, super.size, super.uid, this.bankData, BnkNodeBaseParams baseParams) {
    this.baseParams = baseParams;
  }

  BnkSound.read(ByteDataWrapper bytes) : super.read(bytes) {
    bankData = BnkSourceData.read(bytes);
    baseParams = BnkNodeBaseParams.read(bytes);
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bankData.write(bytes);
    baseParams.write(bytes);
  }

  @override
  int calculateSize() {
    return bankData.calcChunkSize() + baseParams.calcChunkSize();
  }
}


class BnkState extends BnkHircChunkBase {
  late BnkPropValue props;

  BnkState(super.type, super.size, super.uid, this.props);

  BnkState.read(ByteDataWrapper bytes) : super.read(bytes) {
    props = BnkPropValue.read(bytes);
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    props.write(bytes);
  }

  @override
  int calculateSize() {
    return props.calcChunkSize();
  }
}

class BnkSourceData {
  late int ulPluginID;
  late int streamType;
  late BnkMediaInformation mediaInformation;
  int? uSize;

  BnkSourceData(this.ulPluginID, this.streamType, this.mediaInformation, [this.uSize]);

  BnkSourceData.read(ByteDataWrapper bytes) {
    ulPluginID = bytes.readUint32();
    streamType = bytes.readUint32();
    mediaInformation = BnkMediaInformation.read(bytes, streamType);
    int pluginType = ulPluginID & 0x0F;
    bool hasParam = pluginType == 2 || pluginType == 5;
    if (hasParam && ulPluginID > 0) {
      uSize = bytes.readUint32();
    }
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulPluginID);
    bytes.writeUint32(streamType);
    mediaInformation.write(bytes);
    if (uSize != null) {
      bytes.writeUint32(uSize!);
    }
  }

  int calcChunkSize() {
    return 8 + mediaInformation.calcChunkSize() + (uSize != null ? 4 : 0);
  }
}

class BnkMediaInformation {
  late int sourceID;
  late int uFileID;
  int? fileOffset;
  int? uInMemoryMediaSize;
  late int uSourceBits;

  BnkMediaInformation(this.sourceID, this.fileOffset, this.uInMemoryMediaSize, this.uSourceBits);

  BnkMediaInformation.read(ByteDataWrapper bytes, int streamType) {
    sourceID = bytes.readUint32();
    uFileID = bytes.readUint32();
    if (streamType != 1) {
      fileOffset = bytes.readUint32();
      uInMemoryMediaSize = bytes.readUint32();
    }
    uSourceBits = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(sourceID);
    bytes.writeUint32(uFileID);
    if (fileOffset != null)
      bytes.writeUint32(fileOffset!);
    if (uInMemoryMediaSize != null)
      bytes.writeUint32(uInMemoryMediaSize!);
    bytes.writeUint8(uSourceBits);
  }

  int calcChunkSize() {
    return
      4 + // sourceID
      4 + // uFileID
      (fileOffset != null ? 4 : 0) + // fileOffset
      (uInMemoryMediaSize != null ? 4 : 0) + // uInMemoryMediaSize
      1; // uSourceBits
  }
}

mixin BnkActionParamsHasExceptions {
  BnkExceptParams get exceptions;
}
mixin BnkActionParamsHasBitVector {
  int get byBitVector;
}

class BnkExceptParams {
  late int ulExceptionListSize;
  late List<int> ids;
  late List<int> isBus;

  BnkExceptParams(this.ulExceptionListSize, this.ids, this.isBus);

  BnkExceptParams.read(ByteDataWrapper bytes) {
    ulExceptionListSize = bytes.readUint32();
    ids = List.filled(ulExceptionListSize, 0);
    isBus = List.filled(ulExceptionListSize, 0);
    for (var i = 0; i < ulExceptionListSize; i++) {
      ids[i] = bytes.readUint32();
      isBus[i] = bytes.readUint8();
    }
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulExceptionListSize);
    for (var i = 0; i < ulExceptionListSize; i++) {
      bytes.writeUint32(ids[i]);
      bytes.writeUint8(isBus[i]);
    }
  }

  int calcChunkSize() {
    return 4 + ulExceptionListSize * 5;
  }
}

abstract class ActionSpecificParams {
  void write(ByteDataWrapper bytes);
  int calcChunkSize();
}

class BnkStateActionParams implements ActionSpecificParams {
  late int ulStateGroupID;
  late int ulTargetStateID;

  BnkStateActionParams(this.ulStateGroupID, this.ulTargetStateID);

  BnkStateActionParams.read(ByteDataWrapper bytes) {
    ulStateGroupID = bytes.readUint32();
    ulTargetStateID = bytes.readUint32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulStateGroupID);
    bytes.writeUint32(ulTargetStateID);
  }

  @override
  int calcChunkSize() {
    return 8;
  }
}

class BnkSwitchActionParams implements ActionSpecificParams {
  late int ulSwitchGroupID;
  late int ulSwitchStateID;

  BnkSwitchActionParams(this.ulSwitchGroupID, this.ulSwitchStateID);

  BnkSwitchActionParams.read(ByteDataWrapper bytes) {
    ulSwitchGroupID = bytes.readUint32();
    ulSwitchStateID = bytes.readUint32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulSwitchGroupID);
    bytes.writeUint32(ulSwitchStateID);
  }

  @override
  int calcChunkSize() {
    return 8;
  }
}

const _activeActionAdditionalActionTypes = {0x403, 0x503, 0x202, 0x203, 0x204, 0x205, 0x208, 0x209, 0x302, 0x303, 0x304, 0x305, 0x308, 0x309};
class BnkActiveActionParams with BnkActionParamsHasExceptions, BnkActionParamsHasBitVector implements ActionSpecificParams {
  @override
  late int byBitVector;
  int? byBitVector2;
  @override
  late BnkExceptParams exceptions;

  BnkActiveActionParams(this.byBitVector, this.exceptions);

  BnkActiveActionParams.read(ByteDataWrapper bytes, int actionType) {
    byBitVector = bytes.readUint8();
    if (_activeActionAdditionalActionTypes.contains(actionType))
      byBitVector2 = bytes.readUint8();
    exceptions = BnkExceptParams.read(bytes);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(byBitVector);
    if (byBitVector2 != null)
      bytes.writeUint8(byBitVector2!);
    exceptions.write(bytes);
  }

  @override
  int calcChunkSize() {
    return 1 + (byBitVector2 != null ? 1 : 0) + exceptions.calcChunkSize();
  }
}

class BnkGameParameterParams implements ActionSpecificParams {
  // late int bBypassTransition;
  late int eValueMeaning;
  late double base;
  late double min;
  late double max;

  BnkGameParameterParams(this.eValueMeaning, this.base, this.min, this.max);

  BnkGameParameterParams.read(ByteDataWrapper bytes) {
    // bBypassTransition = bytes.readUint8();
    eValueMeaning = bytes.readUint8();
    base = bytes.readFloat32();
    min = bytes.readFloat32();
    max = bytes.readFloat32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    // bytes.writeUint8(bBypassTransition);
    bytes.writeUint8(eValueMeaning);
    bytes.writeFloat32(base);
    bytes.writeFloat32(min);
    bytes.writeFloat32(max);
  }

  @override
  int calcChunkSize() {
    return 1 + 3*4;
  }
}

class BnkPropActionParams implements ActionSpecificParams {
  late int eValueMeaning;
  late double base;
  late double min;
  late double max;

  BnkPropActionParams(this.eValueMeaning, this.base, this.min, this.max);

  BnkPropActionParams.read(ByteDataWrapper bytes) {
    eValueMeaning = bytes.readUint8();
    base = bytes.readFloat32();
    min = bytes.readFloat32();
    max = bytes.readFloat32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(eValueMeaning);
    bytes.writeFloat32(base);
    bytes.writeFloat32(min);
    bytes.writeFloat32(max);
  }

  @override
  int calcChunkSize() {
    return 1 + 3*4;
  }
}

const setGameParamType = 0x1300;
const resetGameParamType = 0x1400;
const gameParamActionTypes = { setGameParamType, resetGameParamType };
const _propActionActionTypes = { 0x0800, 0x0900, 0x0A00, 0x0B00, 0x0C00, 0x0D00, 0x0E00, 0x0F00, 0x2000, 0x3000 };
class BnkValueActionParams with BnkActionParamsHasExceptions, BnkActionParamsHasBitVector implements ActionSpecificParams {
  final int actionType;
  @override
  late int byBitVector;
  ActionSpecificParams? specificParams;
  @override
  late BnkExceptParams exceptions;

  BnkValueActionParams(this.actionType, this.byBitVector, this.specificParams, this.exceptions);

  BnkValueActionParams.read(ByteDataWrapper bytes, this.actionType) {
    byBitVector = bytes.readUint8();
    if (gameParamActionTypes.contains(actionType)) {
      specificParams = BnkGameParameterParams.read(bytes);
    } else if (_propActionActionTypes.contains(actionType)) {
      specificParams = BnkPropActionParams.read(bytes);
    }
    exceptions = BnkExceptParams.read(bytes);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(byBitVector);
    if (specificParams != null)
      specificParams!.write(bytes);
    exceptions.write(bytes);
  }

  @override
  int calcChunkSize() {
    return 1 + (specificParams?.calcChunkSize() ?? 0) + exceptions.calcChunkSize();
  }
}

class BnkPlayActionParams with BnkActionParamsHasBitVector implements ActionSpecificParams {
  @override
  late int byBitVector;
  late int fileID;

  BnkPlayActionParams(this.byBitVector, this.fileID);

  BnkPlayActionParams.read(ByteDataWrapper bytes) {
    byBitVector = bytes.readUint8();
    fileID = bytes.readUint32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(byBitVector);
    bytes.writeUint32(fileID);
  }

  @override
  int calcChunkSize() {
    return 1 + 4;
  }
}

class BnkBypassFXActionParams with BnkActionParamsHasExceptions implements ActionSpecificParams {
  late int bIsBypass;
  late int uTargetMask;
  @override
  late BnkExceptParams exceptions;

  BnkBypassFXActionParams(this.bIsBypass, this.uTargetMask, this.exceptions);

  BnkBypassFXActionParams.read(ByteDataWrapper bytes) {
    bIsBypass = bytes.readUint8();
    uTargetMask = bytes.readInt8();
    exceptions = BnkExceptParams.read(bytes);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(bIsBypass);
    bytes.writeInt8(uTargetMask);
    exceptions.write(bytes);
  }

  @override
  int calcChunkSize() {
    return 1*2 + exceptions.calcChunkSize();
  }
}

class BnkSeekActionParams with BnkActionParamsHasExceptions implements ActionSpecificParams {
  late int bIsSeekRelativeToDuration;
  late double fSeekValue;
  late double fSeekValueMin;
  late double fSeekValueMax;
  late int bSnapToNearestMarker;
  @override
  late BnkExceptParams exceptions;

  BnkSeekActionParams(this.bIsSeekRelativeToDuration, this.fSeekValue, this.fSeekValueMin, this.fSeekValueMax, this.bSnapToNearestMarker, this.exceptions);

  BnkSeekActionParams.read(ByteDataWrapper bytes) {
    bIsSeekRelativeToDuration = bytes.readUint8();
    fSeekValue = bytes.readFloat32();
    fSeekValueMin = bytes.readFloat32();
    fSeekValueMax = bytes.readFloat32();
    bSnapToNearestMarker = bytes.readUint8();
    exceptions = BnkExceptParams.read(bytes);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(bIsSeekRelativeToDuration);
    bytes.writeFloat32(fSeekValue);
    bytes.writeFloat32(fSeekValueMin);
    bytes.writeFloat32(fSeekValueMax);
    bytes.writeUint8(bSnapToNearestMarker);
    exceptions.write(bytes);
  }

  @override
  int calcChunkSize() {
    return 1 + 3*4 + 1 + exceptions.calcChunkSize();
  }
}

class BnkActionInitialParams implements ActionSpecificParams {
  late int idExt;
  late int idExt_4;
  late BnkPropValue propValues;
  late BnkPropRangedValue rangedPropValues;

  BnkActionInitialParams(this.idExt, this.idExt_4, this.propValues, this.rangedPropValues);

  BnkActionInitialParams.read(ByteDataWrapper bytes) {
    idExt = bytes.readUint32();
    idExt_4 = bytes.readUint8();
    propValues = BnkPropValue.read(bytes);
    rangedPropValues = BnkPropRangedValue.read(bytes);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(idExt);
    bytes.writeUint8(idExt_4);
    propValues.write(bytes);
    rangedPropValues.write(bytes);
  }

  @override
  int calcChunkSize() {
    return 4 + 1 + propValues.calcChunkSize() + rangedPropValues.calcChunkSize();
  }

  bool get isBus => (idExt_4 & 0x1) == 1;
}

const _activeActionParamsActionsTypes = {0x0100, 0x0200, 0x0300, 0x2200};
const _playActionParamsActionsTypes = {0x0400, 0x0500, 0x2300};
const _bypassFXActionParamsActionsTypes = {0x1A00, 0x1B00};
const _valueActionParamsActionsTypes = { 0x0600, 0x0700, 0x0800, 0x0900, 0x0A00, 0x0B00, 0x0C00, 0x0D00, 0x0E00, 0x0F00, 0x1300, 0x1400, 0x2000, 0x3000 };
const _switchActionParamsActionsTypes = {0x1900};
const _stateActionParamsActionsTypes = {0x1200};
const _seekActionsTypes = {0x1E00};
class BnkAction extends BnkHircChunkBase {
  late int ulActionType;
  late BnkActionInitialParams initialParams;
  ActionSpecificParams? specificParams;

  BnkAction(super.type, super.size, super.uid, this.ulActionType, this.initialParams, this.specificParams);

  BnkAction.read(ByteDataWrapper bytes) : super.read(bytes) {
    ulActionType = bytes.readUint16();
    initialParams = BnkActionInitialParams.read(bytes);
    var actionType = ulActionType & 0xFF00;
    if (_activeActionParamsActionsTypes.contains(actionType)) {
      specificParams = BnkActiveActionParams.read(bytes, ulActionType);
    } else if (_playActionParamsActionsTypes.contains(actionType)) {
      specificParams = BnkPlayActionParams.read(bytes);
    } else if (_bypassFXActionParamsActionsTypes.contains(actionType)) {
      specificParams = BnkBypassFXActionParams.read(bytes);
    } else if (_valueActionParamsActionsTypes.contains(actionType)) {
      specificParams = BnkValueActionParams.read(bytes, actionType);
    } else if (_switchActionParamsActionsTypes.contains(actionType)) {
      specificParams = BnkSwitchActionParams.read(bytes);
    } else if (_stateActionParamsActionsTypes.contains(actionType)) {
      specificParams = BnkStateActionParams.read(bytes);
    } else if (_seekActionsTypes.contains(actionType)) {
      specificParams = BnkSeekActionParams.read(bytes);
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint16(ulActionType);
    initialParams.write(bytes);
    if (specificParams != null)
      specificParams!.write(bytes);
  }

  @override
  int calculateSize() {
    return 2 + initialParams.calcChunkSize() + (specificParams?.calcChunkSize() ?? 0);
  }
}

const actionTypes = {
  0x0000: "None",
  0x1204: "SetState",
  0x1A02: "BypassFX_M",
  0x1A03: "BypassFX_O",
  0x1B02: "ResetBypassFX_M",
  0x1B03: "ResetBypassFX_O",
  0x1B04: "ResetBypassFX_ALL",
  0x1B05: "ResetBypassFX_ALL_O",
  0x1B08: "ResetBypassFX_AE",
  0x1B09: "ResetBypassFX_AE_O",
  0x1901: "SetSwitch",
  0x1002: "UseState_E",
  0x1102: "UnuseState_E",
  0x0403: "Play",
  0x0503: "PlayAndContinue",
  0x0102: "Stop_E",
  0x0103: "Stop_E_O",
  0x0104: "Stop_ALL",
  0x0105: "Stop_ALL_O",
  0x0108: "Stop_AE",
  0x0109: "Stop_AE_O",
  0x0202: "Pause_E",
  0x0203: "Pause_E_O",
  0x0204: "Pause_ALL",
  0x0205: "Pause_ALL_O",
  0x0208: "Pause_AE",
  0x0209: "Pause_AE_O",
  0x0302: "Resume_E",
  0x0303: "Resume_E_O",
  0x0304: "Resume_ALL",
  0x0305: "Resume_ALL_O",
  0x0308: "Resume_AE",
  0x0309: "Resume_AE_O",
  0x1C02: "Break_E",
  0x1C03: "Break_E_O",
  0x0602: "Mute_M",
  0x0603: "Mute_O",
  0x0702: "Unmute_M",
  0x0703: "Unmute_O",
  0x0704: "Unmute_ALL",
  0x0705: "Unmute_ALL_O",
  0x0708: "Unmute_AE",
  0x0709: "Unmute_AE_O",
  0x0A02: "SetVolume_M",
  0x0A03: "SetVolume_O",
  0x0B02: "ResetVolume_M",
  0x0B03: "ResetVolume_O",
  0x0B04: "ResetVolume_ALL",
  0x0B05: "ResetVolume_ALL_O",
  0x0B08: "ResetVolume_AE",
  0x0B09: "ResetVolume_AE_O",
  0x0802: "SetPitch_M",
  0x0803: "SetPitch_O",
  0x0902: "ResetPitch_M",
  0x0903: "ResetPitch_O",
  0x0904: "ResetPitch_ALL",
  0x0905: "ResetPitch_ALL_O",
  0x0908: "ResetPitch_AE",
  0x0909: "ResetPitch_AE_O",
  0x0E02: "SetLPF_M",
  0x0E03: "SetLPF_O",
  0x0F02: "ResetLPF_M",
  0x0F03: "ResetLPF_O",
  0x0F04: "ResetLPF_ALL",
  0x0F05: "ResetLPF_ALL_O",
  0x0F08: "ResetLPF_AE",
  0x0F09: "ResetLPF_AE_O",
  0x2002: "SetHPF_M",
  0x2003: "SetHPF_O",
  0x3002: "ResetHPF_M",
  0x3003: "ResetHPF_O",
  0x3004: "ResetHPF_ALL",
  0x3005: "ResetHPF_ALL_O",
  0x3008: "ResetHPF_AE",
  0x3009: "ResetHPF_AE_O",
  0x0C02: "SetBusVolume_M",
  0x0C03: "SetBusVolume_O",
  0x0D02: "ResetBusVolume_M",
  0x0D03: "ResetBusVolume_O",
  0x0D04: "ResetBusVolume_ALL",
  0x0D08: "ResetBusVolume_AE",
  0x2103: "PlayEvent",
  0x1511: "StopEvent",
  0x1611: "PauseEvent",
  0x1711: "ResumeEvent",
  0x1820: "Duck",
  0x1D00: "Trigger",
  0x1D01: "Trigger_O",
  0x1D02: "Trigger_E?",
  0x1D03: "Trigger_E_O?",
  0x1E02: "Seek_E",
  0x1E03: "Seek_E_O",
  0x1E04: "Seek_ALL",
  0x1E05: "Seek_ALL_O",
  0x1E08: "Seek_AE",
  0x1E09: "Seek_AE_O",
  0x2202: "ResetPlaylist_E",
  0x2203: "ResetPlaylist_E_O",
  0x1302: "SetGameParameter",
  0x1303: "SetGameParameter_O",
  0x1402: "ResetGameParameter",
  0x1403: "ResetGameParameter_O",
  0x1F02: "Release",
  0x1F03: "Release_O",
  0x2303: "PlayEventUnknown_O?",
  0x3102: "SetFX_M",
  0x3202: "ResetSetFX_M",
  0x3204: "ResetSetFX_ALL",
  0x4000: "NoOp",
};

const syncTypes = {
  0x0: "Immediate",
  0x1: "NextGrid",
  0x2: "NextBar",
  0x3: "NextBeat",
  0x4: "NextMarker",
  0x5: "NextUserMarker",
  0x6: "EntryMarker",
  0x7: "ExitMarker",
  0x8: "ExitNever",
  0x9: "LastExitPosition",
};

const curveInterpolations = {
  0x0: "Log3",
  0x1: "Sine",
  0x2: "Log1",
  0x3: "InvSCurve",
  0x4: "Linear",
  0x5: "SCurve",
  0x6: "Exp1",
  0x7: "SineRecip",
  0x8: "Exp3",
  0x9: "Constant",
};

const entryTypes = {
  0x0: "EntryMarker",
  0x1: "SameTime",
  0x2: "RandomMarker",
  0x3: "RandomUserMarker",
  0x4: "LastExitTime",
};
