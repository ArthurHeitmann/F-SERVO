
import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/openFileTypes.dart';
import '../../../utils/utils.dart';
import '../../misc/mousePosition.dart';
import '../../theme/customTheme.dart';

class AudioFileEditor extends StatefulWidget {
  final AudioFileData file;
  final bool lockControls;
  final Widget? additionalControls;
  final Widget? rightSide;

  const AudioFileEditor({ super.key, required this.file, this.lockControls = false, this.additionalControls, this.rightSide });

  @override
  State<AudioFileEditor> createState() => _AudioFileEditorState();
}

class _AudioFileEditorState extends State<AudioFileEditor> {
  late final AudioPlayer? _player;
  final ValueNotifier<int> _viewStart = ValueNotifier(0);
  final ValueNotifier<int> _viewEnd = ValueNotifier(1000);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    widget.file.load().then((_) {
      if (!mounted)
        return;
      _player!.setSourceDeviceFile(widget.file.resource!.wavPath);
      _viewEnd.value = widget.file.resource!.totalSamples;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    _viewStart.dispose();
    _viewEnd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.file.resource == null)
            const SizedBox(
              height: 2,
              child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
            ),
          _TimelineEditor(
            file: widget.file,
            player: _player,
            lockControls: widget.lockControls,
            viewStart: _viewStart,
            viewEnd: _viewEnd,
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "  ${widget.file.name}",
                        style: const TextStyle(fontFamily: "FiraCode", fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.first_page),
                            splashRadius: 25,
                            onPressed: () => _player?.seek(Duration.zero),
                          ),
                          StreamBuilder(
                            stream: _player?.onPlayerStateChanged,
                            builder: (context, snapshot) => IconButton(
                              icon: _player?.state == PlayerState.playing
                                ? const Icon(Icons.pause)
                                : const Icon(Icons.play_arrow),
                                splashRadius: 25,
                              onPressed: _player?.state == PlayerState.playing
                                ? _player?.pause
                                : _player?.resume,
                            )
                          ),
                          IconButton(
                            icon: const Icon(Icons.last_page),
                            splashRadius: 25,
                            onPressed: () => _player?.seek(Duration(milliseconds: widget.file.resource!.totalSamples ~/ widget.file.resource!.sampleRate - 200)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.repeat),
                            splashRadius: 25,
                            color: _player?.releaseMode == ReleaseMode.loop ? Theme.of(context).colorScheme.secondary : null,
                            onPressed: () => _player?.setReleaseMode(_player?.releaseMode == ReleaseMode.loop ? ReleaseMode.stop : ReleaseMode.loop)
                                                    .then((_) => setState(() {})),
                          ),
                          const SizedBox(width: 15),
                          DurationStream(
                            time: _player?.onPositionChanged,
                          ),
                          const Text(" / "),
                          DurationStream(
                            time: _player?.onDurationChanged,
                            fallback: widget.file.resource?.duration,
                          ),
                          const SizedBox(width: 15),
                        ],
                      ),
                      if (widget.additionalControls != null) ...[
                        const SizedBox(height: 10),
                        widget.additionalControls!,
                      ]
                    ],
                  ),
                ),
              ),
              // _CuePointsEditor(
              //   cuePoints: widget.file.cuePoints,
              //   file: widget.file,
              // ),
              if (widget.rightSide != null) ...[
                const SizedBox(width: 10),
                widget.rightSide!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineEditor extends StatefulWidget {
  final AudioFileData file;
  final AudioPlayer? player;
  final bool lockControls;
  final ValueNotifier<int> viewStart;
  final ValueNotifier<int> viewEnd;

  const _TimelineEditor({
    required this.file, required this.player, required this.lockControls,
    required this.viewStart, required this.viewEnd
  });

  @override
  State<_TimelineEditor> createState() => __TimelineEditorState();
}

class __TimelineEditorState extends State<_TimelineEditor> {
  int _currentPosition = 0;
  late StreamSubscription<Duration> updateSub;
  ValueNotifier<int> get viewStart => widget.viewStart;
  ValueNotifier<int> get viewEnd => widget.viewEnd;

  @override
  void initState() {
    updateSub = widget.player!.onPositionChanged.listen(_onPositionChange);
    super.initState();
  }

  @override
  void dispose() {
    updateSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: 100,
          child: Listener(
            onPointerSignal: !widget.lockControls ? _onPointerSignal : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _onTimelineTap,
                    onHorizontalDragUpdate: !widget.lockControls ? _onHorizontalDragUpdate : null,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        samples: widget.file.resource?.previewSamples,
                        viewStart: viewStart.value,
                        viewEnd: viewEnd.value,
                        totalSamples: widget.file.resource?.totalSamples ?? 44100,
                        curSample: _currentPosition,
                        samplesPerSec: widget.file.resource?.sampleRate ?? 44100,
                        scaleFactor: MediaQuery.of(context).devicePixelRatio,
                        lineColor: getTheme(context).audioColor!,
                        lineInactiveColor: getTheme(context).audioDisabledColor!,
                        textColor: getTheme(context).textColor!.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                // for (var cuePoint in widget.file.cuePoints)
                //   ChangeNotifierBuilder(
                //     key: Key(cuePoint.uuid),
                //     notifiers: [cuePoint.sample, cuePoint.name],
                //     builder: (context) => Positioned(
                //       left: (cuePoint.sample.value - viewStart.value) / (viewEnd.value - viewStart.value) * constraints.maxWidth - 8,
                //       top: 0,
                //       bottom: 0,
                //       child: _CuePointMarker(
                //         cuePoint: cuePoint,
                //         viewStart: viewStart,
                //         viewEnd: viewEnd,
                //         totalSamples: widget.file.resource!.totalSamples,
                //         samplesPerSec: widget.file.resource!.sampleRate,
                //         parentWidth: constraints.maxWidth,
                //         onDrag: _onCuePointDrag,
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _onPositionChange(event) {
    if (!mounted)
      return;
    setState(() => _currentPosition = event.inMicroseconds * widget.file.resource!.sampleRate ~/ 1000000);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent)
      return;
    double delta = event.scrollDelta.dy;
    int viewArea = viewEnd.value - viewStart.value;
    // zoom in/out by 10% of the view area
    if (delta < 0) {
      viewStart.value = max((viewStart.value + viewArea * 0.1).round(), 0);
      viewEnd.value = min((viewEnd.value - viewArea * 0.1).round(), widget.file.resource!.totalSamples);
    } else {
      viewStart.value = max((viewStart.value - viewArea * 0.1).round(), 0);
      viewEnd.value= min((viewEnd.value + viewArea * 0.1).round(), widget.file.resource!.totalSamples);
    }
    setState(() {});
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    var totalViewWidth = context.size!.width;
    int viewArea = viewEnd.value - viewStart.value;
    int delta = (details.delta.dx / totalViewWidth * viewArea).round();
    if (delta > 0) {
      int maxChange = viewStart.value;
      delta = min(delta, maxChange);
    } else {
      int maxChange = widget.file.resource!.totalSamples - viewEnd.value;
      delta = max(delta, -maxChange);
    }
    viewStart.value -= delta;
    viewEnd.value -= delta;
    setState(() {});
  }

  void _onTimelineTap() {
    var renderBox = context.findRenderObject() as RenderBox;
    var locTapPos = renderBox.globalToLocal(MousePosition.pos);
    var xPos = locTapPos.dx;
    double relX = xPos / context.size!.width;
    int viewArea = viewEnd.value - viewStart.value;
    int newPosition = (viewStart.value + relX * viewArea).round();
    _currentPosition = clamp(newPosition, 0, widget.file.resource!.totalSamples);
    widget.player!.seek(Duration(microseconds: _currentPosition * 1000000 ~/ widget.file.resource!.sampleRate));
  }

  // void _onCuePointDrag(double xPos, CuePointMarker cuePoint) {
  //   var renderBox = context.findRenderObject() as RenderBox;
  //   var localPos = renderBox.globalToLocal(Offset(xPos, 0));
  //   int viewArea = viewEnd.value - viewStart.value;
  //   int sample = (localPos.dx / context.size!.width * viewArea + viewStart.value).round();
  //   sample = clamp(sample, 0, widget.file.resource!.totalSamples - 1);
  //   cuePoint.sample.value = sample;
  //   setState(() {});
  // }
}

class _WaveformPainter extends CustomPainter {
  final List<double>? samples;
  final int viewStart;
  final int viewEnd;
  final int totalSamples;
  final int curSample;
  final int samplesPerSec;
  final double scaleFactor;
  final Color lineColor;
  final Color lineInactiveColor;
  final Color textColor;
  Size prevSize = Size.zero;

  static const Map<int, double> viewWidthMsToMarkerInterval = {
    50: 0.0025,
    100: 0.005,
    250: 0.025,
    500: 0.05,
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

  _WaveformPainter({
    required this.samples,
    required this.viewStart, required this.viewEnd,
    required this.totalSamples, required this.curSample, required this.samplesPerSec,
     required this.scaleFactor, required this.lineColor, required this.lineInactiveColor, required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    prevSize = size;
    if (samples != null)
      paintWaveform(canvas, size, samples!);
    else
      paintTimeline(canvas, size);
    paintTimeMarkers(canvas, size);
  }
  
  void paintWaveform(Canvas canvas, Size size, List<double> samples) {
    // only show samples that are in the view up to pixel resolution
    double viewStartRel = viewStart / totalSamples;
    double viewEndRel = viewEnd / totalSamples;
    double curSampleRel = curSample / totalSamples;
    int startSample = (viewStartRel * samples.length).round();
    int endSample = (viewEndRel * samples.length).round();
    int curSampleIdx = (curSampleRel * samples.length).round();
    curSampleIdx = clamp(curSampleIdx, startSample, endSample);
    double curSampleX = (curSampleIdx - startSample) / (endSample - startSample) * size.width;
    List<double> viewSamples = samples.sublist(startSample, endSample);
    List<double> playedSamples = samples.sublist(startSample, curSampleIdx);
    List<double> unplayedSamples = samples.sublist(curSampleIdx, endSample);

    // the denser the view, the lower the opacity
    double samplesPerPixel = viewSamples.length / size.width;
    double opacity;
    if (scaleFactor == 1)
      opacity = (-samplesPerPixel/40+1).clamp(0.1, 1).toDouble();
    else
      opacity = 1;
    Color color = lineColor.withOpacity(opacity);
    Color bwColor = lineInactiveColor.withOpacity(opacity/1.5);
    _paintSamples(canvas, size, playedSamples, color, 0, curSampleX);
    _paintSamples(canvas, size, unplayedSamples, bwColor, curSampleX, size.width);
  }

  double _paintSamples(Canvas canvas, Size size, List<double> samples, Color color, double startX, double endX) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    var height = size.height - 20;
    var path = Path();
    var x = startX;
    var y = height / 2;
    var xStep = (endX - startX) / samples.length;
    var yStep = height;
    path.moveTo(x, y);
    for (var i = 0; i < samples.length; i++) {
      x += xStep;
      y = height / 2 - samples[i] * yStep;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    return x;
  }

  void paintTimeline(Canvas canvas, Size size) {
    double curSampleRel = (curSample - viewStart) / (viewEnd - viewStart);
    double curSampleX = curSampleRel * size.width;
    double playedWidth = curSampleX;

    int bwColorVal = (lineColor.red + lineColor.green + lineColor.blue) ~/ 3;
    Color bwColor = Color.fromARGB(lineColor.alpha, bwColorVal, bwColorVal, bwColorVal);
    _paintTimeline(canvas, size, playedWidth, size.width, bwColor);
    _paintTimeline(canvas, size, 0, playedWidth, lineColor);
  }

  void _paintTimeline(Canvas canvas, Size size, double startX, double endX, Color color) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    var path = Path();
    var startOffset = startX == 0 ? 10 : 0;
    var endOffset = endX == size.width ? -10 : 0;
    path.moveTo(clamp(startX + startOffset, 10, size.width), size.height / 2);
    path.lineTo(clamp(endX + endOffset, 10, size.width), size.height / 2);
    canvas.drawPath(path, paint);
  }

  void paintTimeMarkers(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = textColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    var textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    double viewAreaSec = (viewEnd - viewStart) / samplesPerSec;
    double markersIntervalSec = 1;
    for (var entry in viewWidthMsToMarkerInterval.entries) {
      if (viewAreaSec * 1000 < entry.key) {
        markersIntervalSec = entry.value;
        break;
      }
    }
    int markersIntervalSamples = (markersIntervalSec * samplesPerSec).round();
    int markersStart = (viewStart / markersIntervalSamples).ceil() * markersIntervalSamples;
    int markersEnd = (viewEnd / markersIntervalSamples).floor() * markersIntervalSamples;

    const double fontSize = 12;
    for (int i = markersStart; i <= markersEnd; i += markersIntervalSamples) {
      double x = (i - viewStart) / (viewEnd - viewStart) * size.width;
      if (x.isNaN || x.isInfinite)
        continue;
      // small marker on the bottom
      double yOff = size.height - fontSize;
      canvas.drawLine(Offset(x, yOff - 5), Offset(x, size.height), paint);
      // text to the right
      double totalSecs = i / samplesPerSec;
      String text = formatDuration(Duration(milliseconds: (totalSecs * 1000).round()), true);
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 4, yOff - 3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _WaveformPainter)
      return oldDelegate.viewStart != viewStart
        || oldDelegate.viewEnd != viewEnd
        || oldDelegate.prevSize != prevSize;
    return true;
  }
}


class DurationStream extends StreamBuilder<Duration> {
  final Duration? fallback;
  DurationStream({ super.key, required Stream<Duration>? time, this.fallback }) : super(
    stream: time,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        var pos = snapshot.data!;
        return Text(formatDuration(pos));
      }
      else if (fallback != null)
        return Text(formatDuration(fallback));
      else
        return const Text("00:00");
    }
  );
}
