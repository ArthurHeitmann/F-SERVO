
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/listNotifier.dart';
import '../../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../../stateManagement/openFiles/types/BnkFilePlaylistData.dart';
import '../../../../stateManagement/preferencesData.dart';
import '../../../misc/mousePosition.dart';
import 'audioSequenceController.dart';

class AudioEditorData extends InheritedWidget {
  final ValueNotifier<double> msPerPix;
  final ValueNotifier<double> xOff;
  final ValueListNotifier<String> selectedClipUuids;
  final BnkTrackClip? Function(String uuid) getClipByUuid;

  const AudioEditorData({
    super.key,
    required super.child,
    required this.msPerPix,
    required this.xOff,
    required this.selectedClipUuids,
    required this.getClipByUuid,
  });

  @override
  bool updateShouldNotify(AudioEditorData oldWidget) {
    return msPerPix != oldWidget.msPerPix || xOff != oldWidget.xOff || selectedClipUuids != oldWidget.selectedClipUuids;
  }

  static AudioEditorData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AudioEditorData>()!;
  }
}

class SnapPoint {
  final double Function() getPos;
  final Object? owner;
  
  const SnapPoint(this.getPos, [this.owner]);
  SnapPoint.prop(NumberProp prop) : this(() => prop.value.toDouble(), prop);
  SnapPoint.valueNotifier(ValueNotifier<double> prop) : this(() => prop.value, prop);
  SnapPoint.value(double value) : this(() => value);
}

class SnapPointsData extends InheritedWidget {
  final List<SnapPoint> staticSnapPoints;
  final Iterable<SnapPoint> Function() dynamicSnapPoints;

  const SnapPointsData({
    super.key,
    required super.child,
    required this.staticSnapPoints,
    required this.dynamicSnapPoints,
  });

  @override
  bool updateShouldNotify(SnapPointsData oldWidget) {
    return staticSnapPoints != oldWidget.staticSnapPoints || dynamicSnapPoints != oldWidget.dynamicSnapPoints;
  }

  static SnapPointsData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SnapPointsData>()!;
  }

  Iterable<SnapPoint> getAllSnapPoints() sync* {
    yield* staticSnapPoints;
    yield* dynamicSnapPoints();
  }

  double trySnapTo(double valMs, List<Object> owners, double msPerPix) {
    const snapThresholdPx = 8;
    var curPx = valMs / msPerPix;
    for (var snapPoint in getAllSnapPoints()) {
      if (owners.contains(snapPoint.owner))
        continue;
      var snapPx = snapPoint.getPos() / msPerPix;
      if ((snapPx - curPx).abs() < snapThresholdPx)
        return snapPoint.getPos();
    }
    return valMs;
  }

  SnapPoint? tryFindSnapPoint(double valMs, List<Object> owners, double msPerPix) {
    const snapThresholdPx = 8;
    var curPx = valMs / msPerPix;
    for (var snapPoint in getAllSnapPoints()) {
      if (owners.contains(snapPoint.owner))
        continue;
      var snapPx = snapPoint.getPos() / msPerPix;
      if ((snapPx - curPx).abs() < snapThresholdPx)
        return snapPoint;
    }
    return null;
  }
}

class PlaybackMarker {
  final ValueNotifier<String?> segmentUuid;
  final ValueNotifier<double> pos;

  const PlaybackMarker(this.segmentUuid, this.pos);
}
class CurrentPlaybackItem {
  final PlaybackController playbackController;
  final void Function() onCancel;

  const CurrentPlaybackItem(this.playbackController, this.onCancel);
}
class AudioPlaybackScope extends InheritedWidget {
  final CurrentPlaybackItem? currentPlaybackItem;
  final void Function(CurrentPlaybackItem? item) setCurrentPlaybackItem;
  final PlaybackMarker playbackMarker;

  const AudioPlaybackScope({
    super.key, 
    required super.child,
    required this.currentPlaybackItem,
    required this.setCurrentPlaybackItem,
    required this.playbackMarker,
  });

  void cancelCurrentPlayback() {
    currentPlaybackItem?.onCancel();
    setCurrentPlaybackItem(null);
    playbackMarker.segmentUuid.value = null;
  }

  @override
  bool updateShouldNotify(AudioPlaybackScope oldWidget) {
    return currentPlaybackItem != oldWidget.currentPlaybackItem;
  }

  static AudioPlaybackScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AudioPlaybackScope>()!;
  }
}

mixin AudioPlayingWidget<T extends StatefulWidget> on State<T> {
  CurrentPlaybackItem? currentPlaybackItem;
  final List<Listenable> _prevCurrentFileListeners = [];
  late final PreferencesData prefs;

  @override
  void initState() {
    super.initState();
    prefs = PreferencesData();
    areasManager.areas.addListener(_onAreasChange);
    _onAreasChange();
  }

  void onDispose() {
    areasManager.areas.removeListener(_onAreasChange);
    for (var prevListener in _prevCurrentFileListeners)
      prevListener.removeListener(_onCurrentFileChange);
    if (currentPlaybackItem == null)
      return;
    onCancel(true);
  }

  void _onAreasChange() {
    for (var prevListener in _prevCurrentFileListeners)
      prevListener.removeListener(_onCurrentFileChange);
    _prevCurrentFileListeners.clear();
    for (var area in areasManager.areas) {
      area.currentFile.addListener(_onCurrentFileChange);
      _prevCurrentFileListeners.add(area.currentFile);
    }
  }

  void _onCurrentFileChange() {
    if (currentPlaybackItem == null)
      return;
    if (!currentPlaybackItem!.playbackController.isPlaying)
      return;
    if (prefs.pauseAudioOnFileChange?.value != true)
      return;
    if (areasManager.areas.any((area) => area.currentFile.value?.uuid == fileId))
      return;
    currentPlaybackItem?.playbackController.pause();
  }

  void onCancel([bool isDisposed = false]) {
    if (currentPlaybackItem == null)
      return;
    currentPlaybackItem!.playbackController.dispose();
    currentPlaybackItem = null;
    if (mounted && !isDisposed)
      setState(() {});
  }

  PlaybackController makePlaybackController();
  OpenFileId get fileId;

  void togglePlayback() {
    var audioPlaybackScope = AudioPlaybackScope.of(context);
    if (currentPlaybackItem == null) {
      audioPlaybackScope.cancelCurrentPlayback();
      var playbackController = makePlaybackController();
      audioPlaybackScope.playbackMarker.pos.value = 0;
      playbackController.positionStream.listen(_onPositionChange);
      currentPlaybackItem = CurrentPlaybackItem(playbackController, onCancel);
      audioPlaybackScope.setCurrentPlaybackItem(currentPlaybackItem);
    }

    if (currentPlaybackItem!.playbackController.isPlaying)
      currentPlaybackItem!.playbackController.pause();
    else
      currentPlaybackItem!.playbackController.play();
  }

  void onSegmentChange(String segmentUuid) {
    if (!mounted)
      return;
    var audioPlaybackScope = AudioPlaybackScope.of(context);
    audioPlaybackScope.playbackMarker.segmentUuid.value = segmentUuid;
  }

  void _onPositionChange(double pos) {
    if (!mounted)
      return;
    var audioPlaybackScope = AudioPlaybackScope.of(context);
    audioPlaybackScope.playbackMarker.pos.value = pos;
  }

  bool onKey(KeyEvent event) {
    if (currentPlaybackItem == null)
      return false;
    if (event is! KeyDownEvent)
      return false;
    if (event.logicalKey != LogicalKeyboardKey.space)
      return false;
    if (fileId != areasManager.activeArea.value?.currentFile.value?.uuid)
      return false;

    togglePlayback();
    return true;
  }
}

double getMousePosOnTrack(ValueNotifier<double> xOff, ValueNotifier<double> msPerPix, BuildContext context) {
  var renderBox = context.findRenderObject() as RenderBox;
  var locMousePos = renderBox.globalToLocal(MousePosition.pos).dx;
  var xOffDist = locMousePos - xOff.value;
  return xOffDist * msPerPix.value;
}
