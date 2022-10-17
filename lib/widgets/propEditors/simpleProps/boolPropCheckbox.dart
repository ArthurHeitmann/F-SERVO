
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';

class BoolPropCheckbox extends ChangeNotifierWidget {
  final ValueProp<bool> prop;

  BoolPropCheckbox({super.key, required this.prop}) : super(notifier: prop);

  @override
  State<BoolPropCheckbox> createState() => _BoolPropSliderState();
}

class _BoolPropSliderState extends ChangeNotifierState<BoolPropCheckbox> {
  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: widget.prop.value,
      onChanged: (value) => widget.prop.value = value!,
    );
  }
}
