

import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/otherFileTypes/McdData.dart';
import '../../../utils/utils.dart';
import '../../misc/ColumnSeparated.dart';
import '../../misc/SmoothScrollBuilder.dart';
import '../../misc/smallButton.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/primaryPropTextField.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';

class FontsManager extends ChangeNotifierWidget {
  final McdData? mcd;
  final int singleFontId;

  FontsManager({super.key, this.mcd, this.singleFontId = -1}) : super(notifier: McdData.fontOverrides);

  @override
  State<FontsManager> createState() => __McdFontsManagerState();
}

class __McdFontsManagerState extends ChangeNotifierState<FontsManager> {
  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    const columnNames = ["", "Font IDs", "absScale", "TTF/OTF Path", "", "locScale", "xPadding", "yPadding", "xOffset", "yOffset", "", ""];

    int iStart = 0;
    int iEnd = McdData.fontOverrides.length;
    if (widget.singleFontId != -1) {
      iStart = McdData.fontOverrides.indexWhere((fo) => fo.fontIds.contains(widget.singleFontId));
      iStart = max(0, iStart);
      iEnd = iStart + 1;
    }

    return SmoothSingleChildScrollView(
      controller: scrollController,
      child: ColumnSeparated(
        children: [
          Table(
            // columns:
            // X: spacer
            // 0: fontIDs
            // 1: height scale
            // 2: fontFilePath
            // 3: file path selector
            // 4: scale
            // 5: x letter padding
            // 6: y letter padding
            // 7: y Offset
            // 8: y Offset
            // 9: remove button
            // X: spacer
            columnWidths: const {
              0: FixedColumnWidth(16),
              1: FixedColumnWidth(100 + 8),
              2: FixedColumnWidth(60 + 8),
              3: FlexColumnWidth(1),
              4: FixedColumnWidth(30 + 8),
              5: FixedColumnWidth(60 + 8),
              6: FixedColumnWidth(60 + 8),
              7: FixedColumnWidth(60 + 8),
              8: FixedColumnWidth(60 + 8),
              9: FixedColumnWidth(60 + 8),
              10: FixedColumnWidth(30 + 8),
              11: FixedColumnWidth(16),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                  children: List.generate(columnNames.length, (i) =>
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: getTheme(context).tableBgColor,
                          border: between(i, 1, columnNames.length - 4)
                              ? Border(
                            right: BorderSide(
                              color: getTheme(context).dividerColor!,
                              width: 1,
                            ),
                          )
                              : null,
                        ),
                        child: Center(
                          child: Text(columnNames[i], textScaleFactor: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ))
              ),
              for (int i = iStart; i < iEnd; i++)
                TableRow(
                  key: ValueKey(McdData.fontOverrides[i].uuid),
                  children: [
                    const SizedBox(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: ChangeNotifierBuilder(
                              notifier: McdData.fontOverrides[i].fontIds,
                              builder: (context) => Text(
                                McdData.fontOverrides[i].fontIds.map((id) => "$id").join(", "),
                                overflow: TextOverflow.ellipsis,
                              )
                          ),
                        ),
                        IconButton(
                          onPressed: () => showDialog(context: context, builder: (context) => _FontOverrideIdsSelector(McdData.fontOverrides[i]),),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints.tight(const Size(30, 30)),
                          splashRadius: 18,
                          iconSize: 18,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].heightScale,
                      const PropTFOptions(hintText: "absScale", constraints: BoxConstraints.tightFor(height: 30)),
                    ),
                    PrimaryPropTextField(
                      prop: McdData.fontOverrides[i].fontPath,
                      options: const PropTFOptions(hintText: "Font Path", constraints: BoxConstraints.tightFor(height: 30)),
                      validatorOnChange: (str) => File(str).existsSync() ? null : "File not found",
                      onValid: (str) => McdData.fontOverrides[i].fontPath.value = str,
                    ),
                    SmallButton(
                      onPressed: () async {
                        var selectedFontFile = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ["ttf", "otf"],
                          allowMultiple: false,
                        );
                        if (selectedFontFile == null)
                          return;
                        var fontPath = selectedFontFile.files.first.path!;
                        McdData.fontOverrides[i].fontPath.value = fontPath;
                      },
                      constraints: BoxConstraints.tight(const Size(30, 30)),
                      child: const Icon(Icons.folder, size: 17),
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].scale,
                      const PropTFOptions(hintText: "scale", constraints: BoxConstraints.tightFor(height: 30)),
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].letXPadding,
                      const PropTFOptions(hintText: "X Padding", constraints: BoxConstraints.tightFor(height: 30)),
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].letYPadding,
                      const PropTFOptions(hintText: "Y Padding", constraints: BoxConstraints.tightFor(height: 30)),
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].xOffset,
                      const PropTFOptions(hintText: "X Offset", constraints: BoxConstraints.tightFor(height: 30)),
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].yOffset,
                      const PropTFOptions(hintText: "Y Offset", constraints: BoxConstraints.tightFor(height: 30)),
                    ),
                    SmallButton(
                      onPressed: () => McdData.fontOverrides.removeAt(i),
                      constraints: BoxConstraints.tight(const Size(30, 30)),
                      child: const Icon(Icons.remove, size: 18),
                    ),
                    const SizedBox(),
                  ].map((e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: e,
                  )).toList(),
                ),
            ],
          ),
          if (McdData.fontOverrides.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Text("No font overrides"),
            ),
          ...[
            if (widget.singleFontId == -1)
              SmallButton(
                onPressed: () => McdData.addFontOverride(),
                constraints: BoxConstraints.tight(const Size(30, 30)),
                child: const Icon(Icons.add),
              ),
            Row(
              children: [
                const Text("Letter Spacing: "),
                makePropEditor(
                  McdData.fontAtlasLetterSpacing,
                  const PropTFOptions(hintText: "Letter Spacing", constraints: BoxConstraints.tightFor(height: 30, width: 50)),
                ),
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
          )).toList(),
        ],
      ),
    );
  }
}

class _FontOverrideIdsSelector extends StatefulWidget {
  final McdFontOverride fontOverride;

  const _FontOverrideIdsSelector(this.fontOverride);

  @override
  State<_FontOverrideIdsSelector> createState() => _FontOverrideIdsSelectorState();
}

class _FontOverrideIdsSelectorState extends State<_FontOverrideIdsSelector> {
  final scrollController = ScrollController();

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
                    controller: scrollController,
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
