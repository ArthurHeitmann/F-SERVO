
import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import 'RowSeparated.dart';

Future<String?> textDialog(BuildContext context, { required String title, String? body, bool Function(String)? validator, String? initialValue }) {
  var result = Completer<String?>();
  var controller = TextEditingController(text: initialValue);

  void onSubmit() {
    if (validator != null && !validator(controller.text)) {
      showToast("Invalid input");
      return;
    }
    result.complete(controller.text);
    Navigator.of(context).pop();
  }

  showDialog(
    context: context,
    builder: (context) => WillPopScope(
      onWillPop: () async {
        result.complete(null);
        return true;
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: getTheme(context).sidebarBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headline6),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(body, style: Theme.of(context).textTheme.bodyText2),
              ],
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: RowSeparated(
                  separatorWidth: 5,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        onSubmitted: (_) => onSubmit(),
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          hintText: "Enter text",
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: onSubmit,
                      style: getTheme(context).dialogSecondaryButtonStyle,
                      child: const Text("Confirm"),
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
