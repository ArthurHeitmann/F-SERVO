
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
          prototypeItem: cachedFlatTree.isNotEmpty ? HierarchyEntryWidget(cachedFlatTree.first.entry) : null,
          itemBuilder: (context, index) {
            var entry = cachedFlatTree[index].entry;
            var depth = cachedFlatTree[index].depth;
            return HierarchyEntryWidget(entry, depth: depth);
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

  void _regenerateFlatTree(HierarchyEntry entry, int depth) {
    if (!entry.isVisibleWithSearch.value)
      return;
    cachedFlatTree.add(IndentedHierarchyEntry(entry, depth));
    if (!entry.isCollapsed.value) {
      for (var child in entry)
        _regenerateFlatTree(child, depth + 1);
    }
  }
}

class IndentedHierarchyEntry {
  final HierarchyEntry entry;
  final int depth;

  const IndentedHierarchyEntry(this.entry, this.depth);
}
