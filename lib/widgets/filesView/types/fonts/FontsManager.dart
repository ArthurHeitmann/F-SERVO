

import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/openFiles/types/McdFileData.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../misc/SmoothScrollBuilder.dart';
import '../../../misc/smallButton.dart';
import '../../../propEditors/UnderlinePropTextField.dart';
import '../../../propEditors/propEditorFactory.dart';
import '../../../propEditors/propTextField.dart';
import '../../../theme/customTheme.dart';

class FontsManager extends ChangeNotifierWidget {
  final McdData? mcd;
  final int singleFontId;
  final bool showResolutionScale;
  final List<(String, Prop)> additionalProps;

  FontsManager({super.key, this.mcd, this.singleFontId = -1, this.showResolutionScale = true, this.additionalProps = const []}) : super(notifier: McdData.fontOverrides);

  @override
  State<FontsManager> createState() => __McdFontsManagerState();
}

class __McdFontsManagerState extends ChangeNotifierState<FontsManager> {
  @override
  Widget build(BuildContext context) {
    int iStart = 0;
    int iEnd = McdData.fontOverrides.length;
    if (widget.singleFontId != -1) {
      iStart = McdData.fontOverrides.indexWhere((fo) => fo.fontIds.contains(widget.singleFontId));
      iStart = max(0, iStart);
      iEnd = iStart + 1;
    }

    return SmoothSingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = iStart; i < iEnd; i++)
            _FontOverrideEditor(
              fontOverride: McdData.fontOverrides[i],
              singleFontId: widget.singleFontId,
              altColor: i % 2 == 1,
            ),
          if (McdData.fontOverrides.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Text("No font overrides"),
            ),
          ...[
            if (widget.singleFontId == -1) ...[
              const SizedBox(height: 16),
              SmallButton(
                onPressed: () => McdData.addFontOverride(),
                constraints: BoxConstraints.tight(const Size(30, 30)),
                child: const Icon(Icons.add),
              ),
            ],
            Row(
              children: [
                const Text("Letter Padding: "),
                makePropEditor(
                  McdData.fontAtlasLetterSpacing,
                  const PropTFOptions(hintText: "Letter Padding", constraints: BoxConstraints.tightFor(height: 30, width: 50)),
                ),
                if (widget.showResolutionScale)
                  ...[
                    const SizedBox(width: 20),
                    const Text("Resolution Scale: "),
                    makePropEditor(
                      McdData.fontAtlasResolutionScale,
                      const PropTFOptions(hintText: "Resolution Scale", constraints: BoxConstraints.tightFor(height: 30, width: 50)),
                    ),
                  ],
                for (var (label, prop) in widget.additionalProps)
                  ...[
                    const SizedBox(width: 20),
                    Text("$label: "),
                    makePropEditor(
                      prop,
                      PropTFOptions(hintText: label, constraints: const BoxConstraints.tightFor(height: 30, width: 50)),
                    ),
                  ],
              ],
            ),
            if (widget.mcd != null)
              ChangeNotifierBuilder(
                  notifier: McdData.fontOverrides,
                  builder: (context) {
                    var usedFontIds = widget.mcd!.usedFonts.keys.toList();
                    usedFontIds.sort();
                    var overrideFontIds = McdData.fontOverrides.map((e) => e.fontIds).expand((e) => e).toList();
                    var usedFontsStatus = usedFontIds.map((id) => "$id${overrideFontIds.contains(id) ? "*" : ""}");
                    return Text(
                      "Font IDs used in this file: ${usedFontsStatus.join(", ")}",
                      style: TextStyle(color: getTheme(context).textColor!.withOpacity(0.5)),
                    );
                  }
              ),
          ].map((e) => Padding(
            padding: const EdgeInsets.only(left: 20),
            child: e,
          )),
        ],
      ),
    );
  }
}

class _FontOverrideEditor extends StatelessWidget {
  static const _numberFieldConfig = PropTFOptions(constraints: BoxConstraints.tightFor(width: 50));
  final McdFontOverride fontOverride;
  final int singleFontId;
  final bool altColor;

  _FontOverrideEditor({
    required this.fontOverride,
    required this.singleFontId,
    required this.altColor,
  }) : super(key: Key(fontOverride.uuid));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: altColor ? getTheme(context).tableBgAltColor : getTheme(context).tableBgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Text("Font IDs: "),
                ChangeNotifierBuilder(
                  notifier: fontOverride.fontIds,
                  builder: (context) => Text(
                    fontOverride.fontIds.map((id) => "$id").join(", "),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => showDialog(context: context, builder: (context) => _FontOverrideIdsSelector(fontOverride)),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tight(const Size(30, 30)),
                  splashRadius: 18,
                  iconSize: 18,
                  icon: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(width: 16),
                Text(" Only as fallback: "),
                makePropEditor(
                  fontOverride.isFallbackOnly,
                ),
                Spacer(),
                SmallButton(
                  onPressed: () => McdData.fontOverrides.remove(fontOverride),
                  constraints: BoxConstraints.tight(const Size(30, 30)),
                  child: const Icon(Icons.remove, size: 18),
                ),
              ],
            ),
            Row(
              children: [
                Text("TTF/OTF Path "),
                UnderlinePropTextField(
                  prop: fontOverride.fontPath,
                  options: const PropTFOptions(constraints: BoxConstraints(minWidth: 300)),
                  validatorOnChange: (str) => str.isEmpty || File(str).existsSync() ? null : "File not found",
                  onValid: (str) => fontOverride.fontPath.value = str,
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () async {
                    var selectedFontFile = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ["ttf", "otf"],
                      allowMultiple: false,
                    );
                    if (selectedFontFile == null)
                      return;
                    var fontPath = selectedFontFile.files.first.path!;
                    fontOverride.fontPath.value = fontPath;
                  },
                  constraints: BoxConstraints.tight(const Size(30, 30)),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.folder, size: 17),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text("Scale     "),
                makePropEditor<UnderlinePropTextField>(fontOverride.heightScale, _numberFieldConfig),
                const SizedBox(width: 20),
                Text("Thickness "),
                makePropEditor<UnderlinePropTextField>(fontOverride.strokeWidth, _numberFieldConfig),
                const SizedBox(width: 20),
                Text("Shadow Blur "),
                makePropEditor<UnderlinePropTextField>(fontOverride.rgbBlurSize, _numberFieldConfig),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _make2x2Table("X Padding ", fontOverride.letXPadding, "Y Padding ", fontOverride.letYPadding),
                const SizedBox(width: 20),
                _make2x2Table("X Offset  ", fontOverride.xOffset, "Y Offset  ", fontOverride.yOffset),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _make2x2Table(String label1, Prop prop1, String label2, Prop prop2) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            Text(label1),
            makePropEditor<UnderlinePropTextField>(prop1, _numberFieldConfig),
          ]
        ),
        TableRow(
          children: [
            Text(label2),
            makePropEditor<UnderlinePropTextField>(prop2, _numberFieldConfig),
          ]
        ),
      ],
    );
  }
}

class _FontOverrideIdsSelector extends StatefulWidget {
  final McdFontOverride fontOverride;

  const _FontOverrideIdsSelector(this.fontOverride);

  State<_FontOverrideIdsSelector> createState() => _FontOverrideIdsSelectorState();
}

class _FontOverrideIdsSelectorState extends State<_FontOverrideIdsSelector> {
  @override
  Widget build(BuildContext context) {
    var blockedFontIds = McdData.fontOverrides
        .where((e) => e != widget.fontOverride)
        .expand((e) => e.fontIds)
        .toList();
    return WillPopScope(
      onWillPop: () async => true,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 500, maxWidth: 500, minHeight: 300, maxHeight: 600),
              child: Material(
                color: getTheme(context).editorBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SmoothSingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text("Font IDs", style: TextStyle(fontSize: 24)),
                        GestureDetector(
                          onTap: toggleAll,
                          behavior: HitTestBehavior.translucent,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 50),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Checkbox(
                                  tristate: true,
                                  value: widget.fontOverride.fontIds.length == McdData.availableFonts.length - blockedFontIds.length
                                      ? true
                                      : widget.fontOverride.fontIds.isEmpty
                                      ? false
                                      : null,
                                  onChanged: (value) => toggleAll(),
                                ),
                                const SizedBox(width: 4),
                                const Expanded(child: Text("Toggle All", textScaleFactor: 1.5,)),
                              ],
                            ),
                          ),
                        ),
                        for (var fontId in McdData.availableFonts.keys)
                          GestureDetector(
                            key: ValueKey(fontId),
                            onTap: !blockedFontIds.contains(fontId) ? () {
                              if (widget.fontOverride.fontIds.contains(fontId))
                                widget.fontOverride.fontIds.remove(fontId);
                              else
                                widget.fontOverride.fontIds.add(fontId);
                              setState(() {});
                            } : null,
                            behavior: HitTestBehavior.translucent,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 50),
                              child: Opacity(
                                opacity: blockedFontIds.contains(fontId) ? 0.25 : 1,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: widget.fontOverride.fontIds.contains(fontId),
                                      onChanged: !blockedFontIds.contains(fontId) ? (value) {
                                        if (value!)
                                          widget.fontOverride.fontIds.add(fontId);
                                        else
                                          widget.fontOverride.fontIds.remove(fontId);
                                        setState(() {});
                                      } : null,
                                    ),
                                    const SizedBox(width: 4),
                                    Text("$fontId", textScaleFactor: 1.5,),
                                    const SizedBox(width: 4),
                                    Image.asset("assets/mcdFonts/$fontId/_thumbnail.png"),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void toggleAll() {
    var blockedFontIds = McdData.fontOverrides
        .where((e) => e != widget.fontOverride)
        .expand((e) => e.fontIds)
        .toList();
    if (widget.fontOverride.fontIds.length == McdData.availableFonts.length - blockedFontIds.length)
      widget.fontOverride.fontIds.clear();
    else
      widget.fontOverride.fontIds
          .addAll(McdData.availableFonts.keys
          .where((e) => !widget.fontOverride.fontIds.contains(e))
          .where((e) => !blockedFontIds.contains(e)));
    setState(() {});
  }
}
