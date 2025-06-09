
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../fileSystem/FileSystem.dart';
import '../../widgets/theme/customTheme.dart';
import 'RowSeparated.dart';

enum SelectionType { file, folder }

const _typeToWindowTitle = {
  SelectionType.file: "Select file",
  SelectionType.folder: "Select folder",
};

Future<String?> fileSelectionDialog(BuildContext context, {
    required SelectionType selectionType,
    required String title,
    String? body,
    String? initialDirectory,
  }) {
  var result = Completer<String?>();

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
        child: PointerInterceptor(
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: RowSeparated(
                    separatorWidth: 5,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          String? path;
                          if (selectionType == SelectionType.file) {
                            path = (await FS.i.selectFiles(
                              dialogTitle: title,
                              allowMultiple: false,
                              initialDirectory: initialDirectory,
                            )).firstOrNull;
                          } else if (selectionType == SelectionType.folder) {
                            path = await FS.i.selectDirectory(
                              dialogTitle: title,
                              initialDirectory: initialDirectory,
                            );
                          } else {
                            throw "Invalid selection type";
                          }
        
                          if (path != null) {
                            result.complete(path);
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop();
                          }
                        },
                        style: getTheme(context).dialogPrimaryButtonStyle,
                        child: Text(_typeToWindowTitle[selectionType] ?? "Select"),
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
        ),
      )
    ),
  );

  return result.future;
}
