
import 'package:flutter/material.dart';

import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import 'puidReferenceEditor.dart';

class LayoutsEditor extends StatelessWidget {
  final bool showDetails;
  final XmlProp prop;

  const LayoutsEditor({super.key, required this.prop, required this.showDetails});

  @override
  Widget build(BuildContext context) {
    XmlProp? parent;
    parent ??= prop.get("normal");
    parent ??= prop;
    
    return Column(
      children: [
        if (showDetails)
          Row(
            children: [
              Text("parent", style: getTheme(context).propInputTextStyle,),
              const SizedBox(width: 10),
              Flexible(
                child: PuidReferenceEditor(prop: parent.get("parent")!.get("id")!.get("id")!, showDetails: showDetails)
              ),
            ],
          ),
        if (showDetails && parent.get("flags") != null)
          makeXmlPropEditor(parent.get("flags")!, showDetails),
        ...makeXmlMultiPropEditor(parent.get("layouts")!, showDetails),
      ],
    );
  }
}
