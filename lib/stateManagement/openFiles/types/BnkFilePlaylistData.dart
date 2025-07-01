
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../../../background/wemFilesIndexer.dart';
import '../../../fileTypeUtils/audio/audioModsMetadata.dart';
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../../fileTypeUtils/audio/riffParser.dart';
import '../../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../../utils/Disposable.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../audioResourceManager.dart';
import '../../events/statusInfo.dart';
import '../../hasUuid.dart';
import '../../listNotifier.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import '../openFilesManager.dart';
import 'xml/xmlProps/xmlProp.dart';

enum ClipAutomationType {
  volume(0, "Volume"),
  lpf(1, "Low Pass Filter"),
  hpf(2, "High Pass Filter"),
  fadeIn(3, "Fade In"),
  fadeOut(4, "Fade Out");

  final int value;
  final String name;
  const ClipAutomationType(this.value, this.name);
}
enum RtpcPointInterpolationType {
  log3(0, "Log (base 3)"),
  sin(1, "Sine (Constant Power Fade Out)"),
  log1(2, "Log (base 1.41)"),
  invSCurve(3, "Inverted S-Curve"),
  linear(4, "Linear"),
  sCurve(5, "S-Curve"),
  exp1(6, "Exp (base 1.41)"),
  sinRecip(7, "Sine (Constant Power Fade In)"),
  exp3(8, "Exp (base 3)"),
  constant(9, "Constant");

  final int value;
  final String name;
  const RtpcPointInterpolationType(this.value, this.name);
}
class BnkClipRtpcPoint with HasUuid, Undoable implements Disposable {
  final OpenFileId file;
  final BnkRtpcGraphPoint srcAutomation;
  late final NumberProp x;
  late final NumberProp y;
  final int interpolationType;
  BnkClipRtpcPoint(this.file, this.srcAutomation, this.x, this.y, this.interpolationType) {
    _setupListeners();
  }
  BnkClipRtpcPoint.fromAutomation(this.file, this.srcAutomation) :
    x = NumberProp(srcAutomation.to * 1000, false, fileId: file),
    y = NumberProp(srcAutomation.from, false, fileId: file),
    interpolationType = srcAutomation.interpolation {
    _setupListeners();
  }

  void _setupListeners() {
    x.addListener(_onPropChanged);
    y.addListener(_onPropChanged);
  }
  void _onPropChanged() {
    areasManager.fromId(file)!.setHasUnsavedChanges(true);
  }

  @override
  void dispose() {
    x.dispose();
    y.dispose();
  }

  void applyTo(BnkRtpcGraphPoint point) {
    point.to = x.value.toDouble();
    point.from = y.value.toDouble();
  }

  BnkClipRtpcPoint duplicate() {
    return BnkClipRtpcPoint(
        file,
        srcAutomation,
        x.takeSnapshot() as NumberProp,
        y.takeSnapshot() as NumberProp,
        interpolationType
    );
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkClipRtpcPoint(
        file,
        srcAutomation,
        x.takeSnapshot() as NumberProp,
        y.takeSnapshot() as NumberProp,
        interpolationType
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkClipRtpcPoint;
    x.value = content.x.value;
    y.value = content.y.value;
  }
}
class BnkTrackClip with HasUuid, Undoable implements Disposable {
  final OpenFileId fileId;
  final BnkPlaylist srcPlaylist;
  final int sourceId;
  final NumberProp xOff;
  final NumberProp beginTrim;
  final NumberProp endTrim;
  final NumberProp srcDuration;
  late final XmlProp combinedProps;
  final Map<int, List<BnkClipRtpcPoint>> rtpcPoints;
  AudioResource? resource;
  BnkTrackClip(this.fileId, this.srcPlaylist, this.sourceId, this.xOff, this.beginTrim, this.endTrim, this.srcDuration, this.rtpcPoints) {
    _initCombinedProps();
    _setupListeners();
  }
  BnkTrackClip.fromPlaylist(this.fileId, this.srcPlaylist, List<BnkClipAutomation> automations) :
        sourceId = srcPlaylist.sourceID,
        xOff = NumberProp(srcPlaylist.fPlayAt, false, fileId: fileId),
        beginTrim = NumberProp(srcPlaylist.fBeginTrimOffset, false, fileId: fileId),
        endTrim = NumberProp(srcPlaylist.fEndTrimOffset, false, fileId: fileId),
        srcDuration = NumberProp(srcPlaylist.fSrcDuration, false, fileId: fileId),
        rtpcPoints = {} {
    for (var automation in automations) {
      var type = automation.eAutoType;
      if (!rtpcPoints.containsKey(type))
        rtpcPoints[type] = [];
      for (var point in automation.rtpcGraphPoint) {
        rtpcPoints[type]!.add(BnkClipRtpcPoint.fromAutomation(fileId, point));
      }
    }
    _initCombinedProps();
    _setupListeners();
  }

  void _initCombinedProps() {
    combinedProps = XmlProp(
        file: null,
        tagId: 0,
        tagName: "Clip",
        parentTags: [],
        children: [
          Tuple2("Offset", xOff),
          Tuple2("Begin trim", beginTrim),
          Tuple2("End trim", endTrim),
          Tuple2("Duration", srcDuration),
        ].map((v) => XmlProp(
          file: null,
          tagId: 0,
          tagName: v.item1,
          parentTags: [],
          value: v.item2,
        )).toList()
    );
    combinedProps.overrideUuid(uuid);
  }

  void _setupListeners() {
    xOff.addListener(_onPropChanged);
    beginTrim.addListener(_onPropChanged);
    endTrim.addListener(_onPropChanged);
    srcDuration.addListener(_onPropChanged);
  }
  void _onPropChanged() {
    areasManager.fromId(fileId)!.setHasUnsavedChanges(true);
  }

  @override
  void dispose() {
    // xOff.dispose();
    // beginTrim.dispose();
    // endTrim.dispose();
    // srcDuration.dispose();
    combinedProps.dispose();
    resource?.dispose();
    resource = null;
    for (var points in rtpcPoints.values) {
      for (var point in points) {
        point.dispose();
      }
    }
  }

  void applyTo(BnkPlaylist newPlaylist) {
    newPlaylist.fPlayAt = xOff.value.toDouble();
    newPlaylist.fBeginTrimOffset = beginTrim.value.toDouble();
    newPlaylist.fEndTrimOffset = endTrim.value.toDouble();
    newPlaylist.fSrcDuration = srcDuration.value.toDouble();
  }

  BnkPlaylist makeNewSrcPl() {
    return BnkPlaylist(
      srcPlaylist.trackID,
      sourceId,
      0,
      xOff.value.toDouble(),
      beginTrim.value.toDouble(),
      endTrim.value.toDouble(),
      srcDuration.value.toDouble(),
    );
  }

  BnkTrackClip duplicate() {
    return BnkTrackClip(
        fileId,
        makeNewSrcPl(),
        sourceId,
        xOff.takeSnapshot() as NumberProp,
        beginTrim.takeSnapshot() as NumberProp,
        endTrim.takeSnapshot() as NumberProp,
        srcDuration.takeSnapshot() as NumberProp,
        rtpcPoints.map((key, value) => MapEntry(key, value.map((e) => e.duplicate()).toList()))
    );
  }

  BnkTrackClip cutAt(double time) {
    if (time < 0 || time > srcDuration.value)
      throw Exception("Invalid time");
    var newClip = duplicate();
    endTrim.value = srcDuration.value - time;
    newClip.beginTrim.value = time;
    return newClip;
  }

  void clearRtpcPoints() {
    rtpcPoints.clear();
    _onPropChanged();
    areasManager.onFileIdUndoEvent(fileId);
  }

  Future<void> loadResource() async {
    var wemPath = wemFilesLookup.lookup[sourceId];
    if (wemPath == null) {
      var fileData = areasManager.fromId(fileId);
      if (fileData == null || fileData is! BnkFilePlaylistData)
        return;
      var bnkPath = fileData.path;
      wemPath = await wemFilesLookup.lookupWithAdditionalDir(sourceId, dirname(bnkPath));
      if (wemPath == null)
        return;
    }
    resource = await audioResourcesManager.getAudioResource(wemPath);
    areasManager.onFileIdUndoEvent(fileId);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkTrackClip(
        fileId,
        srcPlaylist,
        sourceId,
        xOff.takeSnapshot() as NumberProp,
        beginTrim.takeSnapshot() as NumberProp,
        endTrim.takeSnapshot() as NumberProp,
        srcDuration.takeSnapshot() as NumberProp,
        rtpcPoints.map((key, value) => MapEntry(key, value.map((e) => e.takeSnapshot() as BnkClipRtpcPoint).toList()))
    );
    snapshot.resource = resource?.newRef();
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkTrackClip;
    xOff.restoreWith(content.xOff);
    beginTrim.restoreWith(content.beginTrim);
    endTrim.restoreWith(content.endTrim);
    srcDuration.restoreWith(content.srcDuration);

    // remove and dispose all current points and replace with new ones
    for (var points in rtpcPoints.values) {
      for (var point in points)
        point.dispose();
    }
    rtpcPoints.clear();
    for (var key in content.rtpcPoints.keys) {
      rtpcPoints[key] = [];
      for (var point in content.rtpcPoints[key]!)
        rtpcPoints[key]!.add(point.duplicate());
    }
  }
}
class BnkTrackData with HasUuid, Undoable implements Disposable {
  final OpenFileId fileId;
  final BnkMusicTrack srcTrack;
  final ValueListNotifier<BnkTrackClip> clips;
  final ValueNotifier<bool> hasSourceChanged = ValueNotifier(false);
  BnkTrackData(this.fileId, this.srcTrack, this.clips) {
    _setupListeners();
  }
  BnkTrackData.fromTrack(this.fileId, this.srcTrack) :
    clips = ValueListNotifier(
      List.generate(srcTrack.playlists.length, (i) => BnkTrackClip.fromPlaylist(
        fileId,
        srcTrack.playlists[i],
        srcTrack.clipAutomations.where((ca) => ca.uClipIndex == i).toList()
      )),
      fileId: fileId
    ) {
    _setupListeners();
  }

  void _setupListeners() {
    clips.addListener(_onPropChanged);
  }
  void _onPropChanged() {
    var file = areasManager.fromId(fileId);
    file!.setHasUnsavedChanges(true);
    file.onUndoableEvent();
  }

  @override
  void dispose() {
    clips.dispose();
    hasSourceChanged.dispose();
  }

  void applyTo(BnkMusicTrack newTrack, AudioModsMetadata? metadata) {
    if (metadata != null)
      metadata.moddedBnkChunks[newTrack.uid] = AudioModChunkInfo(newTrack.uid);
    int minLen = min(clips.length, newTrack.playlists.length);
    // common
    for (var i = 0; i < minLen; i++)
      clips[i].applyTo(newTrack.playlists[i]);
    // newly added
    for (var i = minLen; i < clips.length; i++) {
      var newPlaylist = clips[i].makeNewSrcPl();
      newTrack.playlists.add(newPlaylist);
    }
    // removed
    newTrack.playlists.removeRange(minLen, newTrack.playlists.length);

    newTrack.numPlaylistItem = clips.length;

    // rebuild clip automation (assuming no changes, not supported yet)
    List<BnkClipAutomation> newAutomations = [];
    for (int i = 0; i < clips.length; i++) {
      var clip = clips[i];
      for (var rtpc in clip.rtpcPoints.entries) {
        var type = rtpc.key;
        var points = rtpc.value;
        var newAutomation = BnkClipAutomation(
          i,
          type,
          points.length,
          points.map((p) => p.srcAutomation).toList(),
        );
        newAutomations.add(newAutomation);
      }
    }
    // sort by clip index (asc), then by type (desc)
    newAutomations.sort((a, b) {
      if (a.uClipIndex != b.uClipIndex)
        return a.uClipIndex.compareTo(b.uClipIndex);
      return b.eAutoType.compareTo(a.eAutoType);
    });
    newTrack.clipAutomations = newAutomations;
    newTrack.numClipAutomationItem = newAutomations.length;

    // update chunk size
    newTrack.size = newTrack.calculateSize() + 4;
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkTrackData(
      fileId,
      srcTrack,
      clips.takeSnapshot() as ValueListNotifier<BnkTrackClip>,
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkTrackData;
    clips.restoreWith(content.clips);
  }

  Future<void> updateDuration() async {
    if (srcTrack.sources.isEmpty)
      return;
    if (!srcTrack.sources.every((s) => s.sourceID == srcTrack.sources.first.sourceID))
      throw Exception("Can't update duration of a track with multiple sources");
    var srcId = srcTrack.sources.first.sourceID;
    var wemPath = wemFilesLookup.lookup[srcId];
    if (wemPath == null) {
      var fileData = areasManager.fromId(fileId);
      if (fileData == null || fileData is! BnkFilePlaylistData)
        return;
      var bnkPath = fileData.path;
      var sourceId = srcTrack.sources.firstOrNull?.sourceID;
      if (sourceId != null)
        wemPath = await wemFilesLookup.lookupWithAdditionalDir(sourceId, dirname(bnkPath));
      if (wemPath == null)
        return;
    }
    var wemBytes = await ByteDataWrapper.fromFile(wemPath);
    var wemRiff = RiffFile.fromBytes(wemBytes);
    var riffFormat = wemRiff.format;
    double duration;
    if (riffFormat is WemFormatChunk) {
      duration = riffFormat.numSamples / riffFormat.samplesPerSec;
    } else {
      duration = wemRiff.data.size / riffFormat.avgBytesPerSec;
    }
    for (var clip in clips) {
      var newDuration = duration * 1000;
      if (newDuration == clip.srcDuration.value)
        continue;
      clip.srcDuration.value = newDuration;
      if (clip.beginTrim.value > clip.srcDuration.value + clip.endTrim.value) {
        clip.beginTrim.value = 0;
        messageLog.add("Warning: Set clip begin to 0 on ${basename(wemPath)}");
      }
      if (clip.srcDuration.value + clip.endTrim.value < clip.beginTrim.value) {
        clip.endTrim.value = 0;
        messageLog.add("Warning: Set clip end to 0 on ${basename(wemPath)}");
      }
      hasSourceChanged.value = true;
    }
  }
}
enum BnkMarkerRole {
  entryCue("Entry"), exitCue("Exit"), custom("Custom");

  final String name;

  const BnkMarkerRole(this.name);
}
class BnkSegmentMarker with HasUuid, Undoable implements Disposable {
  final OpenFileId file;
  final BnkMusicMarker srcMarker;
  final NumberProp pos;
  late final XmlProp posSelectable;
  final BnkMarkerRole role;
  String get name => srcMarker.pMarkerName ?? "";
  BnkSegmentMarker(this.file, this.srcMarker, this.pos, this.role) {
    _setupListeners();
  }
  BnkSegmentMarker.fromMarker(this.file, this.srcMarker, List<BnkMusicMarker> markers) :
    pos = NumberProp(srcMarker.fPosition, false, fileId: file),
    role = markers.first == srcMarker
        ? BnkMarkerRole.entryCue
        : markers.last == srcMarker
        ? BnkMarkerRole.exitCue
        : BnkMarkerRole.custom {
    _setupListeners();
  }

  void _setupListeners() {
    pos.addListener(_onPropChanged);
    posSelectable = XmlProp(file: file, tagId: 0, tagName: "${role.name} cue marker", parentTags: [], children: [
      XmlProp(file: file, tagId: 0, tagName: "time", value: pos, parentTags: [])
    ]);
  }
  void _onPropChanged() {
    areasManager.fromId(file)!.setHasUnsavedChanges(true);
  }

  @override
  void dispose() {
    posSelectable.dispose();
  }

  void applyTo(BnkMusicMarker newMarker) {
    newMarker.fPosition = pos.value.toDouble();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkSegmentMarker(file, srcMarker, pos.takeSnapshot() as NumberProp, role);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkSegmentMarker;
    pos.restoreWith(content.pos);
  }
}
class BnkSegmentData with HasUuid, Undoable implements Disposable {
  final OpenFileId file;
  final BnkMusicSegment srcSegment;
  final NumberProp duration;
  final List<BnkTrackData> tracks;
  final List<BnkSegmentMarker> markers;
  BnkSegmentData(this.file, this.srcSegment, this.duration, this.tracks, this.markers) {
    _setupListeners();
  }
  BnkSegmentData.fromSegment(this.file, this.srcSegment, Map<int, BnkHircChunkBase> hircMap) :
        duration = NumberProp(srcSegment.fDuration, false, fileId: file),
        tracks = srcSegment.musicParams.childrenList.ulChildIDs.map((id) =>
            BnkTrackData.fromTrack(file, hircMap[id] as BnkMusicTrack)).toList(),
        markers = srcSegment.wwiseMarkers.map((m) => BnkSegmentMarker.fromMarker(file, m, srcSegment.wwiseMarkers)).toList() {
    _setupListeners();
  }

  void _setupListeners() {
    duration.addListener(_onPropChanged);
  }
  void _onPropChanged() {
    areasManager.fromId(file)!.setHasUnsavedChanges(true);
  }

  @override
  void dispose() {
    duration.dispose();
    for (var t in tracks)
      t.dispose();
    for (var m in markers)
      m.dispose();
  }

  void applyTo(BnkMusicSegment newSegment, Map<int, BnkHircChunkBase> hircMap, AudioModsMetadata? metadata) {
    if (markers.length != srcSegment.wwiseMarkers.length)
      throw Exception("Cannot apply segment with different number of markers");
    if (tracks.length != srcSegment.musicParams.childrenList.ulChildIDs.length)
      throw Exception("Cannot apply segment with different number of tracks");
    if (metadata != null)
      metadata.moddedBnkChunks[newSegment.uid] = AudioModChunkInfo(newSegment.uid);
    if (markers.length >= 2) {
      // var minMarkerPos = markers.map((m) => m.pos.value).reduce(min);
      // var maxMarkerPos = markers.map((m) => m.pos.value).reduce(max);
      // newSegment.fDuration = maxMarkerPos - minMarkerPos.toDouble();
      // newSegment.fDuration = maxMarkerPos.toDouble();
      var maxTrackEndTime = tracks.map(
        (t) => t.clips
          .map((c) => c.xOff.value + c.srcDuration.value + c.endTrim.value)
          .fold(0, max)
      ).reduce(max);
      newSegment.fDuration = maxTrackEndTime.toDouble();
    }
    for (var i = 0; i < markers.length; i++) {
      var newMarker = newSegment.wwiseMarkers[i];
      markers[i].applyTo(newMarker);
    }
    for (var i = 0; i < tracks.length; i++) {
      var newTrack = hircMap[srcSegment.musicParams.childrenList.ulChildIDs[i]] as BnkMusicTrack;
      tracks[i].applyTo(newTrack, metadata);
    }
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkSegmentData(
        file,
        srcSegment,
        duration.takeSnapshot() as NumberProp,
        tracks.map((t) => t.takeSnapshot() as BnkTrackData).toList(),
        markers.map((m) => m.takeSnapshot() as BnkSegmentMarker).toList()
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkSegmentData;
    duration.restoreWith(content.duration);
    for (var i = 0; i < tracks.length; i++)
      tracks[i].restoreWith(content.tracks[i]);
    for (var i = 0; i < markers.length; i++)
      markers[i].restoreWith(content.markers[i]);
  }
}
enum BnkPlaylistChildResetType {
  none(-1, "None"),
  continuousSequence(0, "Continuous Sequence"),
  randomSequence(1, "Step Sequence"),
  continuousRandom(2, "Continuous Random"),
  stepRandom(3, "Step Random");
  final int value;
  final String name;
  const BnkPlaylistChildResetType(this.value, this.name);
  static BnkPlaylistChildResetType fromValue(int value) {
    for (var t in values)
      if (t.value == value)
        return t;
    return none;
  }
}
class BnkPlaylistChild with HasUuid, Undoable implements Disposable {
  final OpenFileId file;
  final BnkPlaylistItem srcItem;
  final int index;
  final List<BnkPlaylistChild> children;
  final BnkSegmentData? segment;
  final String loops;
  final BnkPlaylistChildResetType resetType;
  final List<int> appliesTo;  // playlist IDs
  BnkPlaylistChild(this.file, this.srcItem, this.index, this.children, this.segment, this.loops, this.resetType)
      : appliesTo = [];
  BnkPlaylistChild.fromPlaylistItem(this.file, this.srcItem, this.index, Map<int, BnkHircChunkBase> hircMap) :
        children = [],
        segment = srcItem.segmentId != 0 ? BnkSegmentData.fromSegment(file, hircMap[srcItem.segmentId] as BnkMusicSegment, hircMap) : null,
        loops = srcItem.loop == 0 ? "Infinite" : srcItem.loop.toString(),
        resetType = BnkPlaylistChildResetType.fromValue(srcItem.eRSType),
        appliesTo = [srcItem.playlistItemId];

  List<BnkPlaylistItem> parseChildren(int curIndex, List<BnkPlaylistItem> remainingItems, Map<int, BnkHircChunkBase> hircMap, List<BnkPlaylistChild> parsedItems) {
    var remaining = remainingItems;
    remaining = remaining.sublist(1);
    curIndex++;
    for (int i = 0; i < srcItem.numChildren; i++) {
      var child = BnkPlaylistChild.fromPlaylistItem(file, remaining.first, curIndex, hircMap);
      int prevLength = remaining.length;
      remaining = child.parseChildren(curIndex, remaining, hircMap, parsedItems);
      curIndex += prevLength - remaining.length;
      children.add(child);
      parsedItems.add(child);
    }
    return remaining;
  }

  static BnkPlaylistChild parsePlaylist(OpenFileId file, BnkMusicPlaylist srcPlaylist, Map<int, BnkHircChunkBase> hircMap) {
    var root = BnkPlaylistChild.fromPlaylistItem(file, srcPlaylist.playlistItems.first, 0, hircMap);
    var remaining = root.parseChildren(0, srcPlaylist.playlistItems, hircMap, []);
    if (remaining.isNotEmpty)
      throw Exception("Failed to parse playlist");
    return root;
  }

  @override
  void dispose() {
    segment?.dispose();
    for (var c in children)
      c.dispose();
  }

  void applyTo(List<BnkPlaylistItem> newItems, Map<int, BnkHircChunkBase> hircMap, AudioModsMetadata? metadata) {
    var newItem = newItems[index];
    if (srcItem.playlistItemId != newItem.playlistItemId)
      throw Exception("Playlist item ID mismatch");
    if (children.length != newItem.numChildren)
      throw Exception("Number of children mismatch");
    if ((segment == null) != (newItem.segmentId == 0))
      throw Exception("Segment mismatch");
    if (segment != null) {
      var newSegment = hircMap[newItem.segmentId] as BnkMusicSegment;
      segment!.applyTo(newSegment, hircMap, metadata);
    }
    for (var i = 0; i < children.length; i++) {
      children[i].applyTo(newItems, hircMap, metadata);
    }
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkPlaylistChild(file, srcItem, index, children.map((c) => c.takeSnapshot() as BnkPlaylistChild).toList(), segment?.takeSnapshot() as BnkSegmentData?, loops, resetType);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkPlaylistChild;
    for (var i = 0; i < children.length; i++)
      children[i].restoreWith(content.children[i]);
    if (segment != null)
      segment!.restoreWith(content.segment!);
  }

  Future<void> updateTrackDurations() async {
    List<BnkPlaylistChild> pending = [this];
    List<Future<void>> futures = [];
    while (pending.isNotEmpty) {
      var child = pending.removeAt(0);
      pending.addAll(child.children);
      if (child.segment != null) {
        for (var track in child.segment!.tracks)
          futures.add(track.updateDuration());
      }
    }
    await Future.wait(futures);
  }
}
class BnkFilePlaylistData extends OpenFileData {
  final int playlistId;
  BnkMusicPlaylist? srcPlaylist;
  BnkPlaylistChild? rootChild;
  int? _bnkVersion;

  BnkFilePlaylistData(super.name, super.path, { super.secondaryName }) :
        playlistId = int.parse(RegExp(r"\.bnk#p=(\d+)$").firstMatch(name)!.group(1)!),
        super(type: FileType.bnkPlaylist, icon: Icons.queue_music) {
    canBeReloaded = false;
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var bytes = await ByteDataWrapper.fromFile(path.split("#").first);
    var bnk = BnkFile.read(bytes);
    _bnkVersion = bnk.chunks.whereType<BnkHeader>().firstOrNull?.version;
    var hircChunk = bnk.chunks.whereType<BnkHircChunk>().first;
    Map<int, BnkHircChunkBase> hircMap = {
      for (var hirc in hircChunk.chunks.whereType<BnkHircChunkBase>())
        hirc.uid: hirc
    };
    srcPlaylist = hircChunk.chunks
        .whereType<BnkMusicPlaylist>()
        .firstWhere((p) => p.uid == playlistId);
    rootChild = BnkPlaylistChild.parsePlaylist(uuid, srcPlaylist!, hircMap);
    await rootChild!.updateTrackDurations();

    await super.load();
  }

  @override
  Future<void> save() async {
    if (loadingState.value != LoadingState.loaded)
      return;

    var bnkPath = path.split("#").first;
    var useMetadata = basename(bnkPath) == "BGM.bnk" && _bnkVersion == 113;
    var metaDataPath = join(dirname(dirname(bnkPath)), audioModsMetadataFileName);
    if (useMetadata)
      await AudioModsMetadata.lock();
    try {
      var modsMetaData = useMetadata ? await AudioModsMetadata.fromFile(metaDataPath) : null;
      var bytes = await ByteDataWrapper.fromFile(bnkPath);
      var bnk = BnkFile.read(bytes);
      var hircChunk = bnk.chunks.whereType<BnkHircChunk>().first;
      Map<int, BnkHircChunkBase> hircMap = {
        for (var hirc in hircChunk.chunks.whereType<BnkHircChunkBase>())
          hirc.uid: hirc
      };
      var newPlaylist = hircMap[playlistId] as BnkMusicPlaylist;
      rootChild!.applyTo(newPlaylist.playlistItems, hircMap, modsMetaData);
      hircChunk.chunkSize = hircChunk.calculateSize() - 8;
      bytes = ByteDataWrapper.allocate(bnk.calculateSize());
      bnk.write(bytes);
      await backupFile(bnkPath);
      await bytes.save(bnkPath);
      await modsMetaData?.toFile(metaDataPath);
    } finally {
      if (useMetadata)
        AudioModsMetadata.unlock();
    }

    await super.save();
  }

  @override
  void dispose() {
    super.dispose();
    rootChild?.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkFilePlaylistData(name.value, path);
    snapshot.optionalInfo = optionalInfo;
    snapshot.rootChild = rootChild?.takeSnapshot() as BnkPlaylistChild?;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkFilePlaylistData;
    rootChild?.restoreWith(content.rootChild!);
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
  }
}
