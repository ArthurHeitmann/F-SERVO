

import 'package:flutter/material.dart';

import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../stateManagement/openFiles/types/EstFileData.dart';
import '../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/Selectable.dart';
import '../misc/SmoothScrollBuilder.dart';
import 'types/effect/EstEntryDetailsEditor.dart';
import 'types/effect/EstRecordDetailsEditor.dart';
import 'types/xml/xmlActions/XmlPropDetails.dart';

class FileDetailsEditor extends ChangeNotifierWidget {
  FileDetailsEditor({super.key})
    : super(notifiers: [selectable.active, areasManager.activeArea]);

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
        key: Key(areasManager.activeArea.value?.uuid ?? ""),
        notifier: areasManager.activeArea.value?.currentFile,
        builder: (context) {
          var currentFile = areasManager.activeArea.value?.currentFile.value;
          return ChangeNotifierBuilder(
            key: Key(currentFile?.uuid ?? ""),
            notifier: currentFile is EstFileData
              ? currentFile.selectedEntry
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
    var currentFile = areasManager.activeArea.value?.currentFile.value;
    if (currentFile is EstFileData) {
      if (currentFile.selectedEntry.value?.record != null)
        return EstRecordDetailsEditor(record: currentFile.selectedEntry.value!.record!);
      if (currentFile.selectedEntry.value?.entry != null)
        return EstEntryDetailsEditor(entry: currentFile.selectedEntry.value!.entry!);
    }
    return Container();
  }
}
