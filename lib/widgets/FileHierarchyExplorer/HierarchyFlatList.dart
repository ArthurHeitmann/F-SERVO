
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext, Focus, FocusNode, FocusScope, Key, ListView, ScrollController, State, Widget;

import '../../keyboardEvents/BetterShortcuts.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/HierarchyEntryTypes.dart';
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
    if (openHierarchyManager.selectedEntry == null) {
      if (cachedFlatTree.isNotEmpty)
        openHierarchyManager.selectedEntry = cachedFlatTree.first.entry;
      return;
    }
    var currentIndex = cachedFlatTree.indexWhere((e) => e.entry == openHierarchyManager.selectedEntry);
    if (currentIndex == -1)
      return;
    var newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= cachedFlatTree.length)
      return;
    unfocusCurrent();
    openHierarchyManager.selectedEntry = cachedFlatTree[newIndex].entry;
    scrollToSelectedEntry();
  }

  void onArrowLeft() {
    if (shouldIgnoreKeyboardEvents())
      return;
    if (openHierarchyManager.selectedEntry == null)
      return;
    unfocusCurrent();
    if (openHierarchyManager.selectedEntry!.isCollapsed.value || openHierarchyManager.selectedEntry!.isEmpty) {
      var parent = openHierarchyManager.parentOf(openHierarchyManager.selectedEntry!);
      if (parent is HierarchyEntry)
        openHierarchyManager.selectedEntry = parent;
    }
    else {
      openHierarchyManager.selectedEntry!.isCollapsed.value = true;
    }
    scrollToSelectedEntry();
  }

  void onArrowRight() {
    if (shouldIgnoreKeyboardEvents())
      return;
    if (openHierarchyManager.selectedEntry == null)
      return;
    unfocusCurrent();
    if (openHierarchyManager.selectedEntry!.isCollapsed.value) {
      openHierarchyManager.selectedEntry!.isCollapsed.value = false;
    }
    else {
      var firstChild = openHierarchyManager.selectedEntry!.firstOrNull;
      if (firstChild != null)
        openHierarchyManager.selectedEntry = firstChild;
    }
    scrollToSelectedEntry();
  }

  void openCurrentFile() {
    if (!isCursorInside)
      return;
    if (openHierarchyManager.selectedEntry == null)
      return;
    if (openHierarchyManager.selectedEntry is FileHierarchyEntry)
      openHierarchyManager.selectedEntry!.onOpen();
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
    return;
    if (openHierarchyManager.selectedEntry == null)
      return;
    var currentIndex = cachedFlatTree.indexWhere((e) => e.entry == openHierarchyManager.selectedEntry);
    if (currentIndex == -1)
      return;
    var currentEntry = cachedFlatTree[currentIndex];
    var currentEntryTop = currentEntry.depth * 20.0;
    var currentEntryBottom = currentEntryTop + 20.0;
    var currentEntryCenter = (currentEntryTop + currentEntryBottom) / 2;
    var currentEntryCenterInViewport = currentEntryCenter - scrollController.offset;
    var viewportHeight = scrollController.position.viewportDimension;
    if (currentEntryCenterInViewport < 0) {
      scrollController.jumpTo(scrollController.offset + currentEntryCenterInViewport);
    }
    else if (currentEntryCenterInViewport > viewportHeight) {
      scrollController.jumpTo(scrollController.offset + currentEntryCenterInViewport - viewportHeight);
    }
  }
}

class IndentedHierarchyEntry {
  final HierarchyEntry entry;
  final List<String> uuidPath;
  final int depth;

  const IndentedHierarchyEntry(this.entry, this.uuidPath, this.depth);
}
