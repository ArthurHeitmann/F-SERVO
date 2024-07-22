import 'package:flutter/material.dart';

import '../stateManagement/preferencesData.dart';
import 'FileHierarchyExplorer/FileExplorer.dart';
import 'FileHierarchyExplorer/fileMetaEditor.dart';
import 'filesView/OpenFilesAreas.dart';
import 'layout/rightSidebar.dart';
import 'layout/searchPanel.dart';
import 'layout/sidebar.dart';
import 'misc/ChangeNotifierWidget.dart';
import 'misc/ResizableWidget.dart';
import 'tools/toolsOverview.dart';

class EditorLayout extends ChangeNotifierWidget {
  final ValueNotifier<bool> moveFilePropertiesToRight;

  EditorLayout({super.key, required PreferencesData prefs}) :
    moveFilePropertiesToRight = prefs.moveFilePropertiesToRight!,
    super(notifier: prefs.moveFilePropertiesToRight);

  @override
  State<EditorLayout> createState() => _EditorLayoutState();
}

class _EditorLayoutState extends ChangeNotifierState<EditorLayout> {
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
                percentages: widget.moveFilePropertiesToRight.value
                  ? const [1.0]
                  : const [0.75, 0.25],
                draggableThickness: 5,
                children: [
                  FileExplorer(),
                  if (!widget.moveFilePropertiesToRight.value)
                    FileMetaEditor()
                ],
              ),
            ),
            SidebarEntryConfig(
              name: "Search",
              icon: Icons.search,
              child: const SearchPanel(),
            ),
            SidebarEntryConfig(
              name: "Tools",
              icon: Icons.build,
              child: const ToolsOverview(),
            ),
          ],
        ),
        Expanded(child: OpenFilesAreas()),
        RightSidebar(moveFilePropertiesToRight: widget.moveFilePropertiesToRight),
      ],
    );
  }
}
