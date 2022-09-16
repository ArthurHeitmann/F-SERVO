
import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import 'genericTextField.dart';

class PropTextField<P extends Prop> extends StatelessWidget {
  final P prop;
  final Widget? left;
  final bool Function(String str)? validator;
  final VoidCallback? onInvalid;

  const PropTextField({super.key, required this.prop, this.left, this.validator, this.onInvalid});

  @override
  Widget build(BuildContext context) {
    return genericTextField(context,
      left: left,
      onChanged: (str) {
        if (validator != null) {
          if (validator!(str))
            prop.updateWith(str);
          else
            onInvalid?.call();
        }
        else
          prop.updateWith(str);
      },
      initText: prop.toString(),
    );
  }
}