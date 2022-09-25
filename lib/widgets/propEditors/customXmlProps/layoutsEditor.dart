
import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../simpleProps/XmlPropEditorFactory.dart';

class LayoutsEditor extends StatelessWidget {
  final bool showDetails;
  final XmlProp prop;

  const LayoutsEditor({super.key, required this.prop, required this.showDetails});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDetails)
          makeXmlPropEditor(prop.get("normal")!.get("parent")!, showDetails),
        makeXmlPropEditor(prop.get("normal")!.get("layouts")!, showDetails),
      ],
    );
  }
}
