import 'package:flutter/material.dart';

import '../widgets/theme/customTheme.dart';
import 'FileHierarchyExplorer/fileMetaEditor.dart';
import 'filesView/OpenFilesAreas.dart';
import 'FileHierarchyExplorer/FileExplorer.dart';
import 'ResizableWidget.dart';
import 'filesView/XmlPropDetailsEditor.dart';
import 'filesView/outliner.dart';
import 'filesView/searchPanel.dart';
import 'filesView/sidebar.dart';

class EditorLayout extends StatelessWidget {
  const EditorLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResizableWidget(
      axis: Axis.horizontal,
      percentages: const [0.22, 0.53, 0.25],
      draggableThickness: 4,
      lineThickness: 4,
      children: [
        Material(
          color: getTheme(context).sidebarBackgroundColor,
          child: Sidebar(
            entries: [
              SidebarEntryConfig(
                name: "Files",
                icon: Icons.folder,
                child: ResizableWidget(
                  axis: Axis.vertical,
                  percentages: const [0.55, 0.45],
                  draggableThickness: 5,
                  children: [
                    FileExplorer(),
                    FileMetaEditor()
                  ],
                ),
              ),
              SidebarEntryConfig(
                name: "Search",
                icon: Icons.search,
                child: const SearchPanel(),
              )
            ],
          ),
        ),
        OpenFilesAreas(),
        Material(
          color: getTheme(context).sidebarBackgroundColor,
          child: ResizableWidget(
            axis: Axis.vertical,
            percentages: const [0.4, 0.6],
            children: [
              Outliner(),
              XmlPropDetailsEditor(),
            ],
          ),
        ),
      ],
    );
  }
}
