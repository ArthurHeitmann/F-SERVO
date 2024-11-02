
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../utils/utils.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import 'RgbColorModeFields.dart';

class ColorPicker extends ChangeNotifierWidget {
  final VectorProp rgb;
  final bool showTextFields;

  ColorPicker({super.key, required this.rgb, required this.showTextFields}) : super(notifier: rgb);

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends ChangeNotifierState<ColorPicker> {
  late final double svAreaHeight;
  double desiredHue = 0.0;
  double desiredSaturation = 0.0;

  @override
  void initState() {
    super.initState();
    svAreaHeight = 200 - 25 - (widget.showTextFields ? 40 : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: svAreaHeight,
          child: GestureDetector(
            onPanStart: (details) => onSvDrag(details.localPosition),
            onPanUpdate: (details) => onSvDrag(details.localPosition),
            child: CustomPaint(
              painter: _SvPainter(widget.rgb, desiredHue, desiredSaturation),
            ),
          ),
        ),
        GestureDetector(
          onPanStart: (details) => onHueDrag(details.localPosition),
          onPanUpdate: (details) => onHueDrag(details.localPosition),
          child: Container(
            height: 25,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: CustomPaint(
              painter: _HuePainter(widget.rgb, desiredHue),
            ),
          ),
        ),
        if (widget.showTextFields)
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: RgbColorModeFields(rgb: widget.rgb),
          ),
      ],
    );
  }

  void onHueDrag(Offset pos) {
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var hue = clamp(pos.dx / size.width, 0.0, 0.999);
    var sat = _rgbToSaturation(widget.rgb.map((e) => e.value.toDouble()).toList());
    var val = _rgbToValue(widget.rgb.map((e) => e.value.toDouble()).toList());
    var rgb = _hsvToRgb(hue, sat, val);
    var oldRgb = widget.rgb.map((e) => e.value.toDouble()).toList();
    var brightness = _scaleFactor(oldRgb);
    for (var i = 0; i < 3; i++) {
      widget.rgb[i].value = rgb[i] * brightness;
    }
    desiredHue = hue;
    setState(() {});
  }

  void onSvDrag(Offset pos) {
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var sat = clamp(pos.dx / size.width, 0.0, 1.0);
    var val = 1.0 - clamp(pos.dy / svAreaHeight, 0.0, 1.0);
    var hue = _rgbToHue(widget.rgb.map((e) => e.value.toDouble()).toList());
    var oldRgb = widget.rgb.map((e) => e.value.toDouble()).toList();
    hue = _hueOrDesired(hue, _rgbToSaturation(oldRgb), _rgbToValue(oldRgb), desiredHue);
    var rgb = _hsvToRgb(hue, sat, val);
    var brightness = _scaleFactor(oldRgb);
    var newTempBrightness = rgb.reduce(max);
    var brightnessFactor = brightness > 1 && val > 0.9 && newTempBrightness > 0 ? brightness / newTempBrightness : 1;
    for (var i = 0; i < 3; i++) {
      widget.rgb[i].value = rgb[i] * brightnessFactor;
    }
    desiredSaturation = sat;
    setState(() {});
  }
}

class _HuePainter extends CustomPainter {
  final VectorProp rgb;
  final double desiredHue;
  double lastHue = -1;

  _HuePainter(this.rgb, this.desiredHue);

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      (0, Color.fromARGB(255, 255, 0, 0)),
      (60, Color.fromARGB(255, 255, 255, 0)),
      (120, Color.fromARGB(255, 0, 255, 0)),
      (180, Color.fromARGB(255, 0, 255, 255)),
      (240, Color.fromARGB(255, 0, 0, 255)),
      (300, Color.fromARGB(255, 255, 0, 255)),
      (360, Color.fromARGB(255, 255, 0, 0)),
    ];

    const barHeight = 10.0;
    var centerRect = Rect.fromLTWH(0, (size.height - barHeight) / 2, size.width, barHeight);

    var gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: colors.map((e) => e.$2).toList(),
        stops: colors.map((e) => e.$1 / 360).toList(),
      ).createShader(centerRect);

    canvas.drawRect(centerRect, gradientPaint);

    var hue = _getHue();
    var rgbHue = _hueToRgb(hue).map((e) => (e * 255).round()).toList();
    var radius = size.height / 2 - 2;
    var circleOffset = Offset(hue * size.width, size.height / 2);
    canvas.drawCircle(
      circleOffset,
      radius + 2,
      Paint()..color = Colors.white
    );
    canvas.drawCircle(
      circleOffset,
      radius,
      Paint()..color = Color.fromARGB(255, rgbHue[0], rgbHue[1], rgbHue[2])
    );


    lastHue = hue;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => _getHue() != lastHue;

  double _getHue() {
    var rgb = this.rgb.map((e) => e.value.toDouble()).toList();
    var hue = _hueOrDesired(_rgbToHue(rgb), _rgbToSaturation(rgb), _rgbToValue(rgb), desiredHue);
    return hue;
  }
}

class _SvPainter extends CustomPainter {
  final VectorProp rgb;
  final double desiredHue;
  final double desiredSaturation;
  String lastValue = "";

  _SvPainter(this.rgb, this.desiredHue, this.desiredSaturation);

  @override
  void paint(Canvas canvas, Size size) {
    var rgb = this.rgb.map((e) => e.value.toDouble()).toList();
    var scale = _scaleFactor(rgb);
    rgb = rgb.map((e) => e / scale).toList();
    var hue = _hueOrDesired(_rgbToHue(rgb), _rgbToSaturation(rgb), _rgbToValue(rgb), desiredHue);
    var hueRgb = _hueToRgb(hue).map((e) => (e * 255).round()).toList();
    var rect = Rect.fromLTWH(0, 0, size.width, size.height);
    var whiteHueGradient = LinearGradient(
      colors: [
        Colors.white,
        Color.fromARGB(255, hueRgb[0], hueRgb[1], hueRgb[2]),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(rect);
    var blackMaskGradient = LinearGradient(
      colors: [
        Colors.white,
        Colors.black,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(rect);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = whiteHueGradient
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = blackMaskGradient
        ..blendMode = BlendMode.multiply
    );

    var value = _rgbToValue(rgb);
    var saturation = _saturationOrDesired(_rgbToSaturation(rgb), value, desiredSaturation);
    var circleOffset = Offset(saturation * size.width, (1 - value) * size.height);
    var radius = 10.5;
    canvas.drawCircle(
      circleOffset,
      radius,
      Paint()..color = Colors.white
    );
    var rgb255 = rgb.map((e) => (e * 255).round()).toList();
    canvas.drawCircle(
      circleOffset,
      radius - 2,
      Paint()..color = Color.fromARGB(255, rgb255[0], rgb255[1], rgb255[2])
    );

    lastValue = this.rgb.toString();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => rgb.toString() != lastValue;
}

double _rgbToHue(List<double> rgb) {
  var scale = _scaleFactor(rgb);
  rgb = rgb.map((e) => e / scale).toList();
  var maxVal = rgb.reduce(max);
  var minVal = rgb.reduce(min);
  var delta = maxVal - minVal;
  if (delta == 0) {
    return 0;
  }
  var hue = 0.0;
  if (maxVal == rgb[0]) {
    hue = (rgb[1] - rgb[2]) / delta;
  } else if (maxVal == rgb[1]) {
    hue = 2 + (rgb[2] - rgb[0]) / delta;
  } else {
    hue = 4 + (rgb[0] - rgb[1]) / delta;
  }
  hue *= 60;
  if (hue < 0) {
    hue += 360;
  }
  return hue / 360;
}

double _rgbToSaturation(List<double> rgb) {
  var maxVal = rgb.reduce(max);
  var minVal = rgb.reduce(min);
  if (maxVal == 0) {
    return 0;
  }
  return (maxVal - minVal) / maxVal;
}

double _rgbToValue(List<double> rgb) {
  var scale = _scaleFactor(rgb);
  return rgb.reduce(max) / scale;
}

List<double> _hueToRgb(double h) {
    var kr = (5 + h * 6) % 6;
    var kg = (3 + h * 6) % 6;
    var kb = (1 + h * 6) % 6;

    var r = 1.0 - max(min(min(kr, 4-kr), 1), 0);
    var g = 1.0 - max(min(min(kg, 4-kg), 1), 0);
    var b = 1.0 - max(min(min(kb, 4-kb), 1), 0);

    return [r, g, b];
}

List<double> _hsvToRgb(double h, double s, double v) {
  double r, g, b;

  var i = (h * 6).floor();
  double f = h * 6 - i;
  double p = v * (1 - s);
  double q = v * (1 - f * s);
  double t = v * (1 - (1 - f) * s);

  switch(i % 6){
    case 0: r = v; g = t; b = p; break;
    case 1: r = q; g = v; b = p; break;
    case 2: r = p; g = v; b = t; break;
    case 3: r = p; g = q; b = v; break;
    case 4: r = t; g = p; b = v; break;
    case 5: r = v; g = p; b = q; break;
    default: r = 0; g = 0; b = 0; break;
  }

  return [r, g, b];
}

double _hueOrDesired(double hue, double sat, double val, double desiredHue) {
  if (hue == 0 && desiredHue != 0 && (sat == 0 || val == 0)) {
    return desiredHue;
  }
  return hue;
}

double _saturationOrDesired(double sat, double val, double desiredSaturation) {
  if (sat == 0 && desiredSaturation != 0 && val == 0) {
    return desiredSaturation;
  }
  return sat;
}

double _scaleFactor(Iterable<double> rgb) {
  var maxVal = rgb.reduce(max);
  return max(maxVal, 1.0);
}
