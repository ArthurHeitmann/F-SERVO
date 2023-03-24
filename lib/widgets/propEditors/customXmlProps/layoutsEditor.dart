
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
    return Column(
      children: [
        if (showDetails)
          Row(
            children: [
              Text("parent", style: getTheme(context).propInputTextStyle,),
              const SizedBox(width: 10),
              Flexible(
                child: PuidReferenceEditor(prop: prop.get("normal")!.get("parent")!.get("id")!.get("id")!, showDetails: showDetails)
              ),
            ],
          ),
        if (showDetails && prop.get("normal")!.get("flags") != null)
          makeXmlPropEditor(prop.get("normal")!.get("flags")!, showDetails),
        makeXmlPropEditor(prop.get("normal")!.get("layouts")!, showDetails),
      ],
    );
  }
}
