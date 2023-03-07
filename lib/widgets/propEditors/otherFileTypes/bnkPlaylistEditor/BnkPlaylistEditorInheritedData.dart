
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/listNotifier.dart';
import '../../../../stateManagement/openFileTypes.dart';
import '../../../../stateManagement/openFilesManager.dart';
import '../../../misc/mousePosition.dart';
import 'audioSequenceController.dart';

class AudioEditorData extends InheritedWidget {
  final ValueNotifier<double> msPerPix;
  final ValueNotifier<double> xOff;
  final ValueListNotifier<String> selectedClipUuids;
  final BnkTrackClip? Function(String uuid) getClipByUuid;

  const AudioEditorData({
    super.key,
    required Widget child,
    required this.msPerPix,
    required this.xOff,
    required this.selectedClipUuids,
    required this.getClipByUuid,
  }) : super(child: child);

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
    required Widget child,
    required this.staticSnapPoints,
    required this.dynamicSnapPoints,
  }) : super(child: child);

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
    required Widget child,
    required this.currentPlaybackItem,
    required this.setCurrentPlaybackItem,
    required this.playbackMarker,
  }) :
    super(child: child);

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

  void onDispose() {
    if (currentPlaybackItem == null)
      return;
    onCancel(true);
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
    if (fileId != areasManager.activeArea?.currentFile?.uuid)
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
