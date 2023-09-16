
import 'package:flutter/widgets.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/HierarchyEntryTypes.dart';
import '../misc/SmoothScrollBuilder.dart';
import 'HierarchyEntryWidget.dart';

class HierarchyFlatList extends ChangeNotifierWidget {
  HierarchyFlatList({super.key}) : super(notifier: openHierarchyManager.treeViewIsDirty);

  @override
  State<HierarchyFlatList> createState() => _HierarchyFlatListState();
}

class _HierarchyFlatListState extends ChangeNotifierState<HierarchyFlatList> {
  final scrollController = ScrollController();
  List<IndentedHierarchyEntry> cachedFlatTree = [];

  @override
  void initState() {
    super.initState();
    regenerateFlatTree();
  }

  @override
  Widget build(BuildContext context) {
    if (openHierarchyManager.treeViewIsDirty.value)
      regenerateFlatTree();

    return SmoothScrollBuilder(
      controller: scrollController,
      builder: (context, controller, physics) {
        return ListView.builder(
          controller: controller,
          physics: physics,
          itemCount: cachedFlatTree.length,
          prototypeItem: cachedFlatTree.isNotEmpty ? HierarchyEntryWidget(entry: cachedFlatTree.first.entry) : null,
          itemBuilder: (context, index) {
            var entry = cachedFlatTree[index];
            return HierarchyEntryWidget(
              key: Key(entry.uuidPath.join(", ")),
              entry: entry.entry,
              depth: entry.depth
            );
          }
        );
      }
    );
  }

  void regenerateFlatTree() {
    cachedFlatTree = [];
    for (var entry in openHierarchyManager) {
      _regenerateFlatTree(entry, 0);
    }
    openHierarchyManager.treeViewIsDirty.value = false;
  }

  void _regenerateFlatTree(HierarchyEntry entry, int depth, [List<String> parentUuidPath = const []]) {
    if (!entry.isVisibleWithSearch.value)
      return;
    var uuidPath = [...parentUuidPath, entry.uuid];
    cachedFlatTree.add(IndentedHierarchyEntry(entry, uuidPath, depth));
    if (!entry.isCollapsed.value) {
      for (var child in entry)
        _regenerateFlatTree(child, depth + 1, uuidPath);
    }
  }
}

class IndentedHierarchyEntry {
  final HierarchyEntry entry;
  final List<String> uuidPath;
  final int depth;

  const IndentedHierarchyEntry(this.entry, this.uuidPath, this.depth);
}
