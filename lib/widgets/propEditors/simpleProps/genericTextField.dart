
import 'package:flutter/material.dart';

import '../../../customTheme.dart';

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
