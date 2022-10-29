
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../stateManagement/otherFileTypes/McdData.dart';
import '../../../utils.dart';
import '../../misc/ColumnSeparated.dart';
import '../../misc/RowSeparated.dart';
import '../../misc/SmoothSingleChildScrollView.dart';
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
  @override
  void initState() {
    widget.file.load()
      .then((value) => setState(() {}));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.file.loadingState != LoadingState.loaded || true) {
      return Column(
        children: const [
          SizedBox(height: 35),
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          ),
        ],
      );
    }

    return _McdEditorBody(file: widget.file, mcd: widget.file.mcdData!);
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
  @override
  Widget build(BuildContext context) {
    var sortedEvents = widget.mcd.events
      .toList()
      ..sort((a, b) => a.msgSeqNum.value.compareTo(b.msgSeqNum.value));
    return Stack(
      children: [
        ListView.builder(
          itemCount: widget.mcd.events.length,
          itemBuilder: (context, i) => NestedContextMenu(
            key: Key(sortedEvents[i].uuid),
            clearParent: true,
            buttons: [
              ContextMenuButtonConfig(
                "Remove Event",
                icon: const Icon(Icons.remove),
                onPressed: () => widget.mcd.removeEvent(i)
              ),
            ],
            child: _McdEventEditor(
              file: widget.file,
              event: sortedEvents[i],
              altColor: i % 2 == 1,
            ),
          ),
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
    );
  }
}

class _McdEventEditor extends ChangeNotifierWidget {
  final McdFileData file;
  final McdEvent event;
  final bool altColor;

  _McdEventEditor({ super.key, required this.file, required this.event, required this.altColor }) : super(notifier: event.paragraphs);

  @override
  State<_McdEventEditor> createState() => _McdEventEditorState();
}

class _McdEventEditorState extends ChangeNotifierState<_McdEventEditor> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.altColor ? getTheme(context).tableBgAltColor : getTheme(context).tableBgColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
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
                  onPressed: () => widget.event.addParagraph(widget.file.mcdData!.usedFonts.firstWhere((f) => f.fontId != 0)),
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

  _McdParagraphEditor({ super.key, required this.file, required this.paragraph }) : super(notifier: paragraph.lines);

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
