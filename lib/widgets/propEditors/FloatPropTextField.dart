
import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import '../../utils/utils.dart';
import 'propTextField.dart';


class FloatPropTextField<T extends PropTextField> extends StatelessWidget {
  final FloatProp prop;
  final PropTFOptions options;
  final Widget? left;

  const FloatPropTextField({
    super.key,
    required this.prop,
    this.options = const PropTFOptions(),
    this.left,
  });

  String? textValidator(String str) {
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
