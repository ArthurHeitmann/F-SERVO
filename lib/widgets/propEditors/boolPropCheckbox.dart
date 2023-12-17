
import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import '../misc/ChangeNotifierWidget.dart';

class BoolPropCheckbox extends ChangeNotifierWidget {
  final ValueProp<bool> prop;
  final MaterialStateProperty<Color>? fillColor;
  final Color? checkColor;
  final bool isDisabled;

  BoolPropCheckbox({
    super.key,
    required this.prop,
    this.fillColor,
    this.checkColor,
    this.isDisabled = false,
  }) : super(notifier: prop);

  @override
  State<BoolPropCheckbox> createState() => _BoolPropSliderState();
}

class _BoolPropSliderState extends ChangeNotifierState<BoolPropCheckbox> {
  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: widget.prop.value,
      onChanged: widget.isDisabled ? null : (value) => widget.prop.value = value!,
      fillColor: widget.fillColor,
      checkColor: widget.checkColor,
    );
  }
}
