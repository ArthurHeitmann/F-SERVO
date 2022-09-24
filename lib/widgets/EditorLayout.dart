import 'package:flutter/material.dart';

import '../customTheme.dart';
import 'FileHierarchyExplorer/groupEditor.dart';
import 'filesView/OpenFilesAreas.dart';
import 'FileHierarchyExplorer/FileExplorer.dart';
import 'ResizableWidget.dart';
import 'filesView/XmlActionDetailsEditor.dart';
import 'filesView/outliner.dart';

class EditorLayout extends StatelessWidget {
  const EditorLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return ResizableWidget(
        axis: Axis.horizontal,
        percentages: [0.175, 0.65, 0.175],
        draggableThickness: 4,
        lineThickness: 4,
        children: [
          Container(
            color: getTheme(context).sidebarBackgroundColor,
            child: Material(
              child: ResizableWidget(
                axis: Axis.vertical,
                percentages: [0.55, 0.45],
                draggableThickness: 5,
                children: [
                  FileExplorer(),
                  GroupEditor()
                ],
              ),
            ),
          ),
          OpenFilesAreas(),
          Container(
            color: getTheme(context).sidebarBackgroundColor,
            child: Material(
              child: ResizableWidget(
                axis: Axis.vertical,
                percentages: [0.4, 0.6],
                children: [
                  Outliner(),
                  XmlActionDetailsEditor(),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
