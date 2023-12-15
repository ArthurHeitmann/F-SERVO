
import 'package:flutter/material.dart';

import '../../../../stateManagement/openFiles/openFileTypes.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import 'tableEditor.dart';

class TableFileEditor extends ChangeNotifierWidget {
  final OpenFileData file;
  final CustomTableConfig Function() getTableConfig;

  TableFileEditor({ super.key, required this.file, required this.getTableConfig }) : super(notifier: file.loadingState);

  @override
  State<TableFileEditor> createState() => _TableFileEditorState();
}

class _TableFileEditorState extends ChangeNotifierState<TableFileEditor> {
  @override
  void initState() {
    widget.file.load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.file.loadingState.value == LoadingState.loaded
      ? TableEditor(config: widget.getTableConfig())
      : const Column(
        children: [
          SizedBox(height: 35),
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          ),
        ],
    );
  }
}
