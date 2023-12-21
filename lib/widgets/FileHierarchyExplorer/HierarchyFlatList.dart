
import 'package:flutter/widgets.dart' show BuildContext, Curves, FocusScope, Key, ListView, ScrollController, State, Widget;

import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../misc/TextFieldFocusNode.dart';
import '../misc/onHoverBuilder.dart';
import 'HierarchyEntryWidget.dart';

class HierarchyFlatList extends ChangeNotifierWidget {
  HierarchyFlatList({super.key}) : super(notifiers: [openHierarchyManager.filteredTreeIsDirty, openHierarchyManager.collapsedTreeIsDirty]);

  @override
  State<HierarchyFlatList> createState() => _HierarchyFlatListState();
}

class _HierarchyFlatListState extends ChangeNotifierState<HierarchyFlatList> {
  final scrollController = ScrollController();
  List<_IndentedHierarchyEntryResult> filteredResults = [];
  List<_IndentedHierarchyEntry> flatTree = [];
  bool isCursorInside = false;

  @override
  void initState() {
    super.initState();
    regenerateFilteredResults();
    regenerateFlatTree();
  }

  @override
  Widget build(BuildContext context) {
    if (openHierarchyManager.filteredTreeIsDirty.value) {
      regenerateFilteredResults();
      regenerateFlatTree();
    }
    else if (openHierarchyManager.collapsedTreeIsDirty.value) {
      regenerateFlatTree();
    }

    return shortcutsWrapper(
      child: OnHoverBuilder(
        builder: (context, isHovering) {
          isCursorInside = isHovering;
          return SmoothScrollBuilder(
            controller: scrollController,
            builder: (context, controller, physics) {
              return ListView.builder(
                controller: controller,
                physics: physics,
                itemCount: flatTree.length,
                prototypeItem: flatTree.isNotEmpty ? HierarchyEntryWidget(entry: flatTree.first.entry) : null,
                itemBuilder: (context, index) {
                  var entry = flatTree[index];
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
      ),
    );
  }

  void regenerateFilteredResults() {
    filteredResults = [];
    for (var entry in openHierarchyManager.children)
      filteredResults.add(getFilteredTree(entry, 0, [], openHierarchyManager.search.value.toLowerCase(), false));
    openHierarchyManager.filteredTreeIsDirty.value = false;
  }

  void regenerateFlatTree() {
    flatTree = [];
    flatTree.addAll(filteredResults.expand((e) => getFlatTree(e)));
    openHierarchyManager.collapsedTreeIsDirty.value = false;
  }

  _IndentedHierarchyEntryResult getFilteredTree(HierarchyEntry entry, int depth, Iterable<String> parentUuidPath, String query, bool parentMatchesSearch) {
    var uuidPath = [...parentUuidPath, entry.uuid];
    bool hasMatch = parentMatchesSearch || query.isEmpty || entry.name.toString().toLowerCase().contains(query);
    var newEntry = _IndentedHierarchyEntry(entry, uuidPath, depth);
    var childResults = List.generate(
      entry.children.length,
      (i) => getFilteredTree(entry.children[i], depth + 1, parentUuidPath, query, hasMatch)
    );
    return _IndentedHierarchyEntryResult(
      newEntry,
      childResults,
      hasMatch || childResults.any((e) => e.matchesSearch)
    );
  }

  Iterable<_IndentedHierarchyEntry> getFlatTree(_IndentedHierarchyEntryResult result) sync* {
    if (!result.matchesSearch)
      return;
    yield result.entry;
    if (result.entry.entry.isCollapsed.value)
      return;
    for (var child in result.children)
      yield* getFlatTree(child);
  }

  Widget shortcutsWrapper({required Widget child}) {
    return child;
    // return BetterShortcuts(
    //   shortcuts: {
    //     const KeyCombo(LogicalKeyboardKey.arrowUp, {}, true): ArrowUpShortcut(() => moveSelectionVertically(-1)),
    //     const KeyCombo(LogicalKeyboardKey.arrowDown, {}, true): ArrowDownShortcut(() => moveSelectionVertically(1)),
    //     const KeyCombo(LogicalKeyboardKey.arrowLeft): ArrowLeftShortcut(() => onArrowLeft()),
    //     const KeyCombo(LogicalKeyboardKey.arrowRight): ArrowRightShortcut(() => onArrowRight()),
    //     const KeyCombo(LogicalKeyboardKey.enter): EnterShortcut(() => openCurrentFile()),
    //   },
    //   actions: {
    //     ArrowUpShortcut: CallbackAction(),
    //     ArrowDownShortcut: CallbackAction(),
    //     ArrowLeftShortcut: CallbackAction(),
    //     ArrowRightShortcut: CallbackAction(),
    //     EnterShortcut: CallbackAction(),
    //   },
    //   child: child,
    // );
  }

  void moveSelectionVertically(int direction) {
    if (shouldIgnoreKeyboardEvents())
      return;
    if (openHierarchyManager.selectedEntry.value == null) {
      if (flatTree.isNotEmpty)
        openHierarchyManager.setSelectedEntry(flatTree.first.entry);
      return;
    }
    var currentIndex = flatTree.indexWhere((e) => e.entry == openHierarchyManager.selectedEntry.value);
    if (currentIndex == -1)
      return;
    var newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= flatTree.length)
      return;
    unfocusCurrent();
    openHierarchyManager.setSelectedEntry(flatTree[newIndex].entry);
    scrollToSelectedEntry();
  }

  void onArrowLeft() {
    if (shouldIgnoreKeyboardEvents())
      return;
    if (openHierarchyManager.selectedEntry.value == null)
      return;
    unfocusCurrent();
    if (openHierarchyManager.selectedEntry.value!.isCollapsed.value || openHierarchyManager.selectedEntry.value!.children.isEmpty) {
      var parent = openHierarchyManager.parentOf(openHierarchyManager.selectedEntry.value!);
      if (parent is HierarchyEntry)
        openHierarchyManager.setSelectedEntry(parent);
    }
    else {
      openHierarchyManager.selectedEntry.value!.isCollapsed.value = true;
    }
    scrollToSelectedEntry();
  }

  void onArrowRight() {
    if (shouldIgnoreKeyboardEvents())
      return;
    if (openHierarchyManager.selectedEntry.value == null)
      return;
    unfocusCurrent();
    if (openHierarchyManager.selectedEntry.value!.isCollapsed.value) {
      openHierarchyManager.selectedEntry.value!.isCollapsed.value = false;
    }
    else {
      var firstChild = openHierarchyManager.selectedEntry.value!.children.firstOrNull;
      if (firstChild != null)
        openHierarchyManager.setSelectedEntry(firstChild);
    }
    scrollToSelectedEntry();
  }

  void openCurrentFile() {
    if (!isCursorInside)
      return;
    if (openHierarchyManager.selectedEntry.value == null)
      return;
    if (openHierarchyManager.selectedEntry.value is FileHierarchyEntry)
      openHierarchyManager.selectedEntry.value!.onOpen();
  }

  bool shouldIgnoreKeyboardEvents() {
    if (!isCursorInside)
      return true;
    if (FocusScope.of(context).focusedChild is TextFieldFocusNode)
      return true;
    return false;
  }

  void unfocusCurrent() {
    FocusScope.of(context).focusedChild?.unfocus();
  }

  void scrollToSelectedEntry() {
    if (openHierarchyManager.selectedEntry.value == null)
      return;
    var currentIndex = flatTree.indexWhere((e) => e.entry == openHierarchyManager.selectedEntry.value);
    if (currentIndex == -1)
      return;
    var currentEntryTop = currentIndex * HierarchyEntryWidget.height;
    var currentEntryBottom = currentEntryTop + HierarchyEntryWidget.height;
    var scrollOffset = scrollController.offset;
    var scrollBottom = scrollOffset + scrollController.position.viewportDimension;
    double? scrollOffsetAfter;
    if (currentEntryTop < scrollOffset)
      scrollOffsetAfter = currentEntryTop;
    else if (currentEntryBottom > scrollBottom)
      scrollOffsetAfter = currentEntryBottom - scrollController.position.viewportDimension;
    if (scrollOffsetAfter != null) {
      scrollController.animateTo(
        scrollOffsetAfter,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }
}

class _IndentedHierarchyEntry {
  final HierarchyEntry entry;
  final List<String> uuidPath;
  final int depth;

  const _IndentedHierarchyEntry(this.entry, this.uuidPath, this.depth);
}

class _IndentedHierarchyEntryResult {
  final _IndentedHierarchyEntry entry;
  final List<_IndentedHierarchyEntryResult> children;
  final bool matchesSearch;

  const _IndentedHierarchyEntryResult(this.entry, this.children, this.matchesSearch);
}
