import 'package:flutter/material.dart';

import 'fileTabView.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../widgets/theme/customTheme.dart';
import '../../widgets/ResizableWidget.dart';


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

    return Material(
      color: getTheme(context).editorBackgroundColor,
      child: ResizableWidget(
        axis: Axis.horizontal,
        draggableThickness: 5,
        children: areasManager.map((area) => 
          FileTabView(area, key: Key(area.uuid))
        ).toList(),
      )
    );
  }
}

