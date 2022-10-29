
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../utils/utils.dart';
import 'propTextField.dart';


class NumberPropTextField<T extends PropTextField> extends StatelessWidget {
  final NumberProp prop;
  final bool isInteger;
  final PropTFOptions options;
  final Widget? left;

  NumberPropTextField({
    super.key,
    required this.prop,
    this.options = const PropTFOptions(),
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
    return PropTextField.make<T>(
      prop: prop,
      left: left,
      options: options,
      validatorOnChange: textValidator,
      onValid: onValidUpdateProp,
    );
  }
}
