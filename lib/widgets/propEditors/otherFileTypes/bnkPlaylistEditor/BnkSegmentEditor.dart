
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../../stateManagement/openFileTypes.dart';
import '../../../../utils/utils.dart';
import '../../../misc/CustomIcons.dart';
import '../../../theme/customTheme.dart';
import 'BnkPlaylistEditorInheritedData.dart';
import 'BnkTrackEditor.dart';

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
  late final List<SnapPoint> snapPoints;

  @override
  void initState() {
    snapPoints = [
      SnapPoint.value(0),
      ...widget.segment.markers.map((m) => SnapPoint.prop(m.pos)),
      SnapPoint.valueNotifier(widget.playbackMarker.pos),
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var viewData = AudioEditorData.of(context);
    return SnapPointsData(
      staticSnapPoints: snapPoints,
      dynamicSnapPoints: () => widget.segment.tracks
        .map((t) => t.clips)
        .expand((c) => c)
        .map((c) => [
          SnapPoint(() => c.xOff.value + c.beginTrim.value.toDouble(), c.beginTrim),
          SnapPoint(() => c.xOff.value + c.srcDuration.value + c.endTrim.value.toDouble(), c.endTrim),
          SnapPoint(() => c.xOff.value.toDouble(), c.xOff),
          SnapPoint(() => c.xOff.value + c.srcDuration.value.toDouble(), c.srcDuration),
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
                    AudioEditorData.of(context).msPerPix,
                    AudioEditorData.of(context).xOff,
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
                        onDragUpdate: () => onPlayMarkerDragUpdate(SnapPointsData.of(context)),
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

  List<Widget> getMarkers(BuildContext context, AudioEditorData viewData) {
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
              var newPos = getMousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
              newPos = SnapPointsData.of(context).trySnapTo(newPos, [pos], viewData.msPerPix.value);
              pos.value = newPos;
              AudioPlaybackScope.of(context).cancelCurrentPlayback();
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

  void onPlayMarkerDragUpdate(SnapPointsData snap) {
    var player = AudioPlaybackScope.of(context);
    if (player.currentPlaybackItem == null)
      return;
    var viewData = AudioEditorData.of(context);
    var pos = getMousePosOnTrack(viewData.xOff, viewData.msPerPix, context);
    var playbackController = player.currentPlaybackItem!.playbackController;
    pos = clamp(pos, 0, playbackController.duration);
    // pos = snap.trySnapTo(pos, [widget.playbackMarker.pos], viewData.msPerPix.value);
    playbackController.seekTo(pos);
  }
}

class PlaybackMarkerWidget extends StatefulWidget {
  final void Function() onDragUpdate;

  const PlaybackMarkerWidget({ super.key, required this.onDragUpdate });

  @override
  State<PlaybackMarkerWidget> createState() => _PlaybackMarkerWidgetState();
}

class _PlaybackMarkerWidgetState extends State<PlaybackMarkerWidget> {
  late final void Function() throttledOnDragUpdate;

  @override
  void initState() {
    super.initState();
    throttledOnDragUpdate = throttle(widget.onDragUpdate, 25);
  }

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
                onHorizontalDragUpdate: (_) => throttledOnDragUpdate(),
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

class Timeline extends ChangeNotifierWidget {
  final double headerHeight;

  Timeline({ super.key, required super.notifiers, required this.headerHeight });

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends ChangeNotifierState<Timeline> {
  @override
  Widget build(BuildContext context) {
    var viewData = AudioEditorData.of(context);
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
  final AudioEditorData viewData;
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
