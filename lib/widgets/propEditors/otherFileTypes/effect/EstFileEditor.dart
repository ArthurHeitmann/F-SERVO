
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../fileTypeUtils/effects/estEntryTypes.dart';
import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/listNotifier.dart';
import '../../../../stateManagement/openFiles/openFileTypes.dart';
import '../../../../stateManagement/otherFileTypes/EstFileData.dart';
import '../../../../utils/utils.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../misc/SmoothScrollBuilder.dart';
import '../../../misc/onHoverBuilder.dart';
import '../../../theme/customTheme.dart';
import '../../simpleProps/boolPropCheckbox.dart';
import 'EstModelPreview.dart';
import 'EstTexturePreview.dart';
import 'RgbPropEditor.dart';


class EstFileEditor extends ChangeNotifierWidget {
  final EstFileData file;

  EstFileEditor({super.key, required this.file})
    : super(notifiers: [file.loadingState, file.estData.records]);

  @override
  State<EstFileEditor> createState() => _EstFileEditorState();
}

class _EstFileEditorState extends ChangeNotifierState<EstFileEditor> {
  final scrollController = ScrollController();
  
  @override
  void initState() {
    widget.file.load();
    super.initState();
  }

  void pasteEntries() async {
    var jsonStr = await getClipboardText();
    if (jsonStr == null) {
      showToast("Clipboard is empty");
      return;
    }
    Object json;
    try {
      json = jsonDecode(jsonStr);
    } catch (e) {
      showToast("Invalid json");
      return;
    }
    if (json is Map)
      json = [json];
    if (json is! List) {
      showToast("Invalid json");
      return;
    }
    var entries = json.map((e) => EstEntryWrapper.fromJson(e));
    widget.file.estData.records.add(EstRecordWrapper(
      ValueListNotifier(entries.toList()),
      widget.file.uuid,
    ));
  }


  @override
  Widget build(BuildContext context) {
    if (widget.file.loadingState.value != LoadingState.loaded) {
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
      controller: scrollController,
      child: ChangeNotifierBuilder(
        notifier: widget.file.estData.records,
        builder: (context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 35),
              for (int i = 0; i < widget.file.estData.records.length; i++) ...[
                if (i == 0)
                  const Divider(height: 1, thickness: 1,),
                _EstRecordEditor(
                  index: i,
                  record: widget.file.estData.records[i],
                  typeNames: widget.file.estData.typeNames,
                  onRemove: () => widget.file.estData.removeRecord(widget.file.estData.records[i]),
                  selectedEntry: widget.file.estData.selectedEntry,
                  // initiallyCollapsed: widget.file.estData.records.length > 3,
                  initiallyCollapsed: false,
                ),
                const Divider(height: 1, thickness: 1,),
              ],
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _EntryIconButton(
                  icon: Icons.paste,
                  onPressed: pasteEntries,
                  iconSize: 16,
                  splashRadius: 18,
                ),
              ),
            ],
          );
        }
      )
    );
  }
}

class _EstRecordEditor extends ChangeNotifierWidget {
  final int index;
  final EstRecordWrapper record;
  final List<String> typeNames;
  final VoidCallback onRemove;
  final ValueNotifier<SelectedEffectItem?> selectedEntry;
  final bool initiallyCollapsed;

  _EstRecordEditor({
    required this.index,
    required this.record,
    required this.typeNames,
    required this.onRemove,
    required this.selectedEntry,
    required this.initiallyCollapsed,
  }) : super(notifiers: [record.entries, selectedEntry], key: Key(record.uuid));

  @override
  State<_EstRecordEditor> createState() => _EstRecordEditorState();
}

class _EstRecordEditorState extends ChangeNotifierState<_EstRecordEditor> {
  late bool isCollapsed;

  @override
  void initState() {
    isCollapsed = widget.initiallyCollapsed;
    super.initState();
  }

  void pasteEntry() async {
    var jsonStr = await getClipboardText();
    if (jsonStr == null) {
      showToast("Clipboard is empty");
      return;
    }
    Object json;
    try {
      json = jsonDecode(jsonStr);
    } catch (e) {
      showToast("Invalid json");
      return;
    }
    if (json is! Map) {
      if (json is List)
        showToast("Only single entries can be pasted");
      else
        showToast("Invalid json");
      return;
    }
    var entry = EstEntryWrapper.fromJson(json);
    if (widget.record.entries.any((e) => e.entry.header.id == entry.entry.header.id)) {
      showToast("Entry of this type already exists");
      return;
    }
    widget.record.entries.add(entry);
    widget.record.entries.sort((a, b) {
      var aIdIndex = widget.typeNames.indexOf(a.entry.header.id);
      var bIdIndex = widget.typeNames.indexOf(b.entry.header.id);
      return aIdIndex.compareTo(bIdIndex);
    });
  }

  void copyEntries() {
    var json = widget.record.entries
      .map((entry) => entry.toJson())
      .toList();
    _copyJson(json);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SelectableEffectItem(
          item: SelectedEffectItem(record: widget.record),
          selectedItem: widget.selectedEntry,
          child: SizedBox(
            height: 35,
            child: Row(
              children: [
                // Icon(isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded, size: 20,),
                Text("Record ${widget.index}"),
                const SizedBox(width: 10),
                _EntryIconButton(
                  onPressed: copyEntries,
                  icon: Icons.copy,
                  iconSize: 15,
                  splashRadius: 14,
                ),
                _EntryCheckbox(prop: widget.record.isEnabled),
                const SizedBox(width: 5),
                _EntryIconButton(
                  onPressed: widget.onRemove,
                  icon: Icons.delete,
                  iconSize: 16,
                  splashRadius: 14,
                ),
              ],
            ),
          ),
        ),
        if (!isCollapsed) ...[
          for (var entry in widget.record.entries)
            _EstEntryWidget(
              entry: entry,
              onRemove: () => widget.record.removeEntry(entry),
              selectedEntry: widget.selectedEntry,
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _EntryIconButton(
              icon: Icons.paste,
              onPressed: pasteEntry,
              iconSize: 16,
              splashRadius: 18,
            ),
          ),
        ]
      ],
    );
  }
}

class _EstEntryWidget extends ChangeNotifierWidget {
  final EstEntryWrapper entry;
  final VoidCallback onRemove;
  final ValueNotifier<SelectedEffectItem?> selectedEntry;

  _EstEntryWidget({
    required this.entry,
    required this.onRemove,
    required this.selectedEntry,
  }) : super(notifier: selectedEntry);

  @override
  State<_EstEntryWidget> createState() => _EstEntryWidgetState();
}

class _EstEntryWidgetState extends ChangeNotifierState<_EstEntryWidget> {
  @override
  Widget build(BuildContext context) {
    return _SelectableEffectItem(
      item: SelectedEffectItem(entry: widget.entry),
      selectedItem: widget.selectedEntry,
      child: SizedBox(
        height: 25,
        child: Row(
          children: [
            const SizedBox(width: 15),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 325),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${widget.entry.entry.header.id} / ${estTypeFullNames[widget.entry.entry.header.id]}"),
                  const SizedBox(width: 10),
                  if (widget.entry is EstMoveEntryWrapper)
                    RgbPropEditor(
                      prop: (widget.entry as EstMoveEntryWrapper).rgb,
                      showTextFields: false,
                    ),
                  if (widget.entry is EstTexEntryWrapper) ...[
                    EstTexturePreview(
                      textureFileId: (widget.entry as EstTexEntryWrapper).textureFileId,
                      textureFileTextureIndex: (widget.entry as EstTexEntryWrapper).textureFileTextureIndex,
                    ),
                    const SizedBox(width: 10),
                    EstModelPreview(
                      modelId: (widget.entry as EstTexEntryWrapper).meshId,
                    ),
                  ]
                ],
              )
            ),
            const SizedBox(width: 10),
            _EntryIconButton(
              onPressed: () => _copyJson(widget.entry.toJson()),
              icon: Icons.copy,
            ),
            _EntryCheckbox(prop: widget.entry.isEnabled),
            const SizedBox(width: 5),
            _EntryIconButton(
              onPressed: widget.onRemove,
              icon: Icons.delete,
              iconSize: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableEffectItem extends StatelessWidget {
  final ValueNotifier<SelectedEffectItem?> selectedItem;
  final SelectedEffectItem item;
  final Widget child;

  const _SelectableEffectItem({required this.item, required this.selectedItem, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _select,
      child: OnHoverBuilder(
        builder: (context, isHovering) => AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _getBackgroundColor(context, isHovering),
          padding: const EdgeInsets.only(left: 10),
          child: child,
        )
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

class _EntryIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;
  final double splashRadius;

  const _EntryIconButton({required this.icon, required this.onPressed, this.iconSize = 14, this.splashRadius = 14});

  @override
  Widget build(BuildContext context) {
    return OnHoverBuilder(
      builder: (context, isHovering) => AnimatedOpacity(
        opacity: isHovering ? 1 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: iconSize),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          splashRadius: splashRadius,
        ),
      ),
    );
  }
}

class _EntryCheckbox extends StatelessWidget {
  final BoolProp prop;

  const _EntryCheckbox({required this.prop});

  @override
  Widget build(BuildContext context) {
    return OnHoverBuilder(
      builder: (context, isHovering) => AnimatedOpacity(
        opacity: isHovering ? 0.75 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Transform.scale(
          scale: 0.75,
          child: BoolPropCheckbox(
            prop: prop,
            fillColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected)
              ? getTheme(context).textColor!
              : getTheme(context).editorBackgroundColor!
            ),
            checkColor: getTheme(context).editorBackgroundColor,
          ),
        ),
      ),
    );
  }
}

void _copyJson(Object json) {
  var jsonStr = jsonEncode(json);
  copyToClipboard(jsonStr);
}
