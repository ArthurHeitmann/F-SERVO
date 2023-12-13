
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFilesManager.dart';
import '../ResizableWidget.dart';
import 'FileDetailsEditor.dart';
import 'FileType.dart';
import 'outliner.dart';
import 'sidebar.dart';

class RightSidebar extends ChangeNotifierWidget {
  RightSidebar({super.key})
    : super(notifier: areasManager);

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends ChangeNotifierState<RightSidebar> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierBuilder(
      notifier: areasManager.activeArea,
      builder: (context) {
        // const displayForFileTypes = [FileType.xml, FileType.bnkPlaylist, FileType.est];
        // if (!displayForFileTypes.contains(areasManager.activeArea?.currentFile?.type))
        //   return const SizedBox();
        bool showOutliner = areasManager.activeArea?.currentFile?.type == FileType.xml;
        return Sidebar(
          initialWidth: MediaQuery.of(context).size.width * 0.25,
          switcherPosition: SidebarSwitcherPosition.right,
          entries: [
            SidebarEntryConfig(
              name: "Details",
              child: ResizableWidget(
                axis: Axis.vertical,
                percentages: showOutliner
                  ? [0.4, 0.6]
                  : [1],
                children: [
                  if (showOutliner)
                    Outliner(),
                  FileDetailsEditor(),
                ],
              ),
            ),
          ],
        );
      }
    );
  }
}