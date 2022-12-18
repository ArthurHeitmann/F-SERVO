
import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import 'RowSeparated.dart';
import 'SmoothScrollBuilder.dart';

Future<bool?> confirmDialog(BuildContext context, { required String title, String? body }) {
  var result = Completer<bool?>();
  final ScrollController _scrollController = ScrollController();
  showDialog(
    context: context,
    builder: (context) => WillPopScope(
      onWillPop: () async {
        result.complete(null);
        return true;
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 450),
            child: SmoothSingleChildScrollView(
              controller: _scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headline6),
                  if (body != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodyText2
                    ),
                  ],
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
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
                          child: const Text("Confirm"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            result.complete(false);
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
          ),
        ),
      )
    ),
  );

  return result.future;
}
