
import 'dart:async';

import 'package:flutter/material.dart';

Future<bool> confirmDialog(BuildContext context, { required String title, String? body }) {
  var result = Completer<bool>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: body != null ? Text(body) : null,
      actions: [
        TextButton(
          child: Text("Cancel"),
          onPressed: () {
            result.complete(false);
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text("OK"),
          onPressed: () {
            result.complete(true);
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );

  return result.future;
}
