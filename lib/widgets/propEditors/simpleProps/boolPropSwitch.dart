
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';

class BoolPropSwitch extends ChangeNotifierWidget {
  final ValueProp<bool> prop;

  BoolPropSwitch({super.key, required this.prop}) : super(notifier: prop);

  @override
  State<BoolPropSwitch> createState() => _BoolPropSliderState();
}

class _BoolPropSliderState extends ChangeNotifierState<BoolPropSwitch> {
  @override
  Widget build(BuildContext context) {
    return Switch(
      value: widget.prop.value,
      onChanged: (value) => widget.prop.value = value,
    );
  }
}
