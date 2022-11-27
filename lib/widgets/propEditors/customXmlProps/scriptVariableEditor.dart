
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../filesView/xmlJumpToLineEventWrapper.dart';
import '../../misc/Selectable.dart';
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
    return optionalIdAnchor(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          decoration: BoxDecoration(
            color: getTheme(context).formElementBgColor,
            borderRadius: BorderRadius.circular(4.0),
          ),
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              makePropEditor<TransparentPropTextField>(prop.get("name")!.value),
              const Divider(thickness: 2,),
              PuidReferenceEditor(prop: prop.get("value")!, showDetails: showDetails),
            ],
          ),
        ),
      ),
    );
  }

  Widget optionalIdAnchor({ required Widget child }) {
    var idProp = prop.get("id");
    if (idProp == null)
      return child;
    return XmlWidgetWithId(
      id: idProp.value as HexProp,
      child: child,
    );
  }
}
