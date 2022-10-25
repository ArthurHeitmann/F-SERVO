
import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';
import '../simpleProps/transparentPropTextField.dart';
import 'puidReferenceEditor.dart';

class ScriptVariableEditor<T extends PropTextField> extends StatelessWidget {
  final bool showDetails;
  final XmlProp prop;

  const ScriptVariableEditor({ super.key, required this.showDetails, required this.prop });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).formElementBgColor,
          borderRadius: BorderRadius.circular(4.0),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            makePropEditor<TransparentPropTextField>(prop.get("name")!.value),
            const Divider(thickness: 2,),
            PuidReferenceEditor(prop: prop.get("value")!, showDetails: showDetails),
          ],
        ),
      ),
    );
  }
}
