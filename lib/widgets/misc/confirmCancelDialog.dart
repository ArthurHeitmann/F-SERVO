
import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import 'RowSeparated.dart';

Future<bool?> confirmOrCancelDialog(BuildContext context, { required String title, String? body, String yesText = "Yes", String noText = "No" }) {
  var result = Completer<bool?>();

  showDialog(
    context: context,
    builder: (context) => WillPopScope(
      onWillPop: () async {
        result.complete(null);
        return true;
      },
      child: Dialog(
        backgroundColor: getTheme(context).sidebarBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              IntrinsicWidth(
                child: RowSeparated(
                  separatorWidth: 5,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        result.complete(true);
                        Navigator.of(context).pop();
                      },
                      style: getTheme(context).dialogPrimaryButtonStyle,
                      child: Text(yesText),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        result.complete(false);
                        Navigator.of(context).pop();
                      },
                      style: getTheme(context).dialogSecondaryButtonStyle,
                      child: Text(noText),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        result.complete(null);
                        Navigator.of(context).pop();
                      },
                      style: getTheme(context).dialogSecondaryButtonStyle,
                      child: const Text("Cancel"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
    ),
  );

  return result.future;
}
