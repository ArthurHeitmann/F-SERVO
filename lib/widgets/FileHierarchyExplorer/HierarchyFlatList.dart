
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext, Curves, FocusScope, Key, ListView, ScrollController, State, Widget;

import '../../keyboardEvents/BetterShortcuts.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../misc/TextFieldFocusNode.dart';
import '../misc/onHoverBuilder.dart';
import 'HierarchyEntryWidget.dart';
import 'HierarchyShortcuts.dart';

class HierarchyFlatList extends ChangeNotifierWidget {
  HierarchyFlatList({super.key}) : super(notifier: openHierarchyManager.treeViewIsDirty);

  @override
  State<HierarchyFlatList> createState() => _HierarchyFlatListState();
}

class _HierarchyFlatListState extends ChangeNotifierState<HierarchyFlatList> {
  final scrollController = ScrollController();
  List<IndentedHierarchyEntry> cachedFlatTree = [];
  bool isCursorInside = false;

  @override
  void initState() {
    super.initState();
    regenerateFlatTree();
  }

  @override
  Widget build(BuildContext context) {
    if (openHierarchyManager.treeViewIsDirty.value)
      regenerateFlatTree();

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
      ),
    );
  }

  void regenerateFlatTree() {
    cachedFlatTree = [];
    for (var entry in openHierarchyManager.children) {
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
      for (var child in entry.children)
        _regenerateFlatTree(child, depth + 1, uuidPath);
    }
  }

  Widget shortcutsWrapper({required Widget child}) {
    return BetterShortcuts(
      shortcuts: {
        const KeyCombo(LogicalKeyboardKey.arrowUp, {}, true): ArrowUpShortcut(() => moveSelectionVertically(-1)),
        const KeyCombo(LogicalKeyboardKey.arrowDown, {}, true): ArrowDownShortcut(() => moveSelectionVertically(1)),
        const KeyCombo(LogicalKeyboardKey.arrowLeft): ArrowLeftShortcut(() => onArrowLeft()),
        const KeyCombo(LogicalKeyboardKey.arrowRight): ArrowRightShortcut(() => onArrowRight()),
        const KeyCombo(LogicalKeyboardKey.enter): EnterShortcut(() => openCurrentFile()),
      },
      actions: {
        ArrowUpShortcut: CallbackAction(),
        ArrowDownShortcut: CallbackAction(),
        ArrowLeftShortcut: CallbackAction(),
        ArrowRightShortcut: CallbackAction(),
        EnterShortcut: CallbackAction(),
      },
      child: child,
    );
  }

  void moveSelectionVertically(int direction) {
    if (shouldIgnoreKeyboardEvents())
      return;
    if (openHierarchyManager.selectedEntry.value == null) {
      if (cachedFlatTree.isNotEmpty)
        openHierarchyManager.setSelectedEntry(cachedFlatTree.first.entry);
      return;
    }
    var currentIndex = cachedFlatTree.indexWhere((e) => e.entry == openHierarchyManager.selectedEntry.value);
    if (currentIndex == -1)
      return;
    var newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= cachedFlatTree.length)
      return;
    unfocusCurrent();
    openHierarchyManager.setSelectedEntry(cachedFlatTree[newIndex].entry);
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
    var currentIndex = cachedFlatTree.indexWhere((e) => e.entry == openHierarchyManager.selectedEntry.value);
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

class IndentedHierarchyEntry {
  final HierarchyEntry entry;
  final List<String> uuidPath;
  final int depth;

  const IndentedHierarchyEntry(this.entry, this.uuidPath, this.depth);
}
