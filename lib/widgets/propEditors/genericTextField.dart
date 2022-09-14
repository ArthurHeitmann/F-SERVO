
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/Property.dart';
import 'HexPropTextField.dart';

Widget genericTextField(BuildContext context, {
  Widget? left,
  String? initText,
  void Function(String)? onChanged
}) {
  return Material(
    // decoration: BoxDecoration(
      color: getTheme(context).formElementBgColor,
      borderRadius: BorderRadius.circular(8.0),
    // ),
    child: Row(
      children: [
        if (left != null)
          left,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextFormField(
              initialValue: initText,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 13
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

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

Widget makePropEditor(Prop prop) {
  switch (prop.type) {
    case PropType.hexInt:
      return HexPropTextField(prop: prop as HexProp);
    default:
      return PropTextField(prop: prop);
  }
}
