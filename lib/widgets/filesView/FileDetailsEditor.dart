

import 'package:flutter/material.dart';

import '../misc/ChangeNotifierWidget.dart';
import '../../stateManagement/openFiles/openFileTypes.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../misc/Selectable.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../propEditors/otherFileTypes/effect/EstEntryDetailsEditor.dart';
import '../propEditors/otherFileTypes/effect/EstRecordDetailsEditor.dart';
import '../propEditors/xmlActions/XmlPropDetails.dart';

class FileDetailsEditor extends ChangeNotifierWidget {
  FileDetailsEditor({super.key})
    : super(notifiers: [selectable.active, areasManager]);

  @override
  State<FileDetailsEditor> createState() => _FileDetailsEditorState();
}

class _FileDetailsEditorState extends ChangeNotifierState<FileDetailsEditor> {
  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    XmlProp? prop = selectable.active.value?.prop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        makeTopRow(),
        const Divider(height: 1),
        Expanded(
          child: SmoothSingleChildScrollView(
            stepSize: 60,
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _notifierBuilders(
                (context) => _getDetailsEditor(prop),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget makeTopRow() {
    return const Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text("PROPERTIES", 
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _notifierBuilders(Widget Function(BuildContext context) builder) {
    return ChangeNotifierBuilder(
      notifier: areasManager.activeArea,
      builder: (context) => ChangeNotifierBuilder(
        key: Key(areasManager.activeArea?.uuid ?? ""),
        notifier: areasManager.activeArea?.currentFile,
        builder: (context) {
          var currentFile = areasManager.activeArea?.currentFile;
          return ChangeNotifierBuilder(
            key: Key(currentFile?.uuid ?? ""),
            notifier: currentFile is EstFileData
              ? currentFile.estData.selectedEntry
              : null,
            builder: builder,
          );
        },
      ),
    );
  }

  Widget _getDetailsEditor(XmlProp? prop) {
    if (prop != null)
      return XmlPropDetails(key: ValueKey(prop), prop: prop);
    var currentFile = areasManager.activeArea?.currentFile;
    if (currentFile is EstFileData) {
      if (currentFile.estData.selectedEntry.value?.record != null)
        return EstRecordDetailsEditor(record: currentFile.estData.selectedEntry.value!.record!);
      if (currentFile.estData.selectedEntry.value?.entry != null)
        return EstEntryDetailsEditor(entry: currentFile.estData.selectedEntry.value!.entry!);
    }
    return Container();
  }
}
