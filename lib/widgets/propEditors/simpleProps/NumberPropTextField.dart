
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../utils.dart';
import 'propTextField.dart';


class NumberPropTextField extends StatelessWidget {
  final NumberProp prop;
  final bool isInteger;
  final BoxConstraints? constraints;
  final Widget? left;

  NumberPropTextField({
    super.key,
    required this.prop,
    this.constraints,
    this.left,
  }) : isInteger = prop.isInteger;

  String? textValidator(String str) {
    if (isInteger)
      return !isInt(str) ? "Not a valid integer" : null;
    else
      return !isDouble(str) ? "Not a valid number" : null;
  }

  void onValidUpdateProp(String text) {
    prop.updateWith(text);
  }

  @override
  Widget build(BuildContext context) {
    return PropTextField(
      prop: prop,
      left: left,
      constraints: constraints,
      validatorOnChange: textValidator,
      onValid: onValidUpdateProp,
    );
  }
}
