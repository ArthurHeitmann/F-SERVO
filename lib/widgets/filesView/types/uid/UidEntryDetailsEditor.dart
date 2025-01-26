
import 'package:flutter/material.dart';

import '../../../../stateManagement/openFiles/types/UidFileData.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../propEditors/propEditorFactory.dart';
import '../../../propEditors/propTextField.dart';
import '../effect/RgbPropEditor.dart';

class UidEntryDetailsEditor extends ChangeNotifierWidget {
  final UidFileData uid;
  final ValueNotifier<UidEntryData?> entry;

  UidEntryDetailsEditor({
    super.key,
    required this.uid,
    required this.entry
  }) : super(notifier: entry);

  @override
  State<UidEntryDetailsEditor> createState() => _UidEntryDetailsEditorState();
}

class _UidEntryDetailsEditorState extends ChangeNotifierState<UidEntryDetailsEditor> {
  @override
  Widget build(BuildContext context) {
    var selected = widget.entry.value;
    if (selected == null) {
      return const SizedBox();
    }
    var mcdData = selected.mcdData;
    var uvdData = selected.uvdData;
    return Column(
      key: Key(selected.uuid),
      children: [
        _makeLabeled("Translation", makePropEditor(selected.translation)),
        _makeLabeled("Rotation", makePropEditor(selected.rotation)),
        _makeLabeled("Scale", makePropEditor(selected.scale)),
        _makeLabeled("Color", RgbPropEditor(prop: selected.rgb, showTextFields: true)),
        _makeLabeled("Alpha", makePropEditor(selected.alpha)),
        if (mcdData != null) ...[
          _makeLabeled("MCD Data", const SizedBox(height: 30)),
          _makeLabeled("", Row(
            children: [
              Flexible(
                child: ChangeNotifierBuilder(
                  notifier: mcdData.file,
                  builder: (_) => Text("ui_${mcdData.file.value}_us.dat/mess", overflow: TextOverflow.ellipsis),
                ),
              ),
              makePropEditor(mcdData.file, PropTFOptions(useIntrinsicWidth: true)),
              const Text(".mcd"),
            ],
          )),
          _makeLabeled("Entry ID", makePropEditor(mcdData.id)),
          _makeLabeled("Text preview:", ChangeNotifierBuilder(
            notifier: mcdData.id,
            builder: (context) => Text(widget.uid.mcdNames[mcdData.id.value] ?? messCoreNames[mcdData.id.value] ?? ""),
          )),
        ],
        if (uvdData != null) ...[
          _makeLabeled("UVD Data", const SizedBox(height: 30)),
          _makeLabeled("Icon ID", makePropEditor(uvdData.uvdId)),
          _makeLabeled("Texture ID", makePropEditor(uvdData.texId)),
          Row(
            children: [
              Expanded(
                child: _makeLabeled("Width", makePropEditor(uvdData.width))
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _makeLabeled("Height", makePropEditor(uvdData.height))
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _makeLabeled(String label, Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Row(
        children: [
          if (label.isNotEmpty) ...[
            Text(label),
            const SizedBox(width: 8),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}
