
import 'package:flutter/material.dart';

import '../../../../fileTypeUtils/effects/estEntryTypes.dart';
import '../../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../../stateManagement/otherFileTypes/EstFileData.dart';
import 'EstEntryDetailsEditor.dart';

class EstRecordDetailsEditor extends ChangeNotifierWidget {
  final EstRecordWrapper record;

  EstRecordDetailsEditor({super.key, required this.record})
    : super(notifier: record.entries);

  @override
  State<EstRecordDetailsEditor> createState() => _EstRecordDetailsEditorState();
}

class _EstRecordDetailsEditorState extends ChangeNotifierState<EstRecordDetailsEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var entry in widget.record.entries) ...[
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text("${entry.entry.header.id} / ${estTypeFullNames[entry.entry.header.id]}"),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          EstEntryDetailsEditor(entry: entry),
          const SizedBox(height: 8),
        ]
      ],
    );
  }
}
