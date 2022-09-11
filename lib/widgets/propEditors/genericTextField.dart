
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/Property.dart';

Widget GenericTextField(BuildContext context, {
  String? initText,
  void Function(String)? onChanged
}) {
  return Container(
    decoration: BoxDecoration(
      color: getTheme(context).textFieldBgColor,
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: TextFormField(
      initialValue: initText,
      onChanged: onChanged,
    ),
  );
}

Widget PropTextField(BuildContext context, Prop prop) {
  return GenericTextField(context,
    onChanged: (str) => prop.updateWith(str),
    initText: prop.toString(),
  );
}
