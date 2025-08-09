
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../fileTypeUtils/effects/estEntryTypes.dart';
import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/listNotifier.dart';
import '../../../../stateManagement/openFiles/openFileTypes.dart';
import '../../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../../stateManagement/openFiles/types/EstFileData.dart';
import '../../../../utils/utils.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../misc/SmoothScrollBuilder.dart';
import '../../../misc/onHoverBuilder.dart';
import '../../../propEditors/boolPropCheckbox.dart';
import '../../../theme/customTheme.dart';
import 'EstModelPreview.dart';
import 'EstTexturePreview.dart';
import 'RgbPropEditor.dart';


class EstFileEditor extends ChangeNotifierWidget {
  final EstFileData file;

  EstFileEditor({super.key, required this.file})
    : super(notifiers: [file.loadingState, file.records]);

  @override
  State<EstFileEditor> createState() => _EstFileEditorState();
}

class _EstFileEditorState extends ChangeNotifierState<EstFileEditor> {
  @override
  void initState() {
    widget.file.load();
    super.initState();
  }

  void copyAllEntries() {
    var json = {
      "type": _JsonCopyType.entryList.index,
      "data": widget.file.records
        .map((record) => record.entries
          .map((entry) => entry.toJson())
          .toList()
        )
        .toList()
    };
    _copyJson(json);
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
    if (json is! Map) {
      showToast("Invalid json");
      return;
    }
    var type = json["type"];
    var data = json["data"];
    if (type is! int || type < 0 || type >= _JsonCopyType.values.length) {
      showToast("Invalid json");
      return;
    }
    if (type == _JsonCopyType.entryList.index && data is! List) {
      showToast("Invalid json");
      return;
    }
    if (type == _JsonCopyType.record.index && data is! Map) {
      showToast("Invalid json");
      return;
    }
    if (type == _JsonCopyType.record.index)
      data = [[data]];
    for (var record in (data as List).cast<List>()) {
      var entries = record
        .map((e) => EstEntryWrapper.fromJson(e, widget.file.uuid))
        .toList();
      widget.file.records.add(EstRecordWrapper(
        ValueListNotifier(entries, fileId: widget.file.uuid),
        widget.file.uuid,
      ));
    }
  }

  void setAllCollapsed(bool collapsed) {
    for (var record in widget.file.records) {
      record.isCollapsed.value = collapsed;
    }
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
    return Stack(
      children: [
        SmoothSingleChildScrollView(
          child: ChangeNotifierBuilder(
            notifier: widget.file.records,
            builder: (context) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 35),
                  for (int i = 0; i < widget.file.records.length; i++) ...[
                    if (i == 0)
                      const Divider(height: 1, thickness: 1,),
                    _EstRecordEditor(
                      index: i,
                      record: widget.file.records[i],
                      typeNames: widget.file.typeNames,
                      onRemove: () => widget.file.removeRecord(widget.file.records[i]),
                      selectedEntry: widget.file.selectedEntry,
                      // initiallyCollapsed: widget.file.records.length > 3,
                      initiallyCollapsed: false,
                      fileId: widget.file.uuid,
                    ),
                    const Divider(height: 1, thickness: 1,),
                  ],
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _EntryIconButton(
                          icon: Icons.copy_all,
                          onPressed: copyAllEntries,
                          iconSize: 16,
                          splashRadius: 18,
                        ),
                      ),
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
                  ),
                ],
              );
            }
          )
        ),
        Positioned(
          right: 12,
          top: 20,
          child: 
            Material(
              color: getTheme(context).editorBackgroundColor,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: getTheme(context).textColor!.withOpacity(0.2),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.unfold_more, size: 20,),
                    splashRadius: 20,
                    onPressed: () => setAllCollapsed(false),
                  ),
                  IconButton(
                    icon: Icon(Icons.unfold_less, size: 20,),
                    splashRadius: 20,
                    onPressed: () => setAllCollapsed(true),
                  ),
                ],
              ),
            ),
        )
      ],
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
  final OpenFileId fileId;

  _EstRecordEditor({
    required this.index,
    required this.record,
    required this.typeNames,
    required this.onRemove,
    required this.selectedEntry,
    required this.initiallyCollapsed,
    required this.fileId,
  }) : super(notifiers: [record.entries, selectedEntry, record.isCollapsed], key: Key(record.uuid));

  @override
  State<_EstRecordEditor> createState() => _EstRecordEditorState();
}

class _EstRecordEditorState extends ChangeNotifierState<_EstRecordEditor> {
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
      showToast("Invalid json");
      return;
    }
    var type = json["type"];
    var data = json["data"];
    if (type != _JsonCopyType.record.index) {
      showToast("Can only paste single entries, not full records");
      return;
    }
    var entry = EstEntryWrapper.fromJson(data, widget.fileId);
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
    var json = {
      "type": _JsonCopyType.entryList.index,
      "data": [
        widget.record.entries
          .map((entry) => entry.toJson())
          .toList()
      ]
    };
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
                IconButton(
                  icon: Icon(widget.record.isCollapsed.value ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded, size: 20,),
                  splashRadius: 16,
                  onPressed: () {
                    widget.record.isCollapsed.value = !widget.record.isCollapsed.value;
                  },
                ),
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
        if (!widget.record.isCollapsed.value) ...[
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
  }) : super(key: Key(entry.uuid), notifier: selectedEntry);

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
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints.tightFor(width: 325),
                child: Row(
                  children: [
                    Flexible(child: Text("${widget.entry.entry.header.id} / ${estTypeFullNames[widget.entry.entry.header.id]}", overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 10),
                    if (widget.entry is EstMoveEntryWrapper)
                      RgbPropEditor(
                        prop: (widget.entry as EstMoveEntryWrapper).rgb,
                        showTextFields: false,
                      ),
                    if (widget.entry is EstTexEntryWrapper) ...[
                      EstTexturePreview(
                        textureFileId: (widget.entry as EstTexEntryWrapper).textureFileId,
                        textureFileTextureIndex: (widget.entry as EstTexEntryWrapper).textureFileIndex,
                      ),
                      const SizedBox(width: 10),
                      EstModelPreview(
                        modelId: (widget.entry as EstTexEntryWrapper).meshId,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _EntryIconButton(
              onPressed: () => _copyJson({
                "type": _JsonCopyType.record.index,
                "data": widget.entry.toJson()
              }),
              icon: Icons.copy,
            ),
            _EntryCheckbox(prop: widget.entry.isEnabled),
            const SizedBox(width: 5),
            _EntryIconButton(
              onPressed: widget.onRemove,
              icon: Icons.delete,
              iconSize: 15,
            ),
            const SizedBox(width: 15),
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

enum _JsonCopyType {
  entryList,
  record
}

void _copyJson(Object json) {
  var jsonStr = jsonEncode(json);
  copyToClipboard(jsonStr);
}
