
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

import '../../../../background/wemFilesIndexer.dart';
import '../../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../../../keyboardEvents/intents.dart';
import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../../stateManagement/openFiles/types/BnkFilePlaylistData.dart';
import '../../../../utils/utils.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../misc/Selectable.dart';
import '../../../misc/contextMenuBuilder.dart';
import '../../../misc/mousePosition.dart';
import '../../../misc/nestedContextMenu.dart';
import '../../../misc/onHoverBuilder.dart';
import '../../../theme/customTheme.dart';
import 'BnkPlaylistEditorInheritedData.dart';
import 'audioSequenceController.dart';

class BnkTrackEditor extends ChangeNotifierWidget {
  final String segmentUuid;
  final BnkTrackData track;
  final AudioEditorData viewData;

  BnkTrackEditor({ super.key, required this.segmentUuid, required this.track, required this.viewData })
    : super(notifiers: [
      viewData.msPerPix,
      viewData.xOff,
      viewData.selectedClipUuids,
      track.clips,
    ]
  );

  @override
  State<BnkTrackEditor> createState() => _BnkTrackEditorState();
}

class _BnkTrackEditorState extends ChangeNotifierState<BnkTrackEditor> with AudioPlayingWidget {
  double? dragStartPos;
  Map<String, double>? initialXOff;
  @override
  OpenFileId get fileId => widget.track.fileId;

  @override
  void initState() {
    HardwareKeyboard.instance.addHandler(onKey);
    Future.wait(widget.track.clips.map((c) => c.loadResource()))
      .then((_) {
        if (mounted)
          setState(() {});
      });
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(onKey);
    onDispose();
    super.dispose();
  }

  @override
  PlaybackController makePlaybackController() {
    var audioPlaybackScope = AudioPlaybackScope.of(context);
    var playbackController = BnkTrackPlaybackController(widget.track);
    audioPlaybackScope.playbackMarker.segmentUuid.value = widget.segmentUuid;
    return playbackController;
  }

  @override
  Widget build(BuildContext context) {
    var viewData = AudioEditorData.of(context);
    return SizedBox(
      height: 60,
      child: GestureDetector(
        onTap: () => setState(() {
          viewData.selectedClipUuids.clear();
          selectable.deselectFile(widget.track.fileId);
        }),
        behavior: HitTestBehavior.translucent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                for (int i = 0; i < widget.track.clips.length; i++)
                  ..._makeClipWidgets(
                    i,
                    widget.track.clips[i],
                    viewData,
                    constraints.maxWidth,
                  ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: Center(
                      child: OnHoverBuilder(
                        builder: (context, isHovering) => AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isHovering ? 1 : 0.25,
                          child: StreamBuilder(
                            key: ValueKey(currentPlaybackItem),
                            stream: currentPlaybackItem?.playbackController.isPlayingStream,
                            builder: (context, snapshot) {
                              return IconButton(
                                icon: currentPlaybackItem?.playbackController.isPlaying == true
                                  ? const Icon(Icons.pause)
                                  : const Icon(Icons.play_arrow),
                                splashRadius: 20,
                                onPressed: togglePlayback,
                              );
                            }
                          ),
                        ),
                      )
                    ),
                  )
                ),
              ],
            );
          }
        ),
      )
    );
  }

  List<Widget> _makeClipWidgets(int i, BnkTrackClip clip, AudioEditorData viewData, double viewWidth) {
    var srcId = widget.track.srcTrack.sources.first.sourceID;
    return [
      // left trimmed off area
      if (widget.track.clips.isNotEmpty && clip == widget.track.clips.first)
        ChangeNotifierBuilder(
          key: Key("${clip.uuid}_left"),
          notifiers: _getClipNotifiers(clip),
          builder: (context) {
            return Positioned(
              left: (clip.xOff.value) / viewData.msPerPix.value + viewData.xOff.value,
              width: (clip.beginTrim.value) / viewData.msPerPix.value,
              height: 60,
              child: Container(
                color: getTheme(context).audioDisabledColor,
              ),
            );
          }
        ),
      // main clip
      ChangeNotifierBuilder(
        key: Key("${clip.uuid}_main"),
        notifiers: _getClipNotifiers(clip),
        builder: (context) {
          return Positioned(
            left: (clip.xOff.value + clip.beginTrim.value) / viewData.msPerPix.value + viewData.xOff.value,
            width: (clip.srcDuration.value - clip.beginTrim.value + clip.endTrim.value) / viewData.msPerPix.value,
            height: 60,
            child: NestedContextMenu(
              buttons: _getClipContextMenuButtons(clip, viewData),
              child: GestureDetector(
                onTap: () => _selectClip(clip),
                onHorizontalDragStart: (_) {
                  dragStartPos = MousePosition.pos.dx;
                  initialXOff = {
                    for (var id in viewData.selectedClipUuids)
                      id: viewData.getClipByUuid(id)!.xOff.value.toDouble(),
                  };
                },
                onHorizontalDragEnd: (_) => dragStartPos = null,
                onHorizontalDragUpdate: viewData.selectedClipUuids.contains(clip.uuid)
                  ? (details) => _moveSelectedClips(details, clip)
                  : null,
                child: Stack(
                  children: [
                    // main clip
                    Positioned.fill(
                      child: CustomPaint(
                        foregroundPainter: _ClipRtpcPainter(
                          rtpcPoints: clip.rtpcPoints,
                          msPerPix: viewData.msPerPix.value,
                        ),
                        child: CustomPaint(
                          foregroundPainter: clip.resource?.previewSamples != null ? _ClipWaveformPainter(
                            clip: clip,
                            viewData: viewData,
                            lineColor: getTheme(context).editorBackgroundColor!.withOpacity(0.333),
                            viewWidth: viewWidth,
                          ) : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: getTheme(context).audioColor,
                              border: Border.all(
                                color: viewData.selectedClipUuids.contains(clip.uuid) ? getTheme(context).textColor! : Colors.transparent,
                                width: 1
                              ),
                            ),
                          ),
                        ),
                      )
                    ),
                    // left trim handle
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 5,
                      child: OnHoverBuilder(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        builder: (cxt, isHovering) => GestureDetector(
                          onHorizontalDragUpdate: (_) => _onBeginTrimDrag(clip),
                          child: Container(
                            color: isHovering ? getTheme(context).textColor!.withOpacity(0.5) : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    // right trim handle
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 5,
                      child: OnHoverBuilder(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        builder: (cxt, isHovering) => GestureDetector(
                          onHorizontalDragUpdate: (_) => _onEndTrimDrag(clip),
                          child: Container(
                            color: isHovering ? getTheme(context).textColor!.withOpacity(0.5) : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    // label
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 16,
                      child: Container(
                        color: getTheme(context).audioLabelColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "$srcId (${wemIdsToNames[srcId] ?? "..."})",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: getTheme(context).editorBackgroundColor,
                                    fontFamily: "FiraCode",
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
      // right trimmed off area
      if (widget.track.clips.isNotEmpty && clip == widget.track.clips.last)
        ChangeNotifierBuilder(
          key: Key("${clip.uuid}_right"),
          notifiers: _getClipNotifiers(clip),
          builder: (context) {
            return Positioned(
              left: (clip.xOff.value + clip.srcDuration.value + clip.endTrim.value) / viewData.msPerPix.value + viewData.xOff.value,
              width: (-clip.endTrim.value) / viewData.msPerPix.value,
              height: 60,
              child: Container(
                color: getTheme(context).audioDisabledColor,
              ),
            );
          }
        ),
    ];
  }

  List<ContextMenuConfig> _getClipContextMenuButtons(BnkTrackClip clip, AudioEditorData viewData) {
    return [
      ContextMenuConfig(
        label: "Duplicate",
        icon: const Icon(Icons.copy_all, size: 14),
        action: () => _duplicateClip(clip),
        shortcutLabel: "Ctrl+D"
      ),
      ContextMenuConfig(
        label: "Delete",
        icon: const Icon(Icons.delete, size: 14),
        action: () => _deleteClip(clip),
        shortcutLabel: "Del"
      ),
      ContextMenuConfig(
        label: "Copy offsets",
        icon: const Icon(Icons.copy, size: 16),
        action: () => _copyOffsets(clip),
        shortcutLabel: "Ctrl+C"
      ),
      ContextMenuConfig(
        label: "Paste offsets",
        icon: const Icon(Icons.paste, size: 16),
        action: () => _pasteOffsets(clip),
        shortcutLabel: "Ctrl+V"
      ),
      if (viewData.selectedClipUuids.length >= 2)
        ContextMenuConfig(
          label: "Trim start to other selection",
          icon: const Icon(Icons.cut, size: 16),
          action: () => _trimToOtherSelection(clip),
        ),
      if (clip.rtpcPoints.isNotEmpty)
        ContextMenuConfig(
          label: "Clear Graph Points",
          icon: const Icon(Icons.clear, size: 16),
          action: () => _clearRtpcPoints(clip),
        ),
      ContextMenuConfig(
        label: "Edit WEM",
        icon: const Icon(Icons.edit, size: 16),
        action: () => _replaceWem(clip),
      ),
      ContextMenuConfig(
        label: "Open WEM in explorer",
        icon: const Icon(Icons.folder_open, size: 16),
        action: () => _openWemInExplorer(clip),
      ),
    ];
  }

  List<Listenable> _getClipNotifiers(BnkTrackClip clip) {
    return [
      clip.xOff,
      clip.beginTrim,
      clip.endTrim,
    ];
  }

  void _copyOffsets(BnkTrackClip clip) {
    var data = {
      "beginTrim": clip.beginTrim.value,
      "endTrim": clip.endTrim.value,
      "xOff": clip.xOff.value,
    };
    copyToClipboard(jsonEncode(data));
  }

  void _pasteOffsets(BnkTrackClip clip) async {
    AudioPlaybackScope.of(context).cancelCurrentPlayback();
    var txt = await getClipboardText();
    if (txt == null) {
      showToast("Clipboard is empty");
      return;
    }
    var data = jsonDecode(txt) as Map<String, dynamic>;
    if (!data.containsKey("beginTrim") || !data.containsKey("endTrim") || !data.containsKey("xOff")) {
      showToast("Invalid data");
      return;
    }
    clip.beginTrim.value = data["beginTrim"];
    clip.endTrim.value = data["endTrim"];
    clip.xOff.value = data["xOff"];
  }

  void _trimToOtherSelection(BnkTrackClip clip) {
    var data = AudioEditorData.of(context);
    if (data.selectedClipUuids.length != 2) {
      showToast("Please select 2 clips");
      return;
    }
    var otherClipUuid = data.selectedClipUuids.firstWhere((element) => element != clip.uuid);
    var otherClip = data.getClipByUuid(otherClipUuid);
    if (otherClip == null) {
      showToast("Clip not found");
      return;
    }
    var prevBeginTrim = clip.beginTrim.value;
    clip.beginTrim.value = otherClip.srcDuration.value + otherClip.endTrim.value;
    var diff = clip.beginTrim.value - prevBeginTrim;
    clip.xOff.value -= diff;
    AudioPlaybackScope.of(context).cancelCurrentPlayback();
  }

  void _clearRtpcPoints(BnkTrackClip clip) {
    clip.clearRtpcPoints();
    setState(() {});
  }

  void _replaceWem(BnkTrackClip clip) async {
    var srcId = widget.track.srcTrack.sources.first.sourceID;
    var wemPath = wemFilesLookup.lookup[srcId];
    wemPath ??= clip.resource?.wemPath;
    if (wemPath == null) {
      showToast("WEM file not found");
      return;
    }
    areasManager.openFile(wemPath);
  }

  void _openWemInExplorer(BnkTrackClip clip) {
    var srcId = widget.track.srcTrack.sources.first.sourceID;
    var wemPath = wemFilesLookup.lookup[srcId];
    wemPath ??= clip.resource?.wemPath;
    if (wemPath == null) {
      showToast("WEM file not found");
      return;
    }
    revealFileInExplorer(wemPath);
  }

  void _selectClip(BnkTrackClip clip) {
    var viewData = AudioEditorData.of(context);
    if (isCtrlPressed() || isShiftPressed()) {
      if (viewData.selectedClipUuids.contains(clip.uuid)) {
        viewData.selectedClipUuids.remove(clip.uuid);
        selectable.deselect(clip.uuid);
      } else {
        viewData.selectedClipUuids.add(clip.uuid);
        selectable.select(clip.fileId, clip.combinedProps, (type) => onClipKeyEvent(type, clip));
      }
    } else {
      viewData.selectedClipUuids.clear();
      viewData.selectedClipUuids.add(clip.uuid);
      selectable.select(clip.fileId, clip.combinedProps, (type) => onClipKeyEvent(type, clip));
    }
  }

  void _moveSelectedClips(DragUpdateDetails details, BnkTrackClip clip) {
    var viewData = AudioEditorData.of(context);
    if (dragStartPos == null) {
      dragStartPos = MousePosition.pos.dx;
      return;
    }
    var change = (MousePosition.pos.dx - dragStartPos!) * viewData.msPerPix.value;
    for (var id in viewData.selectedClipUuids) {
      var clip = viewData.getClipByUuid(id)!;
      clip.xOff.value = (initialXOff![id]! + change).roundToDouble();
    }
    List<Tuple2<num, List<NumberProp>>> snapAnchors = [
      Tuple2(clip.xOff.value + clip.beginTrim.value, [clip.beginTrim, if (clip.beginTrim.value == 0) clip.xOff]),
      Tuple2(clip.xOff.value + clip.srcDuration.value + clip.endTrim.value, [clip.endTrim, if (clip.endTrim.value == 0) clip.srcDuration]),
      Tuple2(clip.xOff.value, [clip.xOff, if (clip.beginTrim.value == 0) clip.beginTrim]),
      Tuple2(clip.xOff.value + clip.srcDuration.value, [clip.srcDuration, if (clip.endTrim.value == 0) clip.endTrim]),
    ];
    var snapPoints = SnapPointsData.of(context);
    for (var anchor in snapAnchors) {
      var snap = snapPoints.tryFindSnapPoint(anchor.item1.toDouble(), anchor.item2, viewData.msPerPix.value);
      if (snap == null)
        continue;
      var snapVal = snap.getPos();
      var diff = snapVal - anchor.item1;
      for (var id in viewData.selectedClipUuids) {
        var clip = viewData.getClipByUuid(id)!;
        clip.xOff.value += diff;
      }
      break;
    }
    AudioPlaybackScope.of(context).cancelCurrentPlayback();
  }

  void _onBeginTrimDrag(BnkTrackClip clip) {
    var viewData = AudioEditorData.of(context);
    var newBeginTrim = getMousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
    newBeginTrim = SnapPointsData.of(context).trySnapTo(newBeginTrim, [clip.beginTrim], viewData.msPerPix.value);
    newBeginTrim -= clip.xOff.value;
    newBeginTrim = clamp(newBeginTrim, 0, clip.srcDuration.value - clip.endTrim.value.toDouble());
    clip.beginTrim.value = newBeginTrim;
    AudioPlaybackScope.of(context).cancelCurrentPlayback();
  }

  void _onEndTrimDrag(BnkTrackClip clip) {
    var viewData = AudioEditorData.of(context);
    var newEndTrim = getMousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
    newEndTrim = SnapPointsData.of(context).trySnapTo(newEndTrim, [clip.endTrim], viewData.msPerPix.value);
    newEndTrim = clip.xOff.value + clip.srcDuration.value - newEndTrim;
    newEndTrim = clamp(newEndTrim, 0, clip.srcDuration.value - clip.beginTrim.value.toDouble());
    clip.endTrim.value = -newEndTrim;
    AudioPlaybackScope.of(context).cancelCurrentPlayback();
  }

  void _duplicateClip(BnkTrackClip clip) {
    var newClip = clip.duplicate();
    newClip.xOff.value += clip.srcDuration.value - clip.beginTrim.value + clip.endTrim.value;
    newClip.loadResource().then((value) => setState(() {}));
    widget.track.clips.add(newClip);
    var viewData = AudioEditorData.of(context);
    viewData.selectedClipUuids.clear();
    viewData.selectedClipUuids.add(newClip.uuid);
    selectable.select(newClip.fileId, newClip.combinedProps, (type) => onClipKeyEvent(type, clip));
    AudioPlaybackScope.of(context).cancelCurrentPlayback();
  }

  void _deleteClip(BnkTrackClip clip) {
    var viewData = AudioEditorData.of(context);
    viewData.selectedClipUuids.remove(clip.uuid);
    selectable.deselect(clip.uuid);
    widget.track.clips.remove(clip);
    clip.dispose();
    AudioPlaybackScope.of(context).cancelCurrentPlayback();
  }

  void onClipKeyEvent(ChildKeyboardActionType actionType, BnkTrackClip clip) {
    switch (actionType) {
      case ChildKeyboardActionType.copy:
        _copyOffsets(clip);
        break;
      case ChildKeyboardActionType.cut:
        _copyOffsets(clip);
        _deleteClip(clip);
        break;
      case ChildKeyboardActionType.paste:
        _pasteOffsets(clip);
        break;
      case ChildKeyboardActionType.delete:
        _deleteClip(clip);
        break;
      case ChildKeyboardActionType.duplicate:
        _duplicateClip(clip);
        break;
      default:
    }
  }
}

class _ClipWaveformPainter extends CustomPainter {
  final BnkTrackClip clip;
  final AudioEditorData viewData;
  final Color lineColor;
  final double viewWidth;

  _ClipWaveformPainter({ required this.clip, required this.viewData, required this.lineColor, required this.viewWidth });

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    var viewXOff = viewData.xOff.value * viewData.msPerPix.value;
    var viewWidthMs = viewWidth * viewData.msPerPix.value;
    var viewStart = -viewXOff;
    var viewEnd = viewStart + viewWidthMs;
    var clipStart = clip.xOff.value + clip.beginTrim.value;
    var clipEnd = clip.xOff.value + clip.srcDuration.value + clip.endTrim.value;
    var clipStartVis = min(clipEnd, max(clipStart, viewStart));
    var clipEndVis = max(clipStart, min(clipEnd, viewEnd));
    var clipStartVisRelToTrack = clipStartVis - clip.xOff.value;
    var clipEndVisRelToTrack = clipEndVis - clip.xOff.value;
    var clipStartVisRelToSelf = clipStartVisRelToTrack - clip.beginTrim.value;
    var clipEndVisRelToSelf = clipEndVisRelToTrack - clip.beginTrim.value;
    var samplesIScale = 1 / clip.srcDuration.value * clip.resource!.previewSamples!.length;
    var startI = (clipStartVisRelToTrack * samplesIScale).round();
    startI = clamp(startI, 0, clip.resource!.previewSamples!.length - 1);
    var endI = (clipEndVisRelToTrack * samplesIScale).round();
    endI = clamp(endI, 0, clip.resource!.previewSamples!.length - 1);
    var startX = clipStartVisRelToSelf / viewData.msPerPix.value;
    var endX = clipEndVisRelToSelf / viewData.msPerPix.value;

    var samples = clip.resource!.previewSamples!.sublist(startI, endI);
    var height = size.height;
    var path = Path();
    var x = startX;
    var y = height / 2 - 8;
    var xStep = (endX - startX) / samples.length;
    var yStep = (height - 16) / 2;
    path.moveTo(x, y);
    for (var i = 0; i < samples.length; i++) {
      x += xStep;
      y = height / 2 - 8 - samples[i] * yStep;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ClipRtpcPainter extends CustomPainter {
  final Map<int, List<BnkClipRtpcPoint>> rtpcPoints;
  final double msPerPix;

  _ClipRtpcPainter({ required this.rtpcPoints, required this.msPerPix });

  @override
  void paint(Canvas canvas, Size size) {
    for (var rtpcType in rtpcPoints.keys) {
      _paintRtpcCurve(canvas, size, rtpcType, rtpcPoints[rtpcType]!);
    }
  }

  Color _getCurveColor(int type) {
    if (type == ClipAutomationType.volume.value)
      return Colors.red;
    if (type == ClipAutomationType.fadeIn.value)
      return Colors.teal;
    if (type == ClipAutomationType.fadeOut.value)
      return Colors.teal;
    if (type == ClipAutomationType.lpf.value)
      return Colors.blue.shade900;
    if (type == ClipAutomationType.hpf.value)
      return Colors.blue.shade300;
    return Colors.green;
  }

  double _getScaledY(int type, double y) {
    if (type == ClipAutomationType.volume.value)
      return -y;
    if (type == ClipAutomationType.lpf.value)
      return (100 - y) / 100;
    if (type == ClipAutomationType.hpf.value)
      return (100 - y) / 100;
    return y;
  }

  void _paintRtpcCurve(Canvas canvas, Size size, int type, List<BnkClipRtpcPoint> points) {
    var paint = Paint()
      ..color = _getCurveColor(type)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    
    var path = Path();

    var prevPoint = points.first;
    for (var i = 1; i < points.length; i++) {
      var point = points[i];
      var prevX = prevPoint.x.value / msPerPix;
      var prevY = _getScaledY(type, prevPoint.y.value.toDouble()) * size.height;
      var x = point.x.value / msPerPix;
      double y;
      if (prevPoint.interpolationType == RtpcPointInterpolationType.constant.value)
        y = prevY;
      else
        y = _getScaledY(type, point.y.value.toDouble()) * size.height;
      path.moveTo(prevX, prevY);
      path.lineTo(x, y);
      prevPoint = point;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

}
