
import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import '../../stateManagement/events/jumpToEvents.dart';
import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../../stateManagement/openFiles/openFileTypes.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../propEditors/simpleProps/UnderlinePropTextField.dart';
import '../propEditors/simpleProps/propEditorFactory.dart';
import '../propEditors/simpleProps/propTextField.dart';
import 'FileType.dart';

class Outliner extends ChangeNotifierWidget {
  Outliner({super.key}) : super(notifier: areasManager);

  @override
  State<Outliner> createState() => _OutlinerState();
}

class _OutlinerState extends ChangeNotifierState<Outliner> {
  final StringProp search = StringProp("");
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    search.changesUndoable = false;
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // several listeners are needed to get the current and loaded file
    // active area, active file, file state
    return ChangeNotifierBuilder(
        key: Key(areasManager.activeArea!.uuid),
        notifier: areasManager.activeArea!,
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            makeTopRow(),
            const Divider(height: 1),
            Expanded(
              child: areasManager.activeArea?.currentFile?.type == FileType.xml
                ? ChangeNotifierBuilder(
                  key: Key(areasManager.activeArea!.currentFile!.uuid),
                  notifiers: [areasManager.activeArea!.currentFile!, search],
                  builder: (context) {
                    XmlProp? xmlProp = 
                    areasManager.activeArea?.currentFile?.type == FileType.xml
                      ? (areasManager.activeArea!.currentFile! as XmlFileData).root
                      : null;
                    return xmlProp != null ? SmoothSingleChildScrollView(
                      stepSize: 60,
                      controller: scrollController,
                      child: makeOutliner(),
                    ) : Container();
                  }
                )
                : Container(),
            ),
          ]
        ),
      );
  }
  
  Widget makeTopRow() {
    return Row(
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text("OUTLINER", 
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        makePropEditor<UnderlinePropTextField>(
          search, const PropTFOptions(
            constraints: BoxConstraints(minWidth: 125),
            hintText: "Search...",
          )
        ),
      ],
    );
  }

  Widget makeOutliner() {
    var xmlProp = (areasManager.activeArea!.currentFile! as XmlFileData).root!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: xmlProp
        .whereType<XmlActionProp>()
        .where((e) => e.name.toString().toLowerCase().contains(search.value.toLowerCase()))
        .map((e) => _OutlinerEntry(key: Key(e.uuid), action: e))
        .toList(),
    );
  }
}

class _OutlinerEntry extends ChangeNotifierWidget {
  final XmlActionProp action;

  _OutlinerEntry({ super.key, required this.action }) : super(notifier: action);

  @override
  State<_OutlinerEntry> createState() => __OutlinerEntryState();
}

class __OutlinerEntryState extends ChangeNotifierState<_OutlinerEntry> {
  @override
  Widget build(BuildContext context) {
    var textColor = getTheme(context).textColor!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          var file = areasManager.fromId(widget.action.file!);
          jumpToStream.add(JumpToIdEvent(file!, widget.action.id.value));
        },
        splashColor: textColor.withOpacity(0.2),
        hoverColor: textColor.withOpacity(0.1),
        highlightColor: textColor.withOpacity(0.1),
        child: Container(
          height: 25,
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right, size: 19,),
              const SizedBox(width: 3),
              Expanded(
                child: ChangeNotifierBuilder(
                  notifier: widget.action.name,
                  builder: (context) {
                    return Text(widget.action.name.toString(), 
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
