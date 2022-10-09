
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../simpleProps/XmlPropEditor.dart';
import '../simpleProps/propEditorFactory.dart';

class ParamsEditor extends StatelessWidget {
  final bool showDetails;
  final XmlProp prop;

  const ParamsEditor({super.key, required this.prop, required this.showDetails});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).formElementBgColor,
          border: Border.all(color: getTheme(context).propBorderColor!, width: 0.5),
          borderRadius: BorderRadius.all(Radius.circular(10))
        ),
        // padding: const EdgeInsets.all(2),
        child: IntrinsicWidth(
          child: Wrap(
            direction: Axis.horizontal,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              makePropEditor(prop[0].value),
              if (showDetails || (prop[1].value as HexProp).strVal == "type")
                makePropEditor(prop[1].value),
              if (prop[2].isEmpty)
                makePropEditor(prop[2].value)
              else
                XmlPropEditor(prop: prop[2], showDetails: false, showTagName: false,)
            ],
          ),
        ),
      ),
    );
  }
}
