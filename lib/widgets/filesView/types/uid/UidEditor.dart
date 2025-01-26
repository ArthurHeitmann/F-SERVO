

import 'package:flutter/material.dart';

import '../../../../stateManagement/openFiles/openFileTypes.dart';
import '../../../../stateManagement/openFiles/types/UidFileData.dart';
import '../../../../utils/utils.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../misc/SmoothScrollBuilder.dart';
import '../../../misc/onHoverBuilder.dart';
import '../../../theme/customTheme.dart';
import '../effect/RgbPropEditor.dart';

class UidEditor extends ChangeNotifierWidget {
  final UidFileData uid;
  
  UidEditor({super.key, required this.uid}) : super(notifier: uid.loadingState);

  @override
  State<UidEditor> createState() => _UidEditorState();
}

class _UidEditorState extends ChangeNotifierState<UidEditor> {
  @override
  void initState() {
    super.initState();
    widget.uid.load();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.loadingState.value != LoadingState.loaded) {
      return const Column(
        children: [
          SizedBox(height: 35),
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          ),
        ],
      );
    }
    return SmoothSingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 32, left: 16, right: 16),
        child: Column(
          children: [
            for (var (i, entry) in widget.uid.entries.indexed)
              _UidEntryEditor(
                entry: entry,
                selectedEntry: widget.uid.selectedEntry,
                index: i,
                mcdNames: widget.uid.mcdNames,
              )
          ],
        ),
      )
    );
  }
}

class _UidEntryEditor extends StatelessWidget {
  final UidEntryData entry;
  final ValueNotifier<UidEntryData?> selectedEntry;
  final int index;
  final Map<int, String> mcdNames;

  const _UidEntryEditor({
    required this.entry,
    required this.selectedEntry,
    required this.index,
    required this.mcdNames,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectableUidItem(
      item: entry,
      selectedItem: selectedEntry,
      child: SizedBox(
        height: 35,
        child: Row(
          children: [
            Text("Entry $index"),
            const SizedBox(width: 10),
            RgbPropEditor(
              prop: entry.rgb,
              showTextFields: false,
            ),
            if (entry.mcdData != null)
              Text(" MCD: ${mcdNames[entry.mcdData!.id.value] ?? messCoreNames[entry.mcdData!.id.value] ?? "?"}"),
            if (entry.uvdData != null)
              Text(" UVD"),
          ],
        ),
      ),
    );
  }
}


class _SelectableUidItem extends StatelessWidget {
  final ValueNotifier<UidEntryData?> selectedItem;
  final UidEntryData item;
  final Widget child;

  const _SelectableUidItem({required this.item, required this.selectedItem, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _select,
      child: OnHoverBuilder(
        builder: (context, isHovering) => ChangeNotifierBuilder(
          notifier: selectedItem,
          builder: (context) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              color: _getBackgroundColor(context, isHovering),
              padding: const EdgeInsets.only(left: 10),
              child: child,
            );
          }
        ),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context, bool isHovering) {
    if (item == selectedItem.value)
      return getTheme(context).textColor!.withOpacity(0.15);
    if (isHovering)
      return getTheme(context).textColor!.withOpacity(0.05);
    return Colors.transparent;
  }

  void _select() {
    if (selectedItem.value == item && (isCtrlPressed() || isShiftPressed()))
      selectedItem.value = null;
    else
      selectedItem.value = item;
  }
}
