
import 'package:flutter/material.dart';

import '../../misc/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';

class BoolPropCheckbox extends ChangeNotifierWidget {
  final ValueProp<bool> prop;
  final MaterialStateProperty<Color>? fillColor;
  final Color? checkColor;

  BoolPropCheckbox({
    super.key,
    required this.prop,
    this.fillColor,
    this.checkColor,
  }) : super(notifier: prop);

  @override
  State<BoolPropCheckbox> createState() => _BoolPropSliderState();
}

class _BoolPropSliderState extends ChangeNotifierState<BoolPropCheckbox> {
  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: widget.prop.value,
      onChanged: (value) => widget.prop.value = value!,
      fillColor: widget.fillColor,
      checkColor: widget.checkColor,
    );
  }
}
