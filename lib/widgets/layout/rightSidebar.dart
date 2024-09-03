
import 'package:flutter/material.dart';

import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../utils/utils.dart';
import '../FileHierarchyExplorer/fileMetaEditor.dart';
import '../filesView/FileDetailsEditor.dart';
import '../filesView/FileType.dart';
import '../layout/sidebar.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/ResizableWidget.dart';
import 'outliner.dart';

class RightSidebar extends ChangeNotifierWidget {
  final ValueNotifier<bool> moveFilePropertiesToRight;

  RightSidebar({super.key, required this.moveFilePropertiesToRight})
    : super(notifiers: [areasManager.activeArea, moveFilePropertiesToRight]);

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends ChangeNotifierState<RightSidebar> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierBuilder(
      notifier: areasManager.activeArea.value?.currentFile,
      builder: (context) {
        bool showOutliner = areasManager.activeArea.value?.currentFile.value?.type == FileType.xml;
        double remainingPercentage = 1.0;
        List<double> defaultRatios = [];
        if (showOutliner) {
          defaultRatios.add(0.4);
          remainingPercentage -= 0.4;
        }
        if (widget.moveFilePropertiesToRight.value) {
          defaultRatios.add(0.4);
          remainingPercentage -= 0.4;
        }
        assert(remainingPercentage >= 0);
        defaultRatios.add(remainingPercentage);
        return Sidebar(
          initialWidth: clamp(MediaQuery.of(context).size.width * 0.25, 200, 300),
          switcherPosition: SidebarSwitcherPosition.right,
          entries: [
            SidebarEntryConfig(
              name: "Details",
              child: ResizableWidget(
                axis: Axis.vertical,
                percentages: defaultRatios,
                children: [
                  if (showOutliner)
                    Outliner(),
                  if (widget.moveFilePropertiesToRight.value)
                    FileMetaEditor(),
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
