
import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../utils/utils.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../propEditors/xmlActions/XmlActionEditor.dart';
import 'FileType.dart';

class Outliner extends ChangeNotifierWidget {
  Outliner({super.key}) : super(notifier: areasManager);

  @override
  State<Outliner> createState() => _OutlinerState();
}

class _OutlinerState extends ChangeNotifierState<Outliner> {
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
                  notifier: areasManager.activeArea!.currentFile!,
                  builder: (context) {
                    XmlProp? xmlProp = 
                    areasManager.activeArea?.currentFile?.type == FileType.xml
                      ? (areasManager.activeArea!.currentFile! as XmlFileData).root
                      : null;
                    return xmlProp != null ? SmoothSingleChildScrollView(
                      stepSize: 60,
                      controller: ScrollController(),
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
      children: const [
        Expanded(
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
      ],
    );
  }

  Widget makeOutliner() {
    var xmlProp = (areasManager.activeArea!.currentFile! as XmlFileData).root!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: xmlProp
        .whereType<XmlActionProp>()
        .map((e) => _OutlinerEntry(action: e))
        .toList(),
    );
  }
}

class _OutlinerEntry extends ChangeNotifierWidget {
  final XmlActionProp action;

  _OutlinerEntry({required this.action}) : super(notifier: action);

  @override
  State<_OutlinerEntry> createState() => __OutlinerEntryState();
}

class __OutlinerEntryState extends ChangeNotifierState<_OutlinerEntry> {
  bool isHovering = false;
  bool isClicked = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (isClicked)
      bgColor = getTheme(context).hierarchyEntryClicked!;
    else if (isHovering)
      bgColor = getTheme(context).hierarchyEntryHovered!;
    else
      bgColor = Colors.transparent;

    return GestureDetector(
      onTapDown: (_) => setState(() => isClicked = true),
      onTapUp: (_) => setState(() => isClicked = false),
      onTap: () {
        var actionContext = getActionKey(widget.action.id.value)?.currentContext;
        if (actionContext != null)
          scrollIntoView(actionContext, duration: const Duration(milliseconds: 400), viewOffset: 45);
      },
      child: MouseRegion(
        onEnter: (event) => setState(() => isHovering = true),
        onExit: (event) => setState(() {
          isHovering = false;
          isClicked = false;
        }),
        cursor: SystemMouseCursors.click,
        child: Container(
          color: bgColor,
          // duration: const Duration(milliseconds: 75),
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
                        color: isClicked ? getTheme(context).hierarchyEntrySelectedTextColor : null,
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
