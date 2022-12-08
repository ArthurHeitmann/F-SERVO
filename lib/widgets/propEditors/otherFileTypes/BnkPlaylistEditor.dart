
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../utils/utils.dart';
import '../../misc/CustomIcons.dart';
import '../../misc/mousePosition.dart';
import '../../misc/onHoverBuilder.dart';
import '../../theme/customTheme.dart';

extension ColorFilter on Color {
  Color withSaturation(double saturation) {
    var hsl = HSLColor.fromColor(this);
    return hsl.withSaturation(saturation).toColor();
  }

  Color withLightness(double lightness) {
    var hsl = HSLColor.fromColor(this);
    return hsl.withLightness(lightness).toColor();
  }
}

class _AudioEditorData extends InheritedWidget {
  final ValueNotifier<double> msPerPix;
  final ValueNotifier<double> xOff;

  const _AudioEditorData({
    required Widget child,
    required this.msPerPix,
    required this.xOff,
  }) : super(child: child);

  @override
  bool updateShouldNotify(_AudioEditorData oldWidget) {
    return msPerPix != oldWidget.msPerPix || xOff != oldWidget.xOff;
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
  final List<_SnapPoint> snapPoints;

  const _SnapPointsData({
    required Widget child,
    required this.snapPoints,
  }) : super(child: child);

  @override
  bool updateShouldNotify(_SnapPointsData oldWidget) {
    return snapPoints != oldWidget.snapPoints;
  }

  static _SnapPointsData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SnapPointsData>()!;
  }

  double trySnapTo(double valMs, List<Object> owners, double msPerPix) {
    const snapThresholdPx = 8;
    var curPx = valMs / msPerPix;
    for (var snapPoint in snapPoints) {
      if (owners.contains(snapPoint.owner))
        continue;
      var snapPx = snapPoint.getPos() / msPerPix;
      if ((snapPx - curPx).abs() < snapThresholdPx)
        return snapPoint.getPos();
    }
    return valMs;
  }
}

double _mousePosOnTrack(ValueNotifier<double> xOff, ValueNotifier<double> msPerPix, BuildContext context) {
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
  final ValueNotifier<double> msPerPix = ValueNotifier(1);
  final ValueNotifier<double> xOff = ValueNotifier(0);
  final scrollController = ScrollController();

  @override
  void initState() {
    widget.playlist.load().then((_) async {
      if (context.size == null)
        await waitForNextFrame();
      double maxDuration = 0;
      var pendingSegments = widget.playlist.rootChild!.children.toList();
      while (pendingSegments.isNotEmpty) {
        var segment = pendingSegments.removeLast();
        if (segment.segment != null)
          maxDuration = max(maxDuration, segment.segment!.tracks.first.srcTrack.playlists.first.fSrcDuration);
        pendingSegments.addAll(segment.children);
      }
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
    var segments = widget.playlist.rootChild!.children;
    return _AudioEditorData(
      msPerPix: msPerPix,
      xOff: xOff,
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
            xOff.value -= xChange;
          },
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                BnkPlaylistChildEditor(
                  plSegment: widget.playlist.rootChild!
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BnkPlaylistChildEditor extends StatefulWidget {
  final BnkPlaylistChild plSegment;
  final int depth;

  const BnkPlaylistChildEditor({ super.key, required this.plSegment, this.depth = 0 });

  @override
  State<BnkPlaylistChildEditor> createState() => _BnkPlaylistChildEditorState();
}

class _BnkPlaylistChildEditorState extends State<BnkPlaylistChildEditor> {
  bool isCollapsed = false;
  BnkSegmentData? get segment => widget.plSegment.segment;

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
                Text(
                  "${segment != null ? "Segment" : "Playlist"} (Loops: ${widget.plSegment.loops}) "
                  "${segment == null ? "(Reset type: ${widget.plSegment.resetType.name}) " : ""}"
                  "(ID: ${segment != null ? widget.plSegment.srcItem.segmentId : widget.plSegment.srcItem.playlistItemId})",
                  style: const TextStyle(fontFamily: "FiraCode"),
                ),
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
            ),
            for (var child in widget.plSegment.children)
              BnkPlaylistChildEditor(
                plSegment: child,
                depth: widget.depth + 1,
              )
        ],
      ],
    );
    if (widget.plSegment.children.isNotEmpty && widget.plSegment.children.every((c) => c.segment != null)) {
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

  BnkSegmentEditor({ super.key, required this.segment, required List<Listenable> viewNotifiers })
    : super(notifiers: [...viewNotifiers, ...segment.markers.map((m) => m.pos)]);

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
      ...widget.segment.tracks
        .map((t) => t.clips)
        .expand((c) => c)
        .map((c) => [
          _SnapPoint(() => c.xOff.value + c.beginTrim.value.toDouble(), c.beginTrim),
          _SnapPoint(() => c.xOff.value + c.srcDuration.value + c.endTrim.value.toDouble(), c.endTrim),
          _SnapPoint(() => c.xOff.value.toDouble(), c.xOff),
          _SnapPoint(() => c.xOff.value + c.srcDuration.value.toDouble(), c.srcDuration),
        ])
        .expand((e) => e),
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var viewData = _AudioEditorData.of(context);
    return _SnapPointsData(
      snapPoints: snapPoints,
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
                    ),
                ],
              ),
              ...getMarkers(context, viewData),
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
              var newPos = _mousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
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
}

class BnkTrackEditor extends ChangeNotifierWidget {
  final BnkTrackData track;
  final _AudioEditorData viewData;

  BnkTrackEditor({ super.key, required this.track, required this.viewData })
    : super(notifiers: [
      viewData.msPerPix,
      viewData.xOff,
      ...track.clips
        .map((c) => <Listenable>[c.beginTrim, c.endTrim, c.xOff, c.srcDuration])
        .expand((e) => e)
        .toList(),
    ]
  );

  @override
  State<BnkTrackEditor> createState() => _BnkTrackEditorState();
}

class _BnkTrackEditorState extends ChangeNotifierState<BnkTrackEditor> {
  final Set<int> selectedClips = {};

  @override
  Widget build(BuildContext context) {
    var viewData = _AudioEditorData.of(context);
    return SizedBox(
      height: 60,
      child: GestureDetector(
        onTap: () => setState(() => selectedClips.clear()),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            for (int i = 0; i < widget.track.clips.length; i++)
              ..._makeClipWidgets(i, widget.track.clips[i], viewData),
          ],
        ),
      )
    );
  }

  List<Widget> _makeClipWidgets(int i, BnkTrackClip clip, _AudioEditorData viewData) {
    var srcId = widget.track.srcTrack.sources.first.sourceID;
    return [
      if (clip == widget.track.clips.first)
        Positioned(
          left: (clip.xOff.value) / viewData.msPerPix.value + viewData.xOff.value,
          width: (clip.beginTrim.value) / viewData.msPerPix.value,
          height: 60,
          child: Container(
            color: getTheme(context).audioDisabledColor,
          ),
        ),
      Positioned(
        left: (clip.xOff.value + clip.beginTrim.value) / viewData.msPerPix.value + viewData.xOff.value,
        width: (clip.srcDuration.value - clip.beginTrim.value + clip.endTrim.value) / viewData.msPerPix.value,
        height: 60,
        child: GestureDetector(
          onTap: () => setState(() {
            if (isCtrlPressed() || isShiftPressed()) {
              if (selectedClips.contains(i))
                selectedClips.remove(i);
              else
                selectedClips.add(i);
            } else {
              selectedClips.clear();
              selectedClips.add(i);
            }
          }),
          onHorizontalDragUpdate: selectedClips.contains(i) ? (details) {
            double change = details.delta.dx * viewData.msPerPix.value;
            for (var i in selectedClips) {
              var clip = widget.track.clips[i];
              clip.xOff.value += change;
            }
          } : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: getTheme(context).audioColor,
                    border: Border.all(
                      color: selectedClips.contains(i) ? getTheme(context).textColor! : Colors.transparent,
                      width: 1
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
                    onHorizontalDragUpdate: (details) {
                      var newBeginTrim = _mousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
                      newBeginTrim = _SnapPointsData.of(context).trySnapTo(newBeginTrim, [clip.beginTrim], viewData.msPerPix.value);
                      newBeginTrim -= clip.xOff.value;
                      newBeginTrim = clamp(newBeginTrim, 0, clip.srcDuration.value - clip.endTrim.value.toDouble());
                      clip.beginTrim.value = newBeginTrim;
                    },
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
                    onHorizontalDragUpdate: (details) {
                      var newEndTrim = _mousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
                      newEndTrim = _SnapPointsData.of(context).trySnapTo(newEndTrim, [clip.endTrim], viewData.msPerPix.value);
                      newEndTrim = clip.xOff.value + clip.srcDuration.value - newEndTrim;
                      newEndTrim = clamp(newEndTrim, 0, clip.srcDuration.value - clip.beginTrim.value.toDouble());
                      clip.endTrim.value = -newEndTrim;
                    },
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
      if (clip == widget.track.clips.last)
        Positioned(
          left: (clip.xOff.value + clip.srcDuration.value + clip.endTrim.value) / viewData.msPerPix.value + viewData.xOff.value,
          width: (-clip.endTrim.value) / viewData.msPerPix.value,
          height: 60,
          child: Container(
            color: getTheme(context).audioDisabledColor,
          ),
        ),
    ];
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
            painter: TimelinePainter(
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

class TimelinePainter extends CustomPainter {
  final _AudioEditorData viewData;
  final double headerHeight;
  final Color textColor;

  TimelinePainter({ required this.viewData, required this.headerHeight, required this.textColor });

  static const Map<int, double> viewWidthMsToMarkerInterval = {
    1000: 0.125,
    2000: 0.25,
    5000: 0.5,
    10000: 1,
    20000: 2.5,
    50000: 5,
    100000: 10,
    200000: 20,
    500000: 30,
    1000000: 60,
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
    var minorTicksInterval = ticksInterval / 4;
    var minorTicksIntervalMs = ticksIntervalMs / 4;
    var ticksCount = (canvasWidth / ticksInterval).ceil() + 1;
    var tickAlignmentOffset = viewStart % ticksInterval;
    if (viewStart < tickAlignmentOffset)
      tickAlignmentOffset -= ticksInterval;
    var tickAlignmentOffsetMs = tickAlignmentOffset * msPerPix.value;
    
    var majorTickPaint = Paint()
      ..color = textColor.withOpacity(0.5)
      ..strokeWidth = 3;
    var majorBigTickPaint = Paint()
      ..color = textColor.withOpacity(0.25);
    var textPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < ticksCount; i++) {
      var tickMs = viewStartMs + i * ticksIntervalMs - tickAlignmentOffsetMs;
      var x = i * ticksInterval - tickAlignmentOffset;
      // header line
      canvas.drawLine(Offset(x, 0), Offset(x, headerHeight / 2), majorTickPaint);
      // big line
      canvas.drawLine(Offset(x, headerHeight), Offset(x, size.height), majorBigTickPaint);
      var showDecimal = ticksIntervalMs < 1000;
      var text = (tickMs < -(e-10) ? "-" : "") + formatDuration(Duration(milliseconds: tickMs.round()), showDecimal);
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
    return true;  // TODO
  }
}