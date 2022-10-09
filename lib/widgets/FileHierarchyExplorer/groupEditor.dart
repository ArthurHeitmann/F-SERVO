
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../utils.dart';
import '../misc/SmoothSingleChildScrollView.dart';
import '../misc/smallButton.dart';
import '../propEditors/simpleProps/XmlPropEditorFactory.dart';
import '../propEditors/simpleProps/propEditorFactory.dart';
import '../propEditors/xmlActions/xmlArrayEditor.dart';

class GroupEditor extends ChangeNotifierWidget {
  GroupEditor({super.key}) : super(notifier: openHierarchyManager);

  @override
  State<GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ChangeNotifierState<GroupEditor> {
  @override
  Widget build(BuildContext context) {
    var entry = openHierarchyManager.selectedEntry;
    HapGroupHierarchyEntry? groupEntry;
    if (entry is HapGroupHierarchyEntry)
      groupEntry = entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        makeTopRow(),
        Divider(height: 1),
        Expanded(
          key: Key(openHierarchyManager.selectedEntry?.name.value ?? "noGroup"),
          child: SmoothSingleChildScrollView(
            stepSize: 60,
            controller: ScrollController(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: groupEntry != null ? makeGroupEditor(groupEntry) : makeFallback(),
            ),
          ),
        ),
      ],
    );
  }

  Widget makeTopRow() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text("GROUP EDITOR", 
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Row(
          children: [
          ],
        ),
      ],
    );
  }

  Widget makeGroupEditor(HapGroupHierarchyEntry groupEntry) {
    return ChangeNotifierBuilder(
      notifier: groupEntry.prop,
      builder: (context) {
        var tokens = groupEntry.prop.get("tokens");
        return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(flex: 1, child: Text("Name:")),
              Expanded(flex: 3, child: makePropEditor(groupEntry.name)),
            ],
          ),
          SizedBox(height: 5),
          Text("Tokens:"),
          SizedBox(height: 5),
          if (tokens != null)
            XmlArrayEditor(tokens, XmlPresets.codeAndId, tokens[0], "value", true)
          else
            SmallButton(
              onPressed: () {
                groupEntry.prop.add(XmlProp.fromXml(makeXmlElement(
                  name: "tokens",
                  children: [
                    makeXmlElement(name: "size", text: "1"),
                    makeXmlElement(name: "value", children: [
                      makeXmlElement(name: "code", text: "0x0"),
                      makeXmlElement(name: "id", text: "0x0"),
                    ])
                  ]
                )));
              },
              constraints: BoxConstraints(maxWidth: 60),
              child: Icon(Icons.add, size: 20,),
            ),
        ]
      );
      },
    );
  }

  Widget makeFallback() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text("No group selected"),
    );
  }
}
