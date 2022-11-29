

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/nestedNotifier.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../utils/utils.dart';
import '../../misc/FlexReorderable.dart';
import '../../misc/debugContainer.dart';
import '../../misc/mousePosition.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/AudioSampleNumberPropTextField.dart';
import '../simpleProps/UnderlinePropTextField.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';

class AudioFileEditor extends StatefulWidget {
  final AudioFileData file;

  const AudioFileEditor({ super.key, required this.file });

  @override
  State<AudioFileEditor> createState() => _AudioFileEditorState();
}

class _AudioFileEditorState extends State<AudioFileEditor> {
  late final AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    widget.file.load().then((_) {
      _player!.setSourceDeviceFile(widget.file.audioFilePath!);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _player!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          if (widget.file.audioFilePath != null) ...[
            _TimelineEditor(
              file: widget.file,
              player: _player,
            ),
            const SizedBox(height: 30),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder(
                stream: _player?.onPlayerStateChanged,
                builder: (context, snapshot) {
                  return IconButton(
                    icon: _player?.state == PlayerState.playing
                      ? const Icon(Icons.pause)
                      : const Icon(Icons.play_arrow),
                    onPressed: _player?.state == PlayerState.playing
                      ? _player?.pause
                      : _player?.resume,
                  );
                }
              ),
              DurationStream(
                time: _player?.onPositionChanged,
              ),
              const Text("/"),
              DurationStream(
                time: _player?.onDurationChanged,
              ),
              const Expanded(child: SizedBox(),),
              _CuePointsEditor(
                cuePoints: widget.file.cuePoints,
                file: widget.file,
              ),  
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineEditor extends ChangeNotifierWidget {
  final AudioFileData file;
  final AudioPlayer? player;

  _TimelineEditor({ super.key, required this.file, required this.player }) : super(notifier: file.cuePoints);

  @override
  State<_TimelineEditor> createState() => __TimelineEditorState();
}

class __TimelineEditorState extends ChangeNotifierState<_TimelineEditor> {
  int _currentPosition = 0;
  late StreamSubscription<Duration> updateSub;
  final ValueNotifier<int> _viewStart = ValueNotifier(0);
  final ValueNotifier<int> _viewEnd = ValueNotifier(0);

  @override
  void initState() {
    _viewEnd.value = widget.file.totalSamples;
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
            onPointerSignal: _onPointerSignal,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _onTimelineTap,
                    onHorizontalDragUpdate: _onHorizontalDragUpdate,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        samples: widget.file.wavSamples!,
                        viewStart: _viewStart.value,
                        viewEnd: _viewEnd.value,
                        totalSamples: widget.file.totalSamples,
                        curSample: _currentPosition,
                        samplesPerSec: widget.file.samplesPerSec,
                        lineColor: Theme.of(context).colorScheme.primary,
                        textColor: getTheme(context).textColor!.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                for (var cuePoint in widget.file.cuePoints)
                  ChangeNotifierBuilder(
                    key: Key(cuePoint.uuid),
                    notifiers: [cuePoint.sample, cuePoint.name],
                    builder: (context) => Positioned(
                      left: (cuePoint.sample.value - _viewStart.value) / (_viewEnd.value - _viewStart.value) * constraints.maxWidth - 8,
                      top: 0,
                      bottom: 0,
                      child: _CuePointMarker(
                        cuePoint: cuePoint,
                        viewStart: _viewStart,
                        viewEnd: _viewEnd,
                        totalSamples: widget.file.totalSamples,
                        samplesPerSec: widget.file.samplesPerSec,
                        parentWidth: constraints.maxWidth,
                        onDrag: _onCuePointDrag,
                      ),
                    ),
                  ),
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
    setState(() => _currentPosition = event.inMicroseconds * widget.file.samplesPerSec ~/ 1000000);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent)
      return;
    double delta = event.scrollDelta.dy;
    var viewStart = _viewStart.value;
    var viewEnd = _viewEnd.value;
    int viewArea = viewEnd - viewStart;
    // zoom in/out by 10% of the view area
    if (delta < 0) {
      _viewStart.value = max((viewStart + viewArea * 0.1).round(), 0);
      _viewEnd.value = min((viewEnd - viewArea * 0.1).round(), widget.file.totalSamples);
    } else {
      _viewStart.value = max((viewStart - viewArea * 0.1).round(), 0);
      _viewEnd.value= min((viewEnd + viewArea * 0.1).round(), widget.file.totalSamples);
    }
    setState(() {});
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    var totalViewWidth = context.size!.width;
    int viewArea = _viewEnd.value - _viewStart.value;
    int delta = (details.delta.dx / totalViewWidth * viewArea).round();
    if (delta > 0) {
      int maxChange = _viewStart.value;
      delta = min(delta, maxChange);
    } else {
      int maxChange = widget.file.totalSamples - _viewEnd.value;
      delta = max(delta, -maxChange);
    }
    _viewStart.value -= delta;
    _viewEnd.value -= delta;
    setState(() {});
  }

  void _onTimelineTap() {
    var renderBox = context.findRenderObject() as RenderBox;
    var locTapPos = renderBox.globalToLocal(MousePosition.pos);
    var xPos = locTapPos.dx;
    double relX = xPos / context.size!.width;
    int viewArea = _viewEnd.value - _viewStart.value;
    int newPosition = (_viewStart.value + relX * viewArea).round();
    _currentPosition = clamp(newPosition, 0, widget.file.totalSamples);
    widget.player!.seek(Duration(microseconds: _currentPosition * 1000000 ~/ widget.file.samplesPerSec));
  }

  void _onCuePointDrag(double xPos, CuePointMarker cuePoint) {
    var renderBox = context.findRenderObject() as RenderBox;
    var localPos = renderBox.globalToLocal(Offset(xPos, 0));
    int viewArea = _viewEnd.value - _viewStart.value;
    int sample = (localPos.dx / context.size!.width * viewArea + _viewStart.value).round();
    sample = clamp(sample, 0, widget.file.totalSamples);
    cuePoint.sample.value = sample;
    setState(() {});
  }
}

class _WaveformPainter extends CustomPainter {
  final List<int> samples;
  final int viewStart;
  final int viewEnd;
  final int totalSamples;
  final int curSample;
  final int samplesPerSec;
  final Color lineColor;
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
    required this.lineColor, required this.textColor
  });

  @override
  void paint(Canvas canvas, Size size) {
    prevSize = size;
    paintWaveform(canvas, size);
    paintTimeMarkers(canvas, size);
  }
  
  void paintWaveform(Canvas canvas, Size size) {
    // only show samples that are in the view up to pixel resolution
    double viewStartRel = viewStart / totalSamples;
    double viewEndRel = viewEnd / totalSamples;
    double curSampleRel = curSample / totalSamples;
    int startSample = (viewStartRel * samples.length).round();
    int endSample = (viewEndRel * samples.length).round();
    int curSampleIdx = (curSampleRel * samples.length).round();
    curSampleIdx = clamp(curSampleIdx, startSample, endSample);
    double curSampleX = (curSampleIdx - startSample) / (endSample - startSample) * size.width;
    List<int> viewSamples = samples.sublist(startSample, endSample);
    List<int> playedSamples = samples.sublist(startSample, curSampleIdx);
    List<int> unplayedSamples = samples.sublist(curSampleIdx, endSample);

    // the denser the view, the lower the opacity
    double samplesPerPixel = viewSamples.length / size.width;
    double fac = 1.2;
    double opacity = (pow(fac, -samplesPerPixel) * fac*2).clamp(0.1, 1).toDouble();
    Color color = lineColor.withOpacity(opacity);
    int bwColorVal = (color.red + color.green + color.blue) ~/ 3;
    Color bwColor = Color.fromARGB(color.alpha, bwColorVal, bwColorVal, bwColorVal);
    _paintSamples(canvas, size, playedSamples, color, 0, curSampleX);
    _paintSamples(canvas, size, unplayedSamples, bwColor, curSampleX, size.width);
  }

  double _paintSamples(Canvas canvas, Size size, List<int> samples, Color color, double startX, double endX) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    var height = size.height - 20;
    var path = Path();
    var x = startX;
    var y = height / 2;
    var xStep = (endX - startX) / samples.length;
    var yStep = height / (0x7FFF * 1.25);
    path.moveTo(x, y);
    for (var i = 0; i < samples.length; i++) {
      x += xStep;
      y = height / 2 - samples[i] * yStep;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    return x;
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
      // small marker on the bottom
      double yOff = size.height - fontSize;
      canvas.drawLine(Offset(x, yOff - 5), Offset(x, size.height), paint);
      // text to the right
      double totalSecs = i / samplesPerSec;
      int minutes = totalSecs ~/ 60;
      double seconds = totalSecs % 60;
      String minStr = minutes.toString().padLeft(2, '0');
      String secIntStr = seconds.floor().toString().padLeft(2, '0');
      String secDecStr = (seconds % 1 * 100).round().toString().padLeft(2, '0');
      String text = "$minStr:$secIntStr.$secDecStr";
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

class _CurrentPositionMarker extends StatefulWidget {
  final void Function(double delta) onDrag;
  final Stream<Duration> positionChangeStream;

  const _CurrentPositionMarker({ super.key, required this.onDrag, required this.positionChangeStream });

  @override
  State<_CurrentPositionMarker> createState() => _CurrentPositionMarkerState();
}

class _CurrentPositionMarkerState extends State<_CurrentPositionMarker> {
  late final StreamSubscription<Duration> _positionChangeSubscription;

  @override
  void initState() {
    super.initState();
    _positionChangeSubscription = widget.positionChangeStream.listen((position) {
      print("position changed: $position");
      setState(() {});
    });
  }

  @override
  void dispose() {
    _positionChangeSubscription.cancel();
    MousePosition.removeDragListener(_onDrag);
    MousePosition.removeDragEndListener(_onDragEnd);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DebugContainer(
      child: GestureDetector(
        onPanStart: (_) {
          MousePosition.addDragListener(_onDrag);
          MousePosition.addDragEndListener(_onDragEnd);
        },
        behavior: HitTestBehavior.translucent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: 2,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }

  void _onDrag(Offset pos) {
    print("drag $pos");
    var renderBox = context.findRenderObject() as RenderBox;
    var localPos = renderBox.globalToLocal(pos);
    widget.onDrag(localPos.dx);
  }

  void _onDragEnd() {
    MousePosition.removeDragListener(_onDrag);
    MousePosition.removeDragEndListener(_onDragEnd);
  }
}

class _CuePointMarker extends ChangeNotifierWidget {
  final CuePointMarker cuePoint;
  final ValueNotifier<int> viewStart;
  final ValueNotifier<int> viewEnd;
  final int totalSamples;
  final int samplesPerSec;
  final double parentWidth;
  final void Function(double xPos, CuePointMarker cuePoint) onDrag;

  _CuePointMarker({
    super.key, required this.cuePoint,
    required this.viewStart, required this.viewEnd,
    required this.totalSamples, required this.samplesPerSec,
    required this.parentWidth, required this.onDrag,
  }) : super(notifiers: [viewStart, viewEnd, cuePoint.sample]);

  @override
  State<_CuePointMarker> createState() => __CuePointMarkerState();
}

class __CuePointMarkerState extends ChangeNotifierState<_CuePointMarker> {
  bool isHovered = false;

  @override
  void dispose() {
    MousePosition.removeDragListener(_onDrag);
    MousePosition.removeDragEndListener(_onDragEnd);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!between(widget.cuePoint.sample.value, widget.viewStart.value, widget.viewEnd.value))
      return const SizedBox.shrink();
    
    const double leftPadding = 8;
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Stack(
        children: [
          // marker
          Transform.translate(
            offset: const Offset(-17, -21.5),
            child: Icon(
              Icons.arrow_drop_down_rounded,
              color: Theme.of(context).colorScheme.secondary,
              size: 50,
            ),
          ),
          // line
          Transform.translate(
            offset: const Offset(0, 0),
            child: GestureDetector(
              onPanStart: (_) {
                MousePosition.addDragListener(_onDrag);
                MousePosition.addDragEndListener(_onDragEnd);
              },
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: leftPadding),
                child: Container(
                  width: 2,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ),
          // text
          if (isHovered)
            Transform.translate(
              offset: const Offset(leftPadding * 2, -leftPadding * .2),
              child: makePropEditor<UnderlinePropTextField>(widget.cuePoint.name)
            ),
        ],
      ),
    );
  }

  void _onDrag(Offset pos) {
    widget.onDrag(pos.dx, widget.cuePoint);
  }

  void _onDragEnd() {
    MousePosition.removeDragListener(_onDrag);
    MousePosition.removeDragEndListener(_onDragEnd);
  }
}

class DurationStream extends StreamBuilder<Duration> {
  DurationStream({ super.key, required Stream<Duration>? time }) : super(
    stream: time,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        var pos = snapshot.data!;
        var mins = pos.inMinutes.toString().padLeft(2, "0");
        var secs = (pos.inSeconds % 60).toString().padLeft(2, "0");
        return Text("$mins:$secs");
      } else {
        return const Text("00:00");
      }
    }
  );
}

class _CuePointsEditor extends ChangeNotifierWidget {
  final NestedNotifier<CuePointMarker> cuePoints;
  final AudioFileData file;

  _CuePointsEditor({ super.key, required this.cuePoints, required this.file }) : super(notifier: cuePoints);

  @override
  State<_CuePointsEditor> createState() => __CuePointsEditorState();
}

class __CuePointsEditorState extends ChangeNotifierState<_CuePointsEditor> {
  @override
  Widget build(BuildContext context) {
    return ColumnReorderable(
      crossAxisAlignment: CrossAxisAlignment.start,
      onReorder: widget.cuePoints.move,
      header: Row(
        children: [
          const SizedBox(
            width: 170,
            child: Text("Time", textAlign: TextAlign.center, textScaleFactor: 0.9, style: TextStyle(fontFamily: "FiraCode"),),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 150,
            child: Text("Cue Point Name", textAlign: TextAlign.center, textScaleFactor: 0.9, style: TextStyle(fontFamily: "FiraCode"),),
          ),
          IconButton(
            onPressed: _copyToClipboard,
            iconSize: 14,
            splashRadius: 18,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            onPressed: _pasteFromClipboard,
            iconSize: 14,
            splashRadius: 18,
            icon: const Icon(Icons.paste),
          ),
        ],
      ),
      footer: Row(
        children: [
          const SizedBox(width: 170 + 8 + 150 + 27),
          IconButton(
            onPressed: () {
              widget.cuePoints.add(CuePointMarker(
                AudioSampleNumberProp(0, widget.file.samplesPerSec),
                StringProp("Marker ${widget.cuePoints.length + 1}"),
                widget.file.uuid
              ));
            },
            iconSize: 20,
            splashRadius: 18,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      children: widget.cuePoints.map((p) => ChangeNotifierBuilder(
        key: Key(p.uuid),
        notifier: p.sample,
        builder: (context) {
          return Row(
            children: [
              IconButton(
                onPressed: () => p.sample.value = 0,
                color: p.sample.value == 0 ? Theme.of(context).colorScheme.secondary.withOpacity(0.75) : null,
                splashRadius: 18,
                icon: const Icon(Icons.arrow_left),
              ),
              AudioSampleNumberPropTextField<UnderlinePropTextField>(
                prop: p.sample,
                samplesCount: widget.file.totalSamples,
                samplesPerSecond: widget.file.samplesPerSec,
                options: const PropTFOptions(
                  hintText: "sample",
                  constraints: BoxConstraints.tightFor(width: 90),
                  useIntrinsicWidth: false,
                ),
              ),
              IconButton(
                onPressed: () => p.sample.value = widget.file.totalSamples,
                color: p.sample.value == widget.file.totalSamples ? Theme.of(context).colorScheme.secondary.withOpacity(0.75) : null,
                splashRadius: 18,
                icon: const Icon(Icons.arrow_right),
              ),
              const SizedBox(width: 8),
              makePropEditor<UnderlinePropTextField>(p.name, const PropTFOptions(
                hintText: "name",
                constraints: BoxConstraints(minWidth: 150),
              )),
              IconButton(
                onPressed: () => widget.cuePoints.remove(p),
                iconSize: 16,
                splashRadius: 18,
                icon: const Icon(Icons.close),
              ),
              const FlexDraggableHandle(
                child: Icon(Icons.drag_handle, size: 16),
              )
            ],
          );
        }
      )).toList(),
    );
  }

  void _copyToClipboard() {
    var cuePointsList = widget.cuePoints.map((e) => {
      "sample": e.sample.value,
      "name": e.name.value,
    }).toList();
    var data = {
      "samplesPerSec": widget.file.samplesPerSec,
      "cuePoints": cuePointsList,
    };
    copyToClipboard(const JsonEncoder.withIndent("\t").convert(data));
    showToast("Copied ${cuePointsList.length} cue points to clipboard");
  }

  void _pasteFromClipboard() async {
    var data = await getClipboardText();
    if (data == null)
      return;
    try {
      var json = jsonDecode(data);
      var sampleRate = json["samplesPerSec"];
      if (sampleRate is! int)
        throw Exception("Invalid sample rate $sampleRate");
      var sampleScale = widget.file.samplesPerSec / sampleRate;
      var cuePoints = (json["cuePoints"] as List).map((e) {
        var sample = e["sample"];
        var name = e["name"];
        if (sample is! int || name is! String)
          throw Exception("Invalid cue point $e");
        sample = (sample * sampleScale).round();
        sample = clamp(sample, 0, widget.file.totalSamples);
        return CuePointMarker(
          AudioSampleNumberProp(sample, widget.file.samplesPerSec),
          StringProp(name),
          widget.file.uuid
        );
      }).whereType<CuePointMarker>().toList();
      widget.cuePoints.addAll(cuePoints);
    } catch (e) {
      showToast("Invalid Clipboard Data");
      rethrow;
    }
  }
}
