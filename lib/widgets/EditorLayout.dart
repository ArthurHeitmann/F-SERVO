import 'package:flutter/material.dart';

import '../customTheme.dart';
import 'FileHierarchyExplorer/fileMetaEditor.dart';
import 'filesView/OpenFilesAreas.dart';
import 'FileHierarchyExplorer/FileExplorer.dart';
import 'ResizableWidget.dart';
import 'filesView/XmlActionDetailsEditor.dart';
import 'filesView/outliner.dart';

class EditorLayout extends StatelessWidget {
  const EditorLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResizableWidget(
      axis: Axis.horizontal,
      percentages: [0.22, 0.53, 0.25],
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
                FileMetaEditor()
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
  }
}
