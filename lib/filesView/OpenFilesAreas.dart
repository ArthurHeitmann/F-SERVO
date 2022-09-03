import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/ResizableWidget.dart';
import 'package:nier_scripts_editor/filesView/fileTabView.dart';
import 'package:nier_scripts_editor/stateManagement/openFilesManager.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';


class OpenFilesAreas extends ChangeNotifierWidget {
  OpenFilesAreas({Key? key})
    : super(key: key, notifier: areasManager) {
    if (areasManager.isEmpty)
      areasManager.add(FilesAreaManager());
  }

  @override
  State<OpenFilesAreas> createState() => _OpenFilesAreasState();
}

class _OpenFilesAreasState extends ChangeNotifierState<OpenFilesAreas> {

  @override
  Widget build(BuildContext context) {

    return Container(
      color: Theme.of(context).backgroundColor,
      child: ResizableWidget(
        axis: Axis.horizontal,
        draggableThickness: 5,
        children: areasManager.map((area) => FileTabView(area)).toList(),
      )
    );
  }
}

