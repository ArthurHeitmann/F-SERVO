
import 'package:flutter/material.dart';

import '../../../../fileTypeUtils/effects/estEntryTypes.dart';
import '../../../../stateManagement/openFiles/types/EstFileData.dart';
import '../../../misc/ChangeNotifierWidget.dart';
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
          Text(
            "${entry.entry.header.id} / ${estTypeFullNames[entry.entry.header.id]}",
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          EstEntryDetailsEditor(entry: entry, showUnknown: false),
          const SizedBox(height: 8),
        ]
      ],
    );
  }
}
