
import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import 'propTextField.dart';


class AudioSampleNumberPropTextField<T extends PropTextField> extends StatelessWidget {
  final AudioSampleNumberProp prop;
  final int samplesCount;
  final int samplesPerSecond;
  final PropTFOptions options;

  const AudioSampleNumberPropTextField({
    super.key,
    required this.prop,
    required this.samplesCount,
    required this.samplesPerSecond,
    this.options = const PropTFOptions(),
  });

  String? textValidator(String str) {
    var matches = RegExp(r"(\d+):(\d+)\.(\d+)").firstMatch(str);
    if (matches == null)
      return "Invalid format";
    try {
      int min = int.parse(matches.group(1)!);
      int sec = int.parse(matches.group(2)!);
      int ms = int.parse(matches.group(3)!);
      if (min < 0 || sec < 0 || sec >= 60 || ms < 0 || ms >= 1000)
        return "Invalid format";
      int sample = min * 60 * samplesPerSecond + sec * samplesPerSecond + ms * samplesPerSecond ~/ 1000;
      if (sample < 0 || sample >= samplesCount + 1)
        return "Invalid sample number";
      return null;
    } catch (e) {
      return "Invalid format";
    }
  }

  void onValidUpdateProp(String text) {
    prop.updateWith(text);
  }

  @override
  Widget build(BuildContext context) {
    return PropTextField.make<T>(
      prop: prop,
      options: options,
      validatorOnChange: textValidator,
      onValid: onValidUpdateProp,
    );
  }
}
