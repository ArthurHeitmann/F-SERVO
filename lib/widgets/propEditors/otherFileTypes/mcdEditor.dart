
import 'package:context_menus/context_menus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/changesExporter.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../stateManagement/otherFileTypes/McdData.dart';
import '../../../stateManagement/otherFileTypes/McdFontDebugger.dart';
import '../../../utils/utils.dart';
import '../../misc/ColumnSeparated.dart';
import '../../misc/RowSeparated.dart';
import '../../misc/SmoothScrollBuilder.dart';
import '../../misc/nestedContextMenu.dart';
import '../../misc/smallButton.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/UnderlinePropTextField.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';

class McdEditor extends ChangeNotifierWidget {
  final McdFileData file;

  McdEditor ({super.key, required this.file }) : super(notifier: file);

  @override
  State<McdEditor> createState() => _McdEditorState();
}

class _McdEditorState extends ChangeNotifierState<McdEditor> {
  int activeTab = 0;

  @override
  void initState() {
    widget.file.load()
      .then((value) => setState(() {}));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var loadingIndicator = const SizedBox(
      height: 2,
      child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
    );
    return Column(
      children: [
        const SizedBox(height: 35),
        Material(
          color: Colors.transparent,
          child: Row(
            children: [
              _makeTabButton(0, "MCD Events"),
              _makeTabButton(1, "Font overrides"),
              _makeTabButton(2, "Font debugger"),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 20,
                decoration: BoxDecoration(
                  color: getTheme(context).textColor!.withOpacity(0.25),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save),
                splashRadius: 24,
                onPressed: () async {
                  await widget.file.save();
                  await processChangedFiles();
                },
              ),
            ]
          ),
        ),
        const Divider(height: 1,),
        Expanded(
          child: IndexedStack(
            index: activeTab,
            children: widget.file.loadingState == LoadingState.loaded ? [
              _McdEditorBody(file: widget.file, mcd: widget.file.mcdData!),
              _McdFontsManager(widget.file.mcdData!),
              McdFontDebugger(
                texturePath: widget.file.mcdData!.textureWtpPath!.value,
                fonts: widget.file.mcdData!.usedFonts.values.toList(),
              ),
            ] : List.filled(3, loadingIndicator),
          ),
        ),
      ],
    );
  }

  Widget _makeTabButton(int index, String text) {
    return Flexible(
      child: SizedBox(
        width: 150,
        height: 40,
        child: TextButton(
            onPressed: () {
              if (activeTab == index)
                return;
              setState(() => activeTab = index);
            },
            style: ButtonStyle(
              backgroundColor: activeTab == index
                ? MaterialStateProperty.all(getTheme(context).textColor!.withOpacity(0.1))
                : MaterialStateProperty.all(Colors.transparent),
              foregroundColor: activeTab == index
                ? MaterialStateProperty.all(getTheme(context).textColor)
                : MaterialStateProperty.all(getTheme(context).textColor!.withOpacity(0.5)),
            ),
            child: Text(
              text,
              textScaleFactor: 1.25,
            ),
          ),
      ),
    );
  }
}

class _McdEditorBody extends ChangeNotifierWidget {
  final McdFileData file;
  final McdData mcd;

  _McdEditorBody({ required this.file, required this.mcd }) : super(notifier: mcd.events);

  @override
  State<_McdEditorBody> createState() => _McdEditorBodyState();
}

class _McdEditorBodyState extends ChangeNotifierState<_McdEditorBody> {
  final scrollController = ScrollController();
  List<Tuple2<int, McdEvent>> events = [];
  StringProp search = StringProp("");

  @override
  void initState() {
    search.addListener(() => setState(() {}));
    super.initState();
  }

  void updateEvents() {
    var searchLower = search.value.toLowerCase();
    var allEvents = List.generate(
      widget.mcd.events.length,
      (index) => Tuple2(index, widget.mcd.events[index])
    );

    events = allEvents.where((e) {
      var event = e.item2;
      return event.name.value.toLowerCase().contains(searchLower) ||
        event.paragraphs.any((p) => p.lines.any((l) => l.text.value.toLowerCase().contains(searchLower)));
    }).toList();
    
    events.sort((a, b) => a.item2.msgSeqNum.value.compareTo(b.item2.msgSeqNum.value));
  }

  @override
  Widget build(BuildContext context) {
    updateEvents();
    
    return Column(
      children: [
        _makeHeader(context),
        Expanded(
          child: Stack(
            children: [
              SmoothScrollBuilder(
                controller: scrollController,
                builder: (context, controller, physics) {
                  return ListView.builder(
                    controller: controller,
                    physics: physics,
                    itemCount: events.length,
                    itemBuilder: (context, i) => NestedContextMenu(
                      key: Key(events[i].item2.uuid),
                      clearParent: true,
                      buttons: [
                        ContextMenuButtonConfig(
                          "Remove Event",
                          icon: const Icon(Icons.remove),
                          onPressed: () => widget.mcd.removeEvent(events[i].item1),
                        ),
                      ],
                      child: _McdEventEditor(
                        file: widget.file,
                        event: events[i].item2,
                        altColor: i % 2 == 1,
                      ),
                    ),
                  );
                }
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: FloatingActionButton(
                    onPressed: () => widget.mcd.addEvent(),
                    foregroundColor: getTheme(context).textColor,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _makeHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, right: 8, left: 8, bottom: 8),
      color: getTheme(context).tableBgColor,
      child: RowSeparated(
        children: [
          Flexible(
            child: SizedBox(
              width: 300,
              child: UnderlinePropTextField(
                prop: search,
                options: const PropTFOptions(
                  hintText: "Search",
                  useIntrinsicWidth: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _McdEventEditor extends ChangeNotifierWidget {
  final McdFileData file;
  final McdEvent event;
  final bool altColor;

  _McdEventEditor({ required this.file, required this.event, required this.altColor }) : super(notifier: event.paragraphs);

  @override
  State<_McdEventEditor> createState() => _McdEventEditorState();
}

class _McdEventEditorState extends ChangeNotifierState<_McdEventEditor> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.altColor ? getTheme(context).tableBgAltColor : getTheme(context).tableBgColor,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RowSeparated(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: makePropEditor(
                  widget.event.name, const PropTFOptions(
                    useIntrinsicWidth: false,
                    constraints: BoxConstraints.tightFor(height: 35),
                  )
                )),
                const SizedBox(width: 10,),
                const Text("ID"),
                makePropEditor(widget.event.eventId),
                const Text("SeqNum"),
                makePropEditor(widget.event.msgSeqNum),
              ]
            ),
            const SizedBox(height: 5,),
            for (int i = 0; i < widget.event.paragraphs.length; i++)
              NestedContextMenu(
                key: Key(widget.event.paragraphs[i].uuid),
                clearParent: true,
                buttons: [
                  ContextMenuButtonConfig(
                    "Remove Paragraph",
                    icon: const Icon(Icons.remove),
                    onPressed: () => widget.event.removeParagraph(i)
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _McdParagraphEditor(
                    file: widget.file,
                    paragraph: widget.event.paragraphs[i],
                  ),
                ),
              ),
            const SizedBox(height: 5,),
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: "Add Paragraph",
                waitDuration: const Duration(milliseconds: 500),
                child: IconButton(
                  onPressed: () => widget.event.addParagraph(widget.file.mcdData!.usedFonts.keys.firstWhere((id) => id != 0)),
                  constraints: BoxConstraints.tight(const Size(30, 30)),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add),
                  splashRadius: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _McdParagraphEditor extends ChangeNotifierWidget {
  final McdFileData file;
  final McdParagraph paragraph;

  _McdParagraphEditor({ required this.file, required this.paragraph }) : super(notifier: paragraph.lines);

  @override
  State<_McdParagraphEditor> createState() => __McdParagraphEditorState();
}

class __McdParagraphEditorState extends ChangeNotifierState<_McdParagraphEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // info
        Row(
          children: [
            Expanded(
              child: Text(
                "${pluralStr(widget.paragraph.lines.length, "Line")}:",
                textScaleFactor: 1.1,
              ),
            ),
            const SizedBox(width: 10,),
            const Text("fontID "),
            makePropEditor<UnderlinePropTextField>(widget.paragraph.fontId),
            const Text("vPos "),
            makePropEditor<UnderlinePropTextField>(widget.paragraph.vPos),
          ],
        ),
        const SizedBox(height: 5,),
        // paragraphs
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i <  widget.paragraph.lines.length; i++) 
              Row(
                key: Key(widget.paragraph.lines[i].uuid),
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: makePropEditor<UnderlinePropTextField>(widget.paragraph.lines[i].text),
                    ),
                  ),
                  const SizedBox(width: 10,),
                  IconButton(
                    onPressed: () => widget.paragraph.removeLine(i),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                    constraints: BoxConstraints.tight(const Size(25, 25)),
                    icon: const Icon(Icons.remove),
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: "Add Line",
                waitDuration: const Duration(milliseconds: 500),
                child: IconButton(
                  onPressed: () => widget.paragraph.addLine(),
                  constraints: BoxConstraints.tight(const Size(25, 25)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  splashRadius: 18,
                  iconSize: 18,
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10,),
      ],
    );
  }
}

class _McdFontsManager extends ChangeNotifierWidget {
  final McdData mcd;

  _McdFontsManager(this.mcd) : super(notifier: McdData.fontOverrides);

  @override
  State<_McdFontsManager> createState() => __McdFontsManagerState();
}

class __McdFontsManagerState extends ChangeNotifierState<_McdFontsManager> {
  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SmoothSingleChildScrollView(
      controller: scrollController,
      child: ColumnSeparated(
        children: [
          Table(
            // columns:
            // -1: spacer
            // 0: fontID
            // 1: fontHeight
            // 2: fontFilePath
            // 3: file path selector
            // 3:x: apply to all
            // 4: scale
            // -: x Offset
            // -: y Offset
            // 7: remove button
            // 8: spacer
            columnWidths: const {
              0: FixedColumnWidth(16),
              1: FixedColumnWidth(50 + 8),
              2: FixedColumnWidth(50 + 8),
              3: FlexColumnWidth(1),
              4: FixedColumnWidth(30 + 8),
              5: FixedColumnWidth(30 + 8),
              6: FixedColumnWidth(50 + 8),
              7: FixedColumnWidth(30 + 8),
              8: FixedColumnWidth(16),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: ["", "Font ID", "Height", "File Path", "", "", "Scale", "", ""]
                  .map((e) => Container(
                    color: getTheme(context).tableBgColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(e, textScaleFactor: 1,)
                    ),
                  ))
                  .toList(),
              ),
              for (int i = 0; i < McdData.fontOverrides.length; i++)
                TableRow(
                  key: ValueKey(McdData.fontOverrides[i].uuid),
                  children: [
                    const SizedBox(),
                    makePropEditor(
                      McdData.fontOverrides[i].fontId,
                      const PropTFOptions(hintText: "ID", constraints: BoxConstraints.tightFor(height: 30)),
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].fontHeight,
                      const PropTFOptions(hintText: "height", constraints: BoxConstraints.tightFor(height: 30)),
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].fontPath,
                      const PropTFOptions(hintText: "Font Path", constraints: BoxConstraints.tightFor(height: 30)),
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
                    Tooltip(
                      message: "Apply to all",
                      waitDuration: const Duration(milliseconds: 500),
                      child: SmallButton(
                        onPressed: () {
                          var ownPath = McdData.fontOverrides[i].fontPath.value;
                          for (var fontOverride in McdData.fontOverrides)
                            fontOverride.fontPath.value = ownPath;
                        },
                        constraints: BoxConstraints.tight(const Size(30, 30)),
                        child: const Icon(Icons.sync_alt, size: 17),
                      ),
                    ),
                    makePropEditor(
                      McdData.fontOverrides[i].fontScale,
                      const PropTFOptions(hintText: "scale", constraints: BoxConstraints.tightFor(height: 30)),
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
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: SmallButton(
              onPressed: () => McdData.addFontOverride(),
              constraints: BoxConstraints.tight(const Size(30, 30)),
              child: const Icon(Icons.add),
            ),
          ),
          ChangeNotifierBuilder(
            notifier: McdData.fontOverrides,
            builder: (context) {
              var usedFontIds = widget.mcd.usedFonts.keys.toList();
              usedFontIds.sort();
              var usedFontsStatus = usedFontIds.map((e) => "$e${McdData.fontOverrides.any((fo) => fo.fontId.value == e) ? "*" : ""}");
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 10),
                    child: Text(
                      "Font IDs used in this file: ${usedFontsStatus.join(", ")}",
                      style: TextStyle(color: getTheme(context).textColor!.withOpacity(0.5)),
                    ),
                  ),
                  if (McdData.fontOverrides.any((fo) => fo.fontId.value == 8 || fo.fontId.value == 9))
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 10),
                      child: Text(
                        "Font IDs 8 and 9 are Angelic fonts. Don't override them unless you know what you're doing.",
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }
}
