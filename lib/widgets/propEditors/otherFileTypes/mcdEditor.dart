
import 'package:context_menus/context_menus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../stateManagement/otherFileTypes/McdData.dart';
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
    return Column(
      children: [
        const SizedBox(height: 35),
        Row(
          children: [
            _makeTabButton(0, "MCD Events"),
            _makeTabButton(1, "Font overrides"),
          ]
        ),
        const Divider(height: 1,),
        Expanded(
          child: IndexedStack(
            index: activeTab,
            children: [
              widget.file.loadingState == LoadingState.loaded
                ? _McdEditorBody(file: widget.file, mcd: widget.file.mcdData!)
                : const SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
                ),
              _McdFontsManager(),
            ],
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
  _McdFontsManager() : super(notifier: McdData.fontOverrides);

  @override
  State<_McdFontsManager> createState() => __McdFontsManagerState();
}

class __McdFontsManagerState extends ChangeNotifierState<_McdFontsManager> {
  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SmoothSingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ColumnSeparated(
          children: [
            const Text("Font Overrides", textScaleFactor: 1.1,),
            for (int i = 0; i < McdData.fontOverrides.length; i++)
              Row(
                key: Key(McdData.fontOverrides[i].uuid),
                children: [
                  makePropEditor(
                    McdData.fontOverrides[i].fontId,
                    const PropTFOptions(
                      hintText: "ID",
                      constraints: BoxConstraints.tightFor(height: 30, width: 60),
                    ),
                  ),
                  const SizedBox(width: 10,),
                  Expanded(
                    child: makePropEditor(
                      McdData.fontOverrides[i].fontPath,
                      const PropTFOptions(hintText: "Font Path", constraints: BoxConstraints.tightFor(height: 30),),
                    ),
                  ),
                  const SizedBox(width: 10,),
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
                    child: const Icon(Icons.folder, size: 18),
                  ),
                  const SizedBox(width: 10,),
                  SmallButton(
                    onPressed: () => McdData.fontOverrides.removeAt(i),
                    constraints: BoxConstraints.tight(const Size(30, 30)),
                    child: const Icon(Icons.remove, size: 18),
                  ),
                ],
              ),
              SmallButton(
                onPressed: () => McdData.addFontOverride(),
                constraints: BoxConstraints.tight(const Size(30, 30)),
                child: const Icon(Icons.add),
              ),
          ],
        ),
      ),
    );
  }
}
