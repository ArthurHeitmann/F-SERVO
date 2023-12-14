import 'package:flutter/material.dart';

import '../../stateManagement/openFiles/filesAreaManager.dart';
import 'fileTabView.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../widgets/theme/customTheme.dart';
import '../../widgets/ResizableWidget.dart';


class OpenFilesAreas extends ChangeNotifierWidget {
  OpenFilesAreas({Key? key})
    : super(key: key, notifier: areasManager.areas) {
    if (areasManager.areas.isEmpty)
      areasManager.addArea(FilesAreaManager());
  }

  @override
  State<OpenFilesAreas> createState() => _OpenFilesAreasState();
}

class _OpenFilesAreasState extends ChangeNotifierState<OpenFilesAreas> {

  @override
  Widget build(BuildContext context) {

    return Material(
      color: getTheme(context).editorBackgroundColor,
      child: ResizableWidget(
        axis: Axis.horizontal,
        draggableThickness: 5,
        children: areasManager.areas.map((area) =>
          FileTabView(area, key: Key(area.uuid))
        ).toList(),
      )
    );
  }
}

