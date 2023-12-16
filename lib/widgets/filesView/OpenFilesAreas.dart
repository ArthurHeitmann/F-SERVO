import 'package:flutter/material.dart';

import '../../stateManagement/openFiles/filesAreaManager.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../widgets/ResizableWidget.dart';
import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import 'fileTabView.dart';


class OpenFilesAreas extends ChangeNotifierWidget {
  OpenFilesAreas({super.key})
    : super(notifier: areasManager.areas) {
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

