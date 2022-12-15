
import '../utils/ByteDataWrapper.dart';

mixin SimpleComp<T> {
  bool isSame(T other, Map<int, BnkHircChunkBase> hircObjects);
}

abstract class ChunkBase {
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
}

class BnkFile {
  List<BnkChunkBase> chunks = [];

  BnkFile(this.chunks);

  BnkFile.read(ByteDataWrapper bytes) {
    while (bytes.position < bytes.length) {
      chunks.add(_makeNextChunk(bytes));
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
      case "HIRC": return BnkHircChunk.read(bytes);
      default: return BnkUnknownChunk.read(bytes);
    }
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
}

class BnkHircChunk extends BnkChunkBase {
  late List<BnkHircChunkBase> chunks;

  BnkHircChunk(super.chunkId, super.chunkSize, this.chunks);

  BnkHircChunk.read(ByteDataWrapper bytes) : super.read(bytes) {
    int childrenCount = bytes.readUint32();
    chunks = List.generate(childrenCount, (index) => _makeNextHircChunk(bytes));
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint32(chunks.length);
    for (var chunk in chunks) {
      chunk.write(bytes);
    }
  }
}

enum BnkHircType {
  musicTrack(0x0B),
  musicSegment(0x0A),
  musicPlaylist(0x0D);

  const BnkHircType(this.value);
  final int value;
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
  switch (type) {
    case 0x0B: return BnkMusicTrack.read(bytes);
    case 0x0A: return BnkMusicSegment.read(bytes);
    case 0x0D: return BnkMusicPlaylist.read(bytes);
    default: return BnkHircUnknownChunk.read(bytes);
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
}

/*
typedef struct{
    byte uFlags;
    uint numSources; //this seems promising to play with
    for(i=0;i<numSources;i++){
        pSource Source;
    };
    uint numPlaylistItem;
    for(i=0;i<numPlaylistItem;i++){
        pPlaylist Playlist;
    };
    if(numPlaylistItem>0) uint numSubTrack;//doesn't seem to have children?
    uint numClipAutomationItem;
    for(j=0;j<numClipAutomationItem;j++){
        AkClipAutomation ClipAutomation;
    };
    NodeBaseParams BaseParams;
    byte eTrackType;
    if(eTrackType == 3){
        SwitchParams SwitchParam;
        TransParams TransParam;
    };
    int iLookAheadTime;
}MusicTrack;
*/
class BnkMusicTrack extends BnkHircChunkBase with SimpleComp<BnkMusicTrack> {
  late int uFlags;
  late int numSources;
  late List<BnkSource> sources;
  late int numPlaylistItem;
  late List<BnkPlaylist> playlists;
  int? numSubTrack;
  late int numClipAutomationItem;
  late List<BnkClipAutomation> clipAutomations;
  late BnkNodeBaseParams baseParams;
  late int eTrackType;
  BnkSwitchParams? switchParam;
  BnkTransParams? transParam;
  late int iLookAheadTime;

  BnkMusicTrack(super.chunkId, super.chunkSize, super.type, this.uFlags, this.numSources, this.sources, this.numPlaylistItem, this.playlists, this.numSubTrack, this.numClipAutomationItem, this.clipAutomations, this.baseParams, this.eTrackType, this.switchParam, this.transParam, this.iLookAheadTime);

  BnkMusicTrack.read(ByteDataWrapper bytes) : super.read(bytes) {
    uFlags = bytes.readUint8();
    numSources = bytes.readUint32();
    sources = List.generate(numSources, (index) => BnkSource.read(bytes));
    numPlaylistItem = bytes.readUint32();
    playlists = List.generate(numPlaylistItem, (index) => BnkPlaylist.read(bytes));
    if (numPlaylistItem > 0)
      numSubTrack = bytes.readUint32();
    numClipAutomationItem = bytes.readUint32();
    clipAutomations = List.generate(numClipAutomationItem, (index) => BnkClipAutomation.read(bytes));
    baseParams = BnkNodeBaseParams.read(bytes);
    eTrackType = bytes.readUint8();
    if (eTrackType == 3) {
      switchParam = BnkSwitchParams.read(bytes);
      transParam = BnkTransParams.read(bytes);
    }
    iLookAheadTime = bytes.readUint32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    super.write(bytes);
    bytes.writeUint8(uFlags);
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
    bytes.writeUint8(eTrackType);
    if (eTrackType == 3) {
      switchParam!.write(bytes);
      transParam!.write(bytes);
    }
    bytes.writeUint32(iLookAheadTime);
  }

  @override
  bool isSame(BnkMusicTrack other, Map<int, BnkHircChunkBase> hircObjects) {
    return (
      numSources == other.numSources &&
      sources.every((s1) => other.sources.any((s2) => s1.isSame(s2, hircObjects))) &&
      numPlaylistItem == other.numPlaylistItem &&
      playlists.every((p1) => other.playlists.any((p2) => p1.isSame(p2, hircObjects)))
    );
  }

  int calcChunkSize() {
    return (
      4 + // header uid
      1 + // uFlags
      4 + // numSources
      sources.fold<int>(0, (sum, s) => sum + s.calcChunkSize()) +  // sources
      4 + // numPlaylistItem
      playlists.fold<int>(0, (sum, p) => sum + p.calcChunkSize()) +  // playlists
      (numPlaylistItem > 0 ? 4 : 0) + // numSubTrack
      4 + // numClipAutomationItem
      clipAutomations.fold<int>(0, (sum, c) => sum + c.calcChunkSize()) +  // clipAutomations
      baseParams.calcChunkSize() +  // baseParams
      1 + // eTrackType
      (eTrackType == 3 ? switchParam!.calcChunkSize() + transParam!.calcChunkSize() : 0) +  // switchParam, transParam
      4 // iLookAheadTime
    );
  }
}

class BnkMusicSegment extends BnkHircChunkBase with SimpleComp<BnkMusicSegment> {
  late BnkMusicNodeParams musicParams;
  late double fDuration;
  late int ulNumMarkers;
  late List<BnkMusicMarker> wwiseMarkers;

  BnkMusicSegment(super.chunkId, super.chunkSize, super.type, this.musicParams, this.fDuration, this.ulNumMarkers, this.wwiseMarkers);

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
  bool isSame(BnkMusicSegment other, Map<int, BnkHircChunkBase> hircObjects) {
    return (
      musicParams.isSame(other.musicParams, hircObjects) &&
      fDuration == other.fDuration &&
      ulNumMarkers == other.ulNumMarkers &&
      wwiseMarkers.every((m1) => other.wwiseMarkers.any((m2) => m1.isSame(m2, hircObjects)))
    );
  }
}

class BnkMusicPlaylist extends BnkHircChunkBase with SimpleComp<BnkMusicPlaylist> {
  late BnkMusicTransNodeParams musicTransParams;
  late int numPlaylistItems;
  late List<BnkPlaylistItem> playlistItems;

  BnkMusicPlaylist(super.chunkId, super.chunkSize, super.type, this.musicTransParams, this.numPlaylistItems, this.playlistItems);

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
  bool isSame(BnkMusicPlaylist other, Map<int, BnkHircChunkBase> hircObjects) {
    return (
      numPlaylistItems == other.numPlaylistItems &&
      playlistItems.every((p1) => other.playlistItems.any((p2) => p1.isSame(p2, hircObjects)))
    );
  }
}

class BnkPlaylistItem with SimpleComp<BnkPlaylistItem> {
  late int segmentId;
  late int playlistItemId;
  late int numChildren;
  late int eRSType;
  late int loop;
  late int loopMin;
  late int loopMax;
  late int weight;
  late int wAvoidRepeatCount;
  late int bIsUsingWeight;
  late int bIsShuffle;

  BnkPlaylistItem(this.segmentId, this.playlistItemId, this.numChildren, this.eRSType, this.loop, this.loopMin, this.loopMax, this.weight, this.wAvoidRepeatCount, this.bIsUsingWeight, this.bIsShuffle);

  BnkPlaylistItem.read(ByteDataWrapper bytes) {
    segmentId = bytes.readUint32();
    playlistItemId = bytes.readUint32();
    numChildren = bytes.readUint32();
    eRSType = bytes.readInt32();
    loop = bytes.readInt16();
    loopMin = bytes.readInt16();
    loopMax = bytes.readInt16();
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
    bytes.writeInt16(loopMin);
    bytes.writeInt16(loopMax);
    bytes.writeUint32(weight);
    bytes.writeUint16(wAvoidRepeatCount);
    bytes.writeUint8(bIsUsingWeight);
    bytes.writeUint8(bIsShuffle);
  }

  @override
  bool isSame(BnkPlaylistItem other, Map<int, BnkHircChunkBase> hircObjects) {
    return (
      segmentId == 0 && other.segmentId == 0 || (
        hircObjects.containsKey(segmentId) &&
        hircObjects.containsKey(other.segmentId) &&
        (hircObjects[segmentId]! as BnkMusicSegment).isSame((hircObjects[other.segmentId]! as BnkMusicSegment), hircObjects)
      ) &&
      numChildren == other.numChildren
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
}

/*
typedef struct{
    uint uNumSrc;
    for(i=0;i<uNumSrc;i++){
        uint srcNumID;
    };
    uint uNumDst;
    for(i=0;i<uNumDst;i++){
        uint dstNumID;
    };
    AkMusicTransSrcRule SrcRule;
    AkMusicTransDstRule DstRule;
    byte AllocTransObjectFlag;
    if(AllocTransObjectFlag){
        AkMusicTransitionObject MusicTransition;
    };
}MusicTransitionRule;
*/
class BnkMusicTransitionRule {
  late int uNumSrc;
  late List<int> srcNumIDs;
  late int uNumDst;
  late List<int> dstNumIDs;
  late BnkMusicTransSrcRule srcRule;
  late BnkMusicTransDstRule dstRule;
  late int allocTransObjectFlag;
  BnkMusicTransitionObject? musicTransition;

  BnkMusicTransitionRule(this.uNumSrc, this.srcNumIDs, this.uNumDst, this.dstNumIDs, this.srcRule, this.dstRule, this.allocTransObjectFlag, this.musicTransition);

  BnkMusicTransitionRule.read(ByteDataWrapper bytes) {
    uNumSrc = bytes.readUint32();
    srcNumIDs = List.generate(uNumSrc, (index) => bytes.readUint32());
    uNumDst = bytes.readUint32();
    dstNumIDs = List.generate(uNumDst, (index) => bytes.readUint32());
    srcRule = BnkMusicTransSrcRule.read(bytes);
    dstRule = BnkMusicTransDstRule.read(bytes);
    allocTransObjectFlag = bytes.readUint8();
    if (allocTransObjectFlag == 1)
      musicTransition = BnkMusicTransitionObject.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(uNumSrc);
    for (var i = 0; i < uNumSrc; i++)
      bytes.writeUint32(srcNumIDs[i]);
    bytes.writeUint32(uNumDst);
    for (var i = 0; i < uNumDst; i++)
      bytes.writeUint32(dstNumIDs[i]);
    srcRule.write(bytes);
    dstRule.write(bytes);
    bytes.writeUint8(allocTransObjectFlag);
    if (allocTransObjectFlag == 1)
      musicTransition!.write(bytes);
  }
}

/*
typedef struct{
    FadeParams FadeParam;
    uint uCueFilterHash;
    uint uJumpToID;
    uint16 eEntryType;
    byte bPlayPreEntry;
    byte bDestMatchSourceCueName;
}AkMusicTransSrcRule;
*/
class BnkMusicTransSrcRule {
  late BnkFadeParams fadeParam;
  late int uCueFilterHash;
  late int uJumpToID;
  late int eEntryType;
  late int bPlayPreEntry;
  late int bDestMatchSourceCueName;

  BnkMusicTransSrcRule(this.fadeParam, this.uCueFilterHash, this.uJumpToID, this.eEntryType, this.bPlayPreEntry, this.bDestMatchSourceCueName);

  BnkMusicTransSrcRule.read(ByteDataWrapper bytes) {
    fadeParam = BnkFadeParams.read(bytes);
    uCueFilterHash = bytes.readUint32();
    uJumpToID = bytes.readUint32();
    eEntryType = bytes.readUint16();
    bPlayPreEntry = bytes.readUint8();
    bDestMatchSourceCueName = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    fadeParam.write(bytes);
    bytes.writeUint32(uCueFilterHash);
    bytes.writeUint32(uJumpToID);
    bytes.writeUint16(eEntryType);
    bytes.writeUint8(bPlayPreEntry);
    bytes.writeUint8(bDestMatchSourceCueName);
  }
}

/*
typedef struct{
    FadeParams FadeParam;
    uint eSyncType;
    uint uCueFilterHash;
    byte bPlayPostExit;
}AkMusicTransDstRule;
*/
class BnkMusicTransDstRule {
  late BnkFadeParams fadeParam;
  late int eSyncType;
  late int uCueFilterHash;
  late int bPlayPostExit;

  BnkMusicTransDstRule(this.fadeParam, this.eSyncType, this.uCueFilterHash, this.bPlayPostExit);

  BnkMusicTransDstRule.read(ByteDataWrapper bytes) {
    fadeParam = BnkFadeParams.read(bytes);
    eSyncType = bytes.readUint32();
    uCueFilterHash = bytes.readUint32();
    bPlayPostExit = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    fadeParam.write(bytes);
    bytes.writeUint32(eSyncType);
    bytes.writeUint32(uCueFilterHash);
    bytes.writeUint8(bPlayPostExit);
  }
}

/*
typedef struct{
    uint segmentID;
    FadeParams fadeInParams;
    FadeParams fadeOutParams;
    byte PlayPreEntry;
    byte PlayPostExit;
}AkMusicTransitionObject;
*/
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
}

/*
typedef struct{
    uint id;
    double fPosition;
    uint uStringSize;
    if(uStringSize > 0)
        char pMarkerName[uStringSize];
}MusicMarker;
*/
class BnkMusicMarker with SimpleComp<BnkMusicMarker> {
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

  @override
  bool isSame(BnkMusicMarker other, Map<int, BnkHircChunkBase> hircObjects) {
    return (
      fPosition == other.fPosition &&
      uStringSize == other.uStringSize &&
      pMarkerName == other.pMarkerName
    );
  }
}

/*
typedef struct{
    byte uFlags;
    NodeBaseParams BaseParams;
    Children ChildrenList;
    AkMeterInfo MeterInfo;
    byte bMeterInfoFlag;
    uint uNumStingers;
    for(i=0;i<uNumStingers;i++){
        AkStinger Stinger;
    };
}MusicNodeParams;
*/
class BnkMusicNodeParams with SimpleComp<BnkMusicNodeParams> {
  late int uFlags;
  late BnkNodeBaseParams baseParams;
  late BnkChildren childrenList;
  late BnkAkMeterInfo meterInfo;
  late int bMeterInfoFlag;
  late int uNumStingers;
  late List<BnkAkStinger> stingers;

  BnkMusicNodeParams(this.uFlags, this.baseParams, this.childrenList, this.meterInfo, this.bMeterInfoFlag, this.uNumStingers, this.stingers);

  BnkMusicNodeParams.read(ByteDataWrapper bytes) {
    uFlags = bytes.readUint8();
    baseParams = BnkNodeBaseParams.read(bytes);
    childrenList = BnkChildren.read(bytes);
    meterInfo = BnkAkMeterInfo.read(bytes);
    bMeterInfoFlag = bytes.readUint8();
    uNumStingers = bytes.readUint32();
    stingers = List.generate(uNumStingers, (index) => BnkAkStinger.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(uFlags);
    baseParams.write(bytes);
    childrenList.write(bytes);
    meterInfo.write(bytes);
    bytes.writeUint8(bMeterInfoFlag);
    bytes.writeUint32(uNumStingers);
    for (var i = 0; i < uNumStingers; i++)
      stingers[i].write(bytes);
  }

  @override
  bool isSame(BnkMusicNodeParams other, Map<int, BnkHircChunkBase> hircObjects) {
    return (
      childrenList.isSame(other.childrenList, hircObjects)
    );
  }
}

/*
typedef struct{
    uint uNumChildren;
    for(i=0;i<uNumChildren;i++){
        uint ulChildID;
    };
}Children;
*/
class BnkChildren with SimpleComp<BnkChildren> {
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

  @override
  bool isSame(BnkChildren other, Map<int, BnkHircChunkBase> hircObjects) {
    return (
      uNumChildren == other.uNumChildren &&
      (
        uNumChildren == 0 ||
        hircObjects[ulChildIDs[0]] is SimpleComp &&
        (hircObjects[ulChildIDs[0]]! as SimpleComp).isSame(hircObjects[other.ulChildIDs[0]]!, hircObjects)
      )
    );
  }
}

/*
typedef struct{
    double fGridPeriod;
    double fGridOffset;
    float fTempo;
    byte uNumBeatsPerBar;//top number of time signature
    byte uBeatValue;//bottom number of time signature
}AkMeterInfo;
*/
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
}

/*
typedef struct{
    uint TriggerID;
    uint SegmentID;
    uint SyncPlayAt;
    uint uCueFilterHash;
    int DontRepeatTime;
    uint numSegmentLookAhead;
}AkStinger;
*/
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
}

class BnkSource with SimpleComp<BnkSource> {
  late int ulPluginID;
  late int streamType;
  late int sourceID;
  late int uInMemorySize;
  late int uSourceBits;

  BnkSource(this.ulPluginID, this.streamType, this.sourceID, this.uInMemorySize, this.uSourceBits);

  BnkSource.read(ByteDataWrapper bytes) {
    ulPluginID = bytes.readUint32();
    streamType = bytes.readUint8();
    sourceID = bytes.readUint32();
    uInMemorySize = bytes.readUint32();
    uSourceBits = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulPluginID);
    bytes.writeUint8(streamType);
    bytes.writeUint32(sourceID);
    bytes.writeUint32(uInMemorySize);
    bytes.writeUint8(uSourceBits);
  }

  @override
  bool isSame(BnkSource other, Map<int, BnkHircChunkBase> hircObjects) {
    return sourceID == other.sourceID;
  }
  
  int calcChunkSize() {
    return 14;
  }
}

class BnkPlaylist with SimpleComp<BnkPlaylist> {
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

@override
bool isSame(BnkPlaylist other, Map<int, BnkHircChunkBase> hircObjects) {
    return (
      sourceID == other.sourceID &&
      fPlayAt == other.fPlayAt &&
      fBeginTrimOffset == other.fBeginTrimOffset &&
      fEndTrimOffset == other.fEndTrimOffset &&
      fSrcDuration == other.fSrcDuration
    );
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
}

class BnkRtpcGraphPoint {
  late double to;
  late double from;
  late int interpolation;

  BnkRtpcGraphPoint(this.to, this.from, this.interpolation);

  BnkRtpcGraphPoint.read(ByteDataWrapper bytes) {
    to = bytes.readFloat32();
    from = bytes.readFloat32();
    interpolation = bytes.readUint32();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(to);
    bytes.writeFloat32(from);
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

class BnkPropValue {
  late int cProps;
  late List<int> pID;
  late List<int> pValueBytes;

  BnkPropValue(this.cProps, this.pID, this.pValueBytes);

  BnkPropValue.read(ByteDataWrapper bytes) {
    cProps = bytes.readUint8();
    pID = List.generate(cProps, (index) => bytes.readUint8());
    pValueBytes = List.generate(cProps*4, (index) => bytes.readUint8());
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(cProps);
    for (var i = 0; i < cProps; i++)
      bytes.writeUint8(pID[i]);
    for (var b in pValueBytes)
      bytes.writeUint8(b);
  }
  
  int calcChunkSize() {
    return 1 + cProps + cProps * 4;
  }
}

class BnkPropRangedValue {
  late int cProps;
  late List<int> pID;
  late List<int> pValueBytes;

  BnkPropRangedValue(this.cProps, this.pID, this.pValueBytes);

  BnkPropRangedValue.read(ByteDataWrapper bytes) {
    cProps = bytes.readUint8();
    pID = List.generate(cProps, (index) => bytes.readUint8());
    pValueBytes = Iterable.generate(cProps, (index) {
      if (pID[index] == 2 || pID[index] == 0)
        return List.generate(8, (index) => bytes.readUint8());
      else
        return List.generate(4, (index) => bytes.readUint8());
    })
      .expand((element) => element)
      .toList();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(cProps);
    for (var i = 0; i < cProps; i++)
      bytes.writeUint8(pID[i]);
    for (var b in pValueBytes)
      bytes.writeUint8(b);
  }
  
  int calcChunkSize() {
    return 1 + cProps + pValueBytes.length;
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

class BnkPositioningParams {
  late int uBitsPositioning;
  int? uBits3D;
  int? attenuationID;

  BnkPositioningParams(this.uBitsPositioning, this.uBits3D, this.attenuationID);

  BnkPositioningParams.read(ByteDataWrapper bytes) {
    uBitsPositioning = bytes.readUint8();
    var hasPositioning = (uBitsPositioning >> 0) & 1;
    var has3D = hasPositioning == 1 ? (uBitsPositioning >> 3) & 1 : 0;
    if (has3D == 1) {
      uBits3D = bytes.readUint8();
      attenuationID = bytes.readUint32();
    }
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(uBitsPositioning);
    if (uBits3D != null && attenuationID != null) {
      bytes.writeUint8(uBits3D!);
      bytes.writeUint32(attenuationID!);
    }
  }
  
  int calcChunkSize() {
    return 1 + (uBits3D != null && attenuationID != null ? 5 : 0);
  }
}

class BnkAuxParams {
  late int byBitVector;
  int? auxID1;
  int? auxID2;
  int? auxID3;
  int? auxID4;

  BnkAuxParams(this.byBitVector, this.auxID1, this.auxID2, this.auxID3, this.auxID4);

  BnkAuxParams.read(ByteDataWrapper bytes) {
    byBitVector = bytes.readUint8();
    var hasAux = byBitVector >> 2;
    if (hasAux == 1) {
      auxID1 = bytes.readUint32();
      auxID2 = bytes.readUint32();
      auxID3 = bytes.readUint32();
      auxID4 = bytes.readUint32();
    }
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(byBitVector);
    if (auxID1 != null && auxID2 != null && auxID3 != null && auxID4 != null) {
      bytes.writeUint32(auxID1!);
      bytes.writeUint32(auxID2!);
      bytes.writeUint32(auxID3!);
      bytes.writeUint32(auxID4!);
    }
  }
  
  int calcChunkSize() {
    return 1 + (auxID1 != null && auxID2 != null && auxID3 != null && auxID4 != null ? 16 : 0);
  }
}

class BnkAdvSettingsParams {
  late int byBitVector1;
  late int eVirtualQueueBehavior;
  late int uMaxNumInstance;
  late int eBelowThresholdBehavior;
  late int byBitVector2;

  BnkAdvSettingsParams(this.byBitVector1, this.eVirtualQueueBehavior, this.uMaxNumInstance, this.eBelowThresholdBehavior, this.byBitVector2);

  BnkAdvSettingsParams.read(ByteDataWrapper bytes) {
    byBitVector1 = bytes.readUint8();
    eVirtualQueueBehavior = bytes.readUint8();
    uMaxNumInstance = bytes.readUint16();
    eBelowThresholdBehavior = bytes.readUint8();
    byBitVector2 = bytes.readUint8();
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(byBitVector1);
    bytes.writeUint8(eVirtualQueueBehavior);
    bytes.writeUint16(uMaxNumInstance);
    bytes.writeUint8(eBelowThresholdBehavior);
    bytes.writeUint8(byBitVector2);
  }
  
  int calcChunkSize() {
    return 6;
  }
}

class BnkStateChunk {
  late int ulNumStateGroups;
  late List<BnkStateGroup> stateGroup;

  BnkStateChunk(this.ulNumStateGroups, this.stateGroup);

  BnkStateChunk.read(ByteDataWrapper bytes) {
    ulNumStateGroups = bytes.readUint32();
    stateGroup = List.generate(ulNumStateGroups, (index) => BnkStateGroup.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulNumStateGroups);
    for (var i = 0; i < ulNumStateGroups; i++)
      stateGroup[i].write(bytes);
  }
  
  int calcChunkSize() {
    return 4 + stateGroup.fold<int>(0, (previousValue, element) => previousValue + element.calcChunkSize());
  }
}
class BnkStateGroup {
  late int ulStateGroupID;
  late int eStateSyncType;
  late int ulNumStates;
  late List<BnkState> state;

  BnkStateGroup(this.ulStateGroupID, this.eStateSyncType, this.ulNumStates, this.state);

  BnkStateGroup.read(ByteDataWrapper bytes) {
    ulStateGroupID = bytes.readUint32();
    eStateSyncType = bytes.readUint8();
    ulNumStates = bytes.readUint16();
    state = List.generate(ulNumStates, (index) => BnkState.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(ulStateGroupID);
    bytes.writeUint8(eStateSyncType);
    bytes.writeUint16(ulNumStates);
    for (var i = 0; i < ulNumStates; i++)
      state[i].write(bytes);
  }
  
  int calcChunkSize() {
    return 7 + state.fold<int>(0, (previousValue, element) => previousValue + element.calcChunkSize());
  }
}
class BnkState {
  late int ulStateID;
  late int ulStateInstanceID;

  BnkState(this.ulStateID, this.ulStateInstanceID);

  BnkState.read(ByteDataWrapper bytes) {
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
    return 2 + rtpc.fold<int>(0, (previousValue, element) => previousValue + element.calcChunkSize());
  }
}
class BnkRtpc {
  late int rtpcId;
  late int rtpcType;
  late int rtpcAcc;
  late int paramID;
  late int rtpcCurveID;
  late int eScaling;
  late int ulSize;
  late List<BnkRtpcGraphPoint> rtpcGraphPoint;

  BnkRtpc(this.rtpcId, this.rtpcType, this.rtpcAcc, this.paramID, this.rtpcCurveID, this.eScaling, this.ulSize, this.rtpcGraphPoint);

  BnkRtpc.read(ByteDataWrapper bytes) {
    rtpcId = bytes.readUint32();
    rtpcType = bytes.readUint8();
    rtpcAcc = bytes.readUint8();
    paramID = bytes.readUint8();
    rtpcCurveID = bytes.readUint32();
    eScaling = bytes.readUint8();
    ulSize = bytes.readUint16();
    rtpcGraphPoint = List.generate(ulSize, (index) => BnkRtpcGraphPoint.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(rtpcId);
    bytes.writeUint8(rtpcType);
    bytes.writeUint8(rtpcAcc);
    bytes.writeUint8(paramID);
    bytes.writeUint32(rtpcCurveID);
    bytes.writeUint8(eScaling);
    bytes.writeUint16(ulSize);
    for (var i = 0; i < ulSize; i++)
      rtpcGraphPoint[i].write(bytes);
  }
  
  int calcChunkSize() {
    return 14 + rtpcGraphPoint.fold<int>(0, (previousValue, element) => previousValue + element.calcChunkSize());
  }
}

class BnkNodeBaseParams {
  late BnkNodeInitialFXParams fxParams;
  late int bOverrideAttachmentParams;
  late int overrideBusID;
  late int directParentID;
  late int byBitVector;
  late BnkNodeInitialParams iniParams;
  late BnkPositioningParams positioning;
  late BnkAuxParams auxParam;
  late BnkAdvSettingsParams advSettings;
  late BnkStateChunk states;
  late BnkInitialRTPC rtpc;

  BnkNodeBaseParams(this.fxParams, this.bOverrideAttachmentParams, this.overrideBusID, this.directParentID, this.byBitVector, this.iniParams, this.positioning, this.auxParam, this.advSettings, this.states, this.rtpc);

  BnkNodeBaseParams.read(ByteDataWrapper bytes) {
    fxParams = BnkNodeInitialFXParams.read(bytes);
    bOverrideAttachmentParams = bytes.readUint8();
    overrideBusID = bytes.readUint32();
    directParentID = bytes.readUint32();
    byBitVector = bytes.readUint8();
    iniParams = BnkNodeInitialParams.read(bytes);
    positioning = BnkPositioningParams.read(bytes);
    auxParam = BnkAuxParams.read(bytes);
    advSettings = BnkAdvSettingsParams.read(bytes);
    states = BnkStateChunk.read(bytes);
    rtpc = BnkInitialRTPC.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    fxParams.write(bytes);
    bytes.writeUint8(bOverrideAttachmentParams);
    bytes.writeUint32(overrideBusID);
    bytes.writeUint32(directParentID);
    bytes.writeUint8(byBitVector);
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
      1 +
      4 +
      4 +
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
