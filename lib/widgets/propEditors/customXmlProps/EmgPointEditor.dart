
import 'package:flutter/material.dart';

import '../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../xmlActions/xmlArrayEditor.dart';

class XmlEmgPointEditor extends StatefulWidget {
  final XmlProp prop;
  final bool showDetails;

  const XmlEmgPointEditor({ super.key, required this.showDetails, required this.prop });

  @override
  State<XmlEmgPointEditor> createState() => _XmlEmgPointEditorState();
}

class _XmlEmgPointEditorState extends State<XmlEmgPointEditor> {
  bool isCollapsed = false;

  int get numChildren => widget.prop.get("nodes")!.length - 1;
  static const int collapsedNumChildren = 4;

  @override
  void initState() {
    if (numChildren >= collapsedNumChildren)
      isCollapsed = true;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var attribute = widget.prop.get("attribute")!;
    var nodes = widget.prop.get("nodes")!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text("Spawn Nodes", style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        if (widget.showDetails)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: makeXmlPropEditor(attribute, widget.showDetails),
          ),
        if (isCollapsed)
          Center(
            child: OutlinedButton(
              onPressed: () => setState(() => isCollapsed = false),
              child: Text("Show All ${nodes.length - 1} Nodes"),
            ),
          )
        else
          XmlArrayEditor(nodes, XmlPresets.spawnNode, nodes[0], "value", widget.showDetails),
        if (!isCollapsed && numChildren >= collapsedNumChildren)
          Center(
            child: OutlinedButton(
              onPressed: () => setState(() => isCollapsed = true),
              child: const Text("Hide Nodes"),
            ),
          ),
      ],
    );
  }
}
