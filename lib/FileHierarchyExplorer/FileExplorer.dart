
import 'package:flutter/src/widgets/container.dart';
import 'package:nier_scripts_editor/stateManagement/FileHierarchy.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';

class FileExplorer extends ChangeNotifierWidget {
  FileExplorer({super.key}) : super(notifier: openHierarchyManager);

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends ChangeNotifierState<FileExplorer> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
