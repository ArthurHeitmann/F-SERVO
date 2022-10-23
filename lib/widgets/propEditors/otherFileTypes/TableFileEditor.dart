
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../customXmlProps/tableEditor.dart';

class TableFileEditor extends ChangeNotifierWidget {
  final OpenFileData file;
  final CustomTableConfig Function() getTableConfig;

  TableFileEditor({ super.key, required this.file, required this.getTableConfig }) : super(notifier: file);

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
    return widget.file.loadingState == LoadingState.loaded
      ? TableEditor(config: widget.getTableConfig())
      : Text("Loading...");
  }
}
