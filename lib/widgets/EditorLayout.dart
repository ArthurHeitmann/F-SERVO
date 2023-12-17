import 'package:flutter/material.dart';

import 'FileHierarchyExplorer/FileExplorer.dart';
import 'FileHierarchyExplorer/fileMetaEditor.dart';
import 'filesView/OpenFilesAreas.dart';
import 'layout/rightSidebar.dart';
import 'layout/searchPanel.dart';
import 'layout/sidebar.dart';
import 'misc/ResizableWidget.dart';

class EditorLayout extends StatelessWidget {
  const EditorLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Sidebar(
          initialWidth: MediaQuery.of(context).size.width * 0.22,
          entries: [
            SidebarEntryConfig(
              name: "Files",
              icon: Icons.folder,
              child: ResizableWidget(
                axis: Axis.vertical,
                percentages: const [0.75, 0.25],
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
        Expanded(child: OpenFilesAreas()),
        RightSidebar(),
      ],
    );
  }
}
