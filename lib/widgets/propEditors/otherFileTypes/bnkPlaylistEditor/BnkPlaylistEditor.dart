
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:context_menus/context_menus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

import '../../../../background/wemFilesIndexer.dart';
import '../../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/nestedNotifier.dart';
import '../../../../stateManagement/openFileTypes.dart';
import '../../../../stateManagement/openFilesManager.dart';
import '../../../../utils/utils.dart';
import '../../../misc/CustomIcons.dart';
import '../../../misc/mousePosition.dart';
import '../../../misc/nestedContextMenu.dart';
import '../../../misc/onHoverBuilder.dart';
import '../../../theme/customTheme.dart';
import 'audioSequenceController.dart';

class _AudioEditorData extends InheritedWidget {
  final ValueNotifier<double> msPerPix;
  final ValueNotifier<double> xOff;
  final ValueNestedNotifier<String> selectedClipUuids;
  final BnkTrackClip? Function(String uuid) getClipByUuid;

  const _AudioEditorData({
    required Widget child,
    required this.msPerPix,
    required this.xOff,
    required this.selectedClipUuids,
    required this.getClipByUuid,
  }) : super(child: child);

  @override
  bool updateShouldNotify(_AudioEditorData oldWidget) {
    return msPerPix != oldWidget.msPerPix || xOff != oldWidget.xOff || selectedClipUuids != oldWidget.selectedClipUuids;
  }

  static _AudioEditorData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AudioEditorData>()!;
  }
}

class _SnapPoint {
  final double Function() getPos;
  final Object? owner;
  
  const _SnapPoint(this.getPos, [this.owner]);
  _SnapPoint.prop(NumberProp prop) : this(() => prop.value.toDouble(), prop);
  _SnapPoint.value(double value) : this(() => value);
}

class _SnapPointsData extends InheritedWidget {
  final List<_SnapPoint> staticSnapPoints;
  final Iterable<_SnapPoint> Function() dynamicSnapPoints;

  const _SnapPointsData({
    required Widget child,
    required this.staticSnapPoints,
    required this.dynamicSnapPoints,
  }) : super(child: child);

  @override
  bool updateShouldNotify(_SnapPointsData oldWidget) {
    return staticSnapPoints != oldWidget.staticSnapPoints || dynamicSnapPoints != oldWidget.dynamicSnapPoints;
  }

  static _SnapPointsData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SnapPointsData>()!;
  }

  Iterable<_SnapPoint> getAllSnapPoints() sync* {
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

  _SnapPoint? tryFindSnapPoint(double valMs, List<Object> owners, double msPerPix) {
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

  void _togglePlayback() {
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

  void _onSegmentChange(String segmentUuid) {
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
}

double _getMousePosOnTrack(ValueNotifier<double> xOff, ValueNotifier<double> msPerPix, BuildContext context) {
  var renderBox = context.findRenderObject() as RenderBox;
  var locMousePos = renderBox.globalToLocal(MousePosition.pos).dx;
  var xOffDist = locMousePos - xOff.value;
  return xOffDist * msPerPix.value;
}

class BnkPlaylistEditor extends StatefulWidget {
  final BnkFilePlaylistData playlist;

  const BnkPlaylistEditor({ super.key, required this.playlist });

  @override
  State<BnkPlaylistEditor> createState() => _BnkPlaylistEditorState();
}

class _BnkPlaylistEditorState extends State<BnkPlaylistEditor> {
  CurrentPlaybackItem? _currentPlaybackItem;
  final playbackMarker = PlaybackMarker(ValueNotifier(null), ValueNotifier(0));
  final ValueNotifier<double> msPerPix = ValueNotifier(1);
  final ValueNotifier<double> xOff = ValueNotifier(0);
  final selectedClipUuids = ValueNestedNotifier<String>([]);
  final scrollController = ScrollController();

  @override
  void initState() {
    widget.playlist.load().then((_) async {
      if (context.size == null)
        await waitForNextFrame();
      double maxDuration = 10000;
      var pendingSegments = widget.playlist.rootChild!.children.toList();
      while (pendingSegments.isNotEmpty) {
        var segment = pendingSegments.removeLast();
        if (segment.segment != null) {
          for (var track in segment.segment!.tracks) {
            for (var playlist in track.srcTrack.playlists) {
              maxDuration = max(maxDuration, playlist.fSrcDuration);
            }
          }
        }
        pendingSegments.addAll(segment.children);
      }
      maxDuration *= 1.25;
      var width = context.size?.width ?? 1000;
      msPerPix.value = maxDuration / width;
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlist.loadingState != LoadingState.loaded) {
      return Stack(
        children: const [
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent),
          ),
        ],
      );
    }
    return _AudioEditorData(
      msPerPix: msPerPix,
      xOff: xOff,
      selectedClipUuids: selectedClipUuids,
      getClipByUuid: _getClipByUuid,
      child: AudioPlaybackScope(
        currentPlaybackItem: _currentPlaybackItem,
        playbackMarker: playbackMarker,
        setCurrentPlaybackItem: (item) {
          _currentPlaybackItem = item;
          setState(() {});
        },
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            xOff.value += details.delta.dx;
          },
          onVerticalDragUpdate: (details) {
            scrollController.jumpTo(clamp(scrollController.offset - details.delta.dy, 0, scrollController.position.maxScrollExtent));
          },
          behavior: HitTestBehavior.translucent,
          child: Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent)
                return;
              // zoom
              var scale = event.scrollDelta.dy / 100;
              msPerPix.value *= scale + 1;
              // offset
              var renderBox = context.findRenderObject() as RenderBox;
              var x = renderBox.globalToLocal(event.position).dx;
              var xOffDist = x - xOff.value;
              var xChange = xOffDist * -scale;
              if (scale < 0)  // magic numbers :)
                xChange *= 1.25;
              else
                xChange /= 1.2;
              xOff.value -= xChange;
            },
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40,),
                  Stack(
                    children: [
                      BnkPlaylistChildEditor(
                        plSegment: widget.playlist.rootChild!
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: Tooltip(
                            message: "Update track durations",
                            waitDuration: const Duration(milliseconds: 500),
                            child: IconButton(
                              onPressed: () => widget.playlist.rootChild!.updateTrackDurations()
                                .then((_) => showToast("Updated track durations", const Duration(seconds: 2))),
                              splashRadius: 20,
                              icon: const Icon(Icons.refresh),
                            ),
                          ),
                        )
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BnkTrackClip? _getClipByUuid(String uuid, [BnkPlaylistChild? playlistChild]) {
    playlistChild ??= widget.playlist.rootChild;
    if (playlistChild == null)
      return null;
    if (playlistChild.segment != null) {
      for (var track in playlistChild.segment!.tracks) {
        for (var clip in track.clips) {
          if (clip.uuid == uuid)
            return clip;
        }
      }
    }

    for (var child in playlistChild.children) {
      var clip = _getClipByUuid(uuid, child);
      if (clip != null)
        return clip;
    }

    return null;
  }
}

class BnkPlaylistChildEditor extends StatefulWidget {
  final BnkPlaylistChild plSegment;
  final int depth;

  const BnkPlaylistChildEditor({ super.key, required this.plSegment, this.depth = 0 });

  @override
  State<BnkPlaylistChildEditor> createState() => _BnkPlaylistChildEditorState();
}

class _BnkPlaylistChildEditorState extends State<BnkPlaylistChildEditor> with AudioPlayingWidget {
  bool isCollapsed = false;
  BnkPlaylistChild get plSegment => widget.plSegment;
  BnkSegmentData? get segment => widget.plSegment.segment;

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }

  @override
  PlaybackController makePlaybackController() {
    var audioPlaybackScope = AudioPlaybackScope.of(context);
    PlaybackController playbackController;
    if (segment != null) {
      playbackController = BnkSegmentPlaybackController(plSegment, segment!);
      audioPlaybackScope.playbackMarker.segmentUuid.value = segment!.uuid;
    } else if (plSegment.children.every((c) => c.segment != null)) {
      var newController = MultiSegmentPlaybackController(plSegment);
      playbackController = newController;
      newController.currentSegmentStream.listen(_onSegmentChange);
      audioPlaybackScope.playbackMarker.segmentUuid.value = plSegment.children.first.segment!.uuid;
    } else {
      throw Exception("Can't play this segment");
    }
    return playbackController;
  }

  @override
  Widget build(BuildContext context) {
    var inner = Column(
      children: [
        InkWell(
          onTap: () => setState(() => isCollapsed = !isCollapsed),
          child: Padding(
            padding: EdgeInsets.only(left: widget.depth * 20, top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(isCollapsed ? Icons.chevron_right : Icons.expand_more),
                Flexible(
                  child: Text(
                    "${segment != null ? "Segment" : "Playlist"} (Loops: ${widget.plSegment.loops}) "
                    "${segment == null ? "(Reset type: ${widget.plSegment.resetType.name}) " : ""}"
                    "(ID: ${segment != null ? widget.plSegment.srcItem.segmentId : widget.plSegment.srcItem.playlistItemId})",
                    style: const TextStyle(fontFamily: "FiraCode"),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8,),
                ChangeNotifierBuilder(
                  notifiers: segment?.tracks.map((t) => t.hasSourceChanged).toList(),
                  builder: (context) => segment?.tracks.any((t) => t.hasSourceChanged.value) == true
                    ? Tooltip(
                      message: "Source changed",
                      waitDuration: const Duration(milliseconds: 500),
                      child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(
                            child: Icon(Icons.schedule, size: 16, color: Colors.white.withOpacity(0.8)),
                          ),
                      ),
                    )
                    : const SizedBox()
                ),
                if (segment != null || widget.plSegment.children.isNotEmpty && widget.plSegment.children.every((c) => c.segment != null)) ...[
                  StreamBuilder(
                    stream: currentPlaybackItem?.playbackController.isPlayingStream,
                    builder: (context, snapshot) {
                      return IconButton(
                        iconSize: 20,
                        splashRadius: 20,
                        icon: currentPlaybackItem?.playbackController.isPlaying == true
                          ? const Icon(Icons.pause)
                          : const Icon(Icons.play_arrow),
                        onPressed: _togglePlayback,
                      );
                    }
                  ),
                  StreamBuilder(
                    key: ValueKey(currentPlaybackItem?.playbackController.positionStream),
                    stream: currentPlaybackItem?.playbackController.positionStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        var pos = snapshot.data as double;
                        return Text(formatDuration(Duration(milliseconds: pos.toInt())));
                      }
                      return const SizedBox();
                    }
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!isCollapsed) ...[
          if (segment != null)
            BnkSegmentEditor(
              segment: segment!,
              viewNotifiers: [
                _AudioEditorData.of(context).msPerPix,
                _AudioEditorData.of(context).xOff,
              ],
              playbackMarker: AudioPlaybackScope.of(context).playbackMarker,
            ),
            for (int i = 0; i < widget.plSegment.children.length; i++)
              BnkPlaylistChildEditor(
                plSegment: widget.plSegment.children[i],
                depth: widget.depth + 1,
              )
        ],
      ],
    );
    if (widget.plSegment.children.isNotEmpty) {
      return Material(
        color: getTheme(context).actionBgColor,
        child: Container(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: getTheme(context).propBorderColor!),
            ),
          ),
          child: inner
        ),
      );
    }
    return inner;
  }
}

class BnkSegmentEditor extends ChangeNotifierWidget {
  final BnkSegmentData segment;
  final PlaybackMarker playbackMarker;

  BnkSegmentEditor({ super.key, required this.segment, required List<Listenable> viewNotifiers, required this.playbackMarker })
    : super(notifiers: [
      ...viewNotifiers,
      ...segment.markers.map((m) => m.pos),
      playbackMarker.segmentUuid,
    ]);

  static const headerHeight = 25.0;
  static const markerSize = 20.0;

  @override
  State<BnkSegmentEditor> createState() => _BnkSegmentEditorState();
}

class _BnkSegmentEditorState extends ChangeNotifierState<BnkSegmentEditor> {
  late final List<_SnapPoint> snapPoints;

  @override
  void initState() {
    snapPoints = [
      _SnapPoint.value(0),
      ...widget.segment.markers.map((m) => _SnapPoint.prop(m.pos)),
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var viewData = _AudioEditorData.of(context);
    return _SnapPointsData(
      staticSnapPoints: snapPoints,
      dynamicSnapPoints: () => widget.segment.tracks
        .map((t) => t.clips)
        .expand((c) => c)
        .map((c) => [
          _SnapPoint(() => c.xOff.value + c.beginTrim.value.toDouble(), c.beginTrim),
          _SnapPoint(() => c.xOff.value + c.srcDuration.value + c.endTrim.value.toDouble(), c.endTrim),
          _SnapPoint(() => c.xOff.value.toDouble(), c.xOff),
          _SnapPoint(() => c.xOff.value + c.srcDuration.value.toDouble(), c.srcDuration),
        ])
        .expand((e) => e),
      child: Builder(
        builder: (context) {
          return Stack(
            children: [
              Positioned.fill(
                child: Timeline(
                  headerHeight: BnkSegmentEditor.headerHeight,
                  notifiers: [
                    _AudioEditorData.of(context).msPerPix,
                    _AudioEditorData.of(context).xOff,
                  ]
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: BnkSegmentEditor.headerHeight),
                  for (var track in widget.segment.tracks)
                    BnkTrackEditor(
                      track: track,
                      viewData: viewData,
                      segmentUuid: widget.segment.uuid,
                    ),
                ],
              ),
              ...getMarkers(context, viewData),
              if (widget.playbackMarker.segmentUuid.value == widget.segment.uuid)
                ChangeNotifierBuilder(
                  notifier: widget.playbackMarker.pos,
                  builder: (context) {
                    return Positioned(
                      left: widget.playbackMarker.pos.value / viewData.msPerPix.value + viewData.xOff.value,
                      top: 0,
                      bottom: 0,
                      child: PlaybackMarkerWidget(
                        onDragUpdate: onPlayMarkerDragUpdate,
                      ),
                    );
                  }
                ),
            ],
          );
        }
      ),
    );
  }

  List<Widget> getMarkers(BuildContext context, _AudioEditorData viewData) {
    return [
      for (var i = 0; i < widget.segment.markers.length; i++) ...[
        Positioned(
          left: widget.segment.markers[i].pos.value / viewData.msPerPix.value + viewData.xOff.value + getMarkerOffset(widget.segment.markers[i].role),
          width: BnkSegmentEditor.markerSize,
          // move down a bit, by how close this marker is to the previous one
          top: i - 1 >= 0
            ? clamp(10.0 - (widget.segment.markers[i].pos.value - widget.segment.markers[i - 1].pos.value).abs() / viewData.msPerPix.value, 0, 10)
            : 0,
          child: GestureDetector(
            onHorizontalDragUpdate: (_) {
              var pos = widget.segment.markers[i].pos;
              var newPos = _getMousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
              newPos = _SnapPointsData.of(context).trySnapTo(newPos, [pos], viewData.msPerPix.value);
              pos.value = newPos;
            },
            child: Icon(
              getMarkerIcon(widget.segment.markers[i].role),
              size: BnkSegmentEditor.markerSize,
              color: getMarkerColor(context, widget.segment.markers[i].role)
            ),
          ),
        ),
        Positioned(
          left: widget.segment.markers[i].pos.value / viewData.msPerPix.value + viewData.xOff.value,
          width: 2,
          top: BnkSegmentEditor.headerHeight / 2,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              color: getMarkerColor(context, widget.segment.markers[i].role),
            ),
          ),
        ),
      ]
    ];
  }

  double getMarkerOffset(BnkMarkerRole type) {
    switch (type) {
      case BnkMarkerRole.entryCue:
        return -3;
      case BnkMarkerRole.exitCue:
        return -BnkSegmentEditor.markerSize + 4;
      default:
        return -BnkSegmentEditor.markerSize / 2;
    }
  }

  IconData getMarkerIcon(BnkMarkerRole type) {
    switch (type) {
      case BnkMarkerRole.entryCue:
        return CustomIcons.entryCue2_rounded;
      case BnkMarkerRole.exitCue:
        return CustomIcons.exitCue2_rounded;
      default:
        return CustomIcons.customCue2_rounded;
    }
  }

  Color getMarkerColor(BuildContext context, BnkMarkerRole type) {
    switch (type) {
      case BnkMarkerRole.entryCue:
        return getTheme(context).entryCueColor!;
      case BnkMarkerRole.exitCue:
        return getTheme(context).exitCueColor!;
      default:
        return getTheme(context).customCueColor!;
    }
  }

  void onPlayMarkerDragUpdate(DragUpdateDetails details) {
    var player = AudioPlaybackScope.of(context);
    if (player.currentPlaybackItem == null)
      return;
    var viewData = _AudioEditorData.of(context);
    var pos = _getMousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
    var playbackController = player.currentPlaybackItem!.playbackController;
    pos = clamp(pos, 0, playbackController.duration);
    playbackController.seekTo(pos);
  }
}

class PlaybackMarkerWidget extends StatefulWidget {
  final void Function(DragUpdateDetails details) onDragUpdate;

  const PlaybackMarkerWidget({ super.key, required this.onDragUpdate });

  @override
  State<PlaybackMarkerWidget> createState() => _PlaybackMarkerWidgetState();
}

class _PlaybackMarkerWidgetState extends State<PlaybackMarkerWidget> {
  @override
  Widget build(BuildContext context) {
    const iconSize = 12.5;
    return SizedBox(
      width: iconSize + 5,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: iconSize,
            child: CustomPaint(
              painter: _PlaybackMarkerPainter(iconSize: iconSize),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: iconSize,
            height: 25,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              hitTestBehavior: HitTestBehavior.translucent,
              child: GestureDetector(
                onHorizontalDragUpdate: widget.onDragUpdate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackMarkerPainter extends CustomPainter {
  final double iconSize;

  _PlaybackMarkerPainter({required this.iconSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.teal
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    List<Offset> points = [
      const Offset(0, 0),
      Offset(iconSize, 12.5),
      const Offset(0, 25),
      Offset(0, size.height),
    ];

    canvas.drawPoints(PointMode.polygon, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BnkTrackEditor extends ChangeNotifierWidget {
  final String segmentUuid;
  final BnkTrackData track;
  final _AudioEditorData viewData;

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
  void initState() {
    Future.wait(widget.track.clips.map((c) => c.loadResource()))
      .then((_) {
        if (mounted)
          setState(() {});
      });
    super.initState();
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
    var viewData = _AudioEditorData.of(context);
    return SizedBox(
      height: 60,
      child: GestureDetector(
        onTap: () => setState(() => viewData.selectedClipUuids.clear()),
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
                          opacity: isHovering ? 1 : 0.5,
                          child: StreamBuilder(
                            key: ValueKey(currentPlaybackItem),
                            stream: currentPlaybackItem?.playbackController.isPlayingStream,
                            builder: (context, snapshot) {
                              return IconButton(
                                icon: currentPlaybackItem?.playbackController.isPlaying == true
                                  ? const Icon(Icons.pause)
                                  : const Icon(Icons.play_arrow),
                                splashRadius: 20,
                                onPressed: _togglePlayback,
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

  List<Widget> _makeClipWidgets(int i, BnkTrackClip clip, _AudioEditorData viewData, double viewWidth) {
    var srcId = widget.track.srcTrack.sources.first.sourceID;
    return [
      if (clip == widget.track.clips.first)
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
      ChangeNotifierBuilder(
        key: Key("${clip.uuid}_main"),
        notifiers: _getClipNotifiers(clip),
        builder: (context) {
          return Positioned(
            left: (clip.xOff.value + clip.beginTrim.value) / viewData.msPerPix.value + viewData.xOff.value,
            width: (clip.srcDuration.value - clip.beginTrim.value + clip.endTrim.value) / viewData.msPerPix.value,
            height: 60,
            child: NestedContextMenu(
              buttons: [
                ContextMenuButtonConfig(
                  "Duplicate",
                  icon: const Icon(Icons.copy_all, size: 16),
                  onPressed: () => _duplicateClip(clip),
                ),
                ContextMenuButtonConfig(
                  "Delete",
                  icon: const Icon(Icons.delete, size: 16),
                  onPressed: () => _deleteClip(clip),
                ),
                ContextMenuButtonConfig(
                  "Copy offsets",
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () => _copyOffsets(clip),
                ),
                ContextMenuButtonConfig(
                  "Paste offsets",
                  icon: const Icon(Icons.paste, size: 16),
                  onPressed: () => _pasteOffsets(clip),
                ),
                if (i == 0 && viewData.selectedClipUuids.length >= 2)
                  ContextMenuButtonConfig(
                    "Trim start to other selection",
                    icon: const Icon(Icons.cut, size: 16),
                    onPressed: () => _trimToOtherSelection(clip),
                  ),
                ContextMenuButtonConfig(
                  "Replace WEM",
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () => _replaceWem(clip),
                ),
                ContextMenuButtonConfig(
                  "Open WEM in explorer",
                  icon: const Icon(Icons.folder_open, size: 16),
                  onPressed: () => _openWemInExplorer(clip),
                ),
              ],
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
      if (clip == widget.track.clips.last)
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
    var data = _AudioEditorData.of(context);
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
    clip.beginTrim.value = otherClip.srcDuration.value + otherClip.endTrim.value;
  }

  void _replaceWem(BnkTrackClip clip) {
    var srcId = widget.track.srcTrack.sources.first.sourceID;
    var wemPath = wemFilesLookup.lookup[srcId];
    if (wemPath == null) {
      showToast("WEM file not found");
      return;
    }
    areasManager.openFile(wemPath);
  }

  void _openWemInExplorer(BnkTrackClip clip) {
    var srcId = widget.track.srcTrack.sources.first.sourceID;
    var wemPath = wemFilesLookup.lookup[srcId];
    if (wemPath == null) {
      showToast("WEM file not found");
      return;
    }
    revealFileInExplorer(wemPath);
  }

  void _selectClip(BnkTrackClip clip) {
    var viewData = _AudioEditorData.of(context);
    if (isCtrlPressed() || isShiftPressed()) {
      if (viewData.selectedClipUuids.contains(clip.uuid))
        viewData.selectedClipUuids.remove(clip.uuid);
      else
        viewData.selectedClipUuids.add(clip.uuid);
    } else {
      viewData.selectedClipUuids.clear();
      viewData.selectedClipUuids.add(clip.uuid);
    }
  }

  void _moveSelectedClips(DragUpdateDetails details, BnkTrackClip clip) {
    var viewData = _AudioEditorData.of(context);
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
    var snapPoints = _SnapPointsData.of(context);
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
  }

  void _onBeginTrimDrag(BnkTrackClip clip) {
    var viewData = _AudioEditorData.of(context);
    var newBeginTrim = _getMousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
    newBeginTrim = _SnapPointsData.of(context).trySnapTo(newBeginTrim, [clip.beginTrim], viewData.msPerPix.value);
    newBeginTrim -= clip.xOff.value;
    newBeginTrim = clamp(newBeginTrim, 0, clip.srcDuration.value - clip.endTrim.value.toDouble());
    clip.beginTrim.value = newBeginTrim;
  }

  void _onEndTrimDrag(BnkTrackClip clip) {
    var viewData = _AudioEditorData.of(context);
    var newEndTrim = _getMousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
    newEndTrim = _SnapPointsData.of(context).trySnapTo(newEndTrim, [clip.endTrim], viewData.msPerPix.value);
    newEndTrim = clip.xOff.value + clip.srcDuration.value - newEndTrim;
    newEndTrim = clamp(newEndTrim, 0, clip.srcDuration.value - clip.beginTrim.value.toDouble());
    clip.endTrim.value = -newEndTrim;
  }

  void _duplicateClip(BnkTrackClip clip) {
    var newClip = clip.duplicate();
    newClip.xOff.value += clip.srcDuration.value - clip.beginTrim.value + clip.endTrim.value;
    newClip.loadResource().then((value) => setState(() {}));
    widget.track.clips.add(newClip);
    var viewData = _AudioEditorData.of(context);
    viewData.selectedClipUuids.clear();
    viewData.selectedClipUuids.add(newClip.uuid);
  }

  void _deleteClip(BnkTrackClip clip) {
    var viewData = _AudioEditorData.of(context);
    viewData.selectedClipUuids.remove(clip.uuid);
    widget.track.clips.remove(clip);
    clip.dispose();
  }
}

class _ClipWaveformPainter extends CustomPainter {
  final BnkTrackClip clip;
  final _AudioEditorData viewData;
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

class Timeline extends ChangeNotifierWidget {
  final double headerHeight;

  Timeline({ super.key, required super.notifiers, required this.headerHeight });

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends ChangeNotifierState<Timeline> {
  @override
  Widget build(BuildContext context) {
    var viewData = _AudioEditorData.of(context);
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: widget.headerHeight,
          child: Container(
            color: getTheme(context).audioTimelineBgColor,
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _TimelinePainter(
              viewData: viewData,
              headerHeight: widget.headerHeight,
              textColor: getTheme(context).textColor!,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final _AudioEditorData viewData;
  final double headerHeight;
  final Color textColor;

  _TimelinePainter({ required this.viewData, required this.headerHeight, required this.textColor });

  static const Map<int, double> viewWidthMsToMarkerInterval = {
    10: 0.001,
    25: 0.002,
    50: 0.005,
    125: 0.01,
    250: 0.025,
    500: 0.05,
    1000: 0.1,
    2000: 0.25,
    5000: 0.5,
    10000: 1,
    20000: 2,
    50000: 5,
    100000: 10,
    200000: 20,
    500000: 30,
    1000000: 60,
    4000000: 240,
    10000000: 600,
    20000000: 1200,
    50000000: 3000,
  };

  @override
  void paint(Canvas canvas, Size size) {
    var canvasWidth = size.width;
    var msPerPix = viewData.msPerPix;
    var viewWidthMs = canvasWidth * msPerPix.value;
    var viewStart = -viewData.xOff.value;
    var viewStartMs = viewStart * msPerPix.value;

    double ticksIntervalMs = -1;
    for (var entry in viewWidthMsToMarkerInterval.entries) {
      if (viewWidthMs < entry.key) {
        ticksIntervalMs = entry.value * 1000;
        break;
      }
    }
    if (ticksIntervalMs == -1)
      ticksIntervalMs = viewWidthMsToMarkerInterval.entries.last.value * 1000;
    var ticksInterval = ticksIntervalMs / msPerPix.value;
    var ticksCount = (canvasWidth / ticksInterval).ceil() + 1;
    var minorTicksCount = (ticksIntervalMs / 1000).floor() % 5 == 0 ? 5 : 4;
    var minorTicksInterval = ticksInterval / minorTicksCount;
    var tickAlignmentOffset = viewStart % ticksInterval;
    if (viewStart < tickAlignmentOffset)
      tickAlignmentOffset -= ticksInterval;
    var tickAlignmentOffsetMs = tickAlignmentOffset * msPerPix.value;
    
    var majorTickPaint = Paint()
      ..color = textColor.withOpacity(0.5)
      ..strokeWidth = 3;
    var minorTickPaint = Paint()
      ..color = textColor.withOpacity(0.25)
      ..strokeWidth = 1;
    var majorBigTickPaint = Paint()
      ..color = textColor.withOpacity(0.25);
    var textPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < ticksCount; i++) {
      var tickMs = viewStartMs + i * ticksIntervalMs - tickAlignmentOffsetMs;
      var x = i * ticksInterval - tickAlignmentOffset;
      // header major tick
      canvas.drawLine(Offset(x, 0), Offset(x, headerHeight / 2), majorTickPaint);
      // header minor ticks
      for (int j = 1; j < minorTicksCount; j++) {
        var minorTickX = x + j * minorTicksInterval;
        canvas.drawLine(Offset(minorTickX, 0), Offset(minorTickX, headerHeight / minorTicksCount), minorTickPaint);
      }
      // big line
      canvas.drawLine(Offset(x, headerHeight), Offset(x, size.height), majorBigTickPaint);
      var showDecimal = ticksIntervalMs < 1000;
      String text = "";
      if (tickMs < -1e-10) {
        text = "-";
        tickMs = tickMs.abs();
      }
      text += formatDuration(Duration(milliseconds: tickMs.round()), showDecimal);
      textPaint.text = TextSpan(
        text: text,
        style: TextStyle(
          color: textColor.withOpacity(0.5),
          fontFamily: "FiraCode",
          fontSize: 11,
        ),
      );
      textPaint.layout();
      textPaint.paint(canvas, Offset(x, headerHeight / 2));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}