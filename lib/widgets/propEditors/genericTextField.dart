
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/Property.dart';
import 'HexPropTextField.dart';
import 'propTextField.dart';

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

Widget makePropEditor(Prop prop) {
  switch (prop.type) {
    case PropType.hexInt:
      return HexPropTextField(prop: prop as HexProp);
    default:
      return PropTextField(prop: prop);
  }
}
