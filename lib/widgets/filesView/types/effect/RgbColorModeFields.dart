
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/preferencesData.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../propEditors/primaryPropTextField.dart';
import '../../../propEditors/propEditorFactory.dart';

class RgbColorModeFields extends ChangeNotifierWidget {
  final VectorProp rgb;
  
  RgbColorModeFields({super.key, required this.rgb}) : super(notifier: rgb);

  @override
  State<RgbColorModeFields> createState() => _RgbColorModeFieldsState();
}

class _RgbColorModeFieldsState extends ChangeNotifierState<RgbColorModeFields> {
  late _ColorMode colorMode;

  @override
  void initState() {
    super.initState();

    var prefs = PreferencesData();
    colorMode = _ColorMode.values[prefs.lastColorPickerMode!.value];
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var compact = constraints.maxWidth < 300;
        return Row(
          children: [
            PopupMenuButton<_ColorMode>(
              initialValue: colorMode,
              onSelected: (v) {
                setState(() => colorMode = v);
                var prefs = PreferencesData();
                prefs.lastColorPickerMode!.value = v.index;
              },
              itemBuilder: (context) => _ColorMode.values.map((e) => PopupMenuItem(
                value: e,
                height: 20,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(e.name)
                ),
              )).toList(),
              position: PopupMenuPosition.under,
              constraints: BoxConstraints.tightFor(width: 60),
              popUpAnimationStyle: AnimationStyle(duration: Duration.zero),
              tooltip: "",
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    colorMode.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            if (colorMode == _ColorMode.raw)
              ...makeRawFields(context, compact)
            else if (colorMode == _ColorMode.rgb)
              ...makeRgbFields(context, compact)
            else if (colorMode == _ColorMode.hex)
              ...makeHexFields(context, compact)
            ,
            if (colorMode != _ColorMode.raw) ...[
              ...makeBrightnessField(context, compact),
            ],
          ],
        );
      }
    );
  }
  
  List<Widget> makeRawFields(BuildContext context, bool compact) {
    return [
      for (int i = 0; i < 3; i++) ...[
        SizedBox(width: compact ? 1 : 5),
        Text("RGB"[i]),
        SizedBox(width: compact ? 1 : 5),
        Flexible(
            child: makePropEditor(widget.rgb[i])
        )
      ]
    ];
  }
  
  List<Widget> makeRgbFields(BuildContext context, bool compact) {
    return [
      for (int i = 0; i < 3; i++) ...[
        SizedBox(width: compact ? 1 : 5),
        Text("RGB"[i]),
        SizedBox(width: compact ? 1 : 5),
        Flexible(
          child: PrimaryPropTextField(
            key: Key(widget.rgb[i].uuid),
            prop: widget.rgb[i],
            validatorOnChange: (str) => double.tryParse(str) == null ? "Invalid number" : null,
            onValid: (str) {
              var brightness = getBrightness();
              widget.rgb[i].value = double.parse(str) / 255 * brightness;
            },
            getDisplayText: () {
              var brightness = getBrightness();
              return (widget.rgb[i].value * 255 / brightness).toString();
            },
          ),
        )
      ]
    ];
  }
  
  List<Widget> makeHexFields(BuildContext context, bool compact) {
    return [
      Flexible(
        child: PrimaryPropTextField(
          key: Key(widget.rgb.uuid),
          prop: widget.rgb,
          validatorOnChange: (str) => RegExp(r"^(#|0x)?[a-fA-F\d]+$").hasMatch(str) ? null : "Invalid hex number",
          onValid: (hexStr) {
            if (hexStr.isNotEmpty && hexStr[0] == "#")
              hexStr = hexStr.substring(1);
            else if (hexStr.length > 2 && hexStr.startsWith("0x"))
              hexStr = hexStr.substring(2);
            var hexInt = int.parse(hexStr, radix: 16);
            var r = (hexInt >> 16) & 0xFF;
            var g = (hexInt >> 8) & 0xFF;
            var b = hexInt & 0xFF;
            var brightness = getBrightness();
            widget.rgb[0].value = r / 255 * brightness;
            widget.rgb[1].value = g / 255 * brightness;
            widget.rgb[2].value = b / 255 * brightness;
          },
          getDisplayText: () {
            var brightness = getBrightness();
            var rgb = widget.rgb
              .map((e) => e.value * 255 ~/ brightness)
              .map((e) => e.toRadixString(16).padLeft(2, "0"));
            return rgb.join();
          },
        ),
      )
    ];
  }

  List<Widget> makeBrightnessField(BuildContext context, bool compact) {
    return [
      SizedBox(width: compact ? 1 : 5),
      Icon(Icons.light_mode, size: 16),
      SizedBox(width: compact ? 1 : 5),
      Flexible(
        child: PrimaryPropTextField(
          prop: widget.rgb,
          validatorOnChange: (str) => double.tryParse(str) == null ? "Invalid number" : null,
          onValid: (str) {
            var prevBrightness = getBrightness();
            var newBrightness = double.parse(str);
            for (var i = 0; i < 3; i++) {
              widget.rgb[i].value = widget.rgb[i].value / prevBrightness * newBrightness;
            }
          },
          getDisplayText: () => getBrightness().toString(),
        ),
      )
    ];
  }

  double getBrightness() {
    var maxVal = widget.rgb
      .map((e) => e.value.toDouble())
      .reduce(max);
    return max(maxVal, 1.0);
  }
}

enum _ColorMode {
  raw,
  rgb,
  hex,
}
