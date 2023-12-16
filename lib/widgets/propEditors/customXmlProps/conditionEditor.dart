
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../utils/labelsPresets.dart';
import '../../../utils/utils.dart';
import '../../../widgets/theme/customTheme.dart';
import '../../misc/ChangeNotifierWidget.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';
import '../simpleProps/textFieldAutocomplete.dart';
import '../simpleProps/transparentPropTextField.dart';
import 'puidReferenceEditor.dart';

class ConditionEditor extends ChangeNotifierWidget {
  final XmlProp prop;
  final bool showDetails;

  ConditionEditor({super.key, required this.prop, required this.showDetails}) : super(notifiers: [prop, prop.get("condition")!.get("state")!]);

  @override
  State<ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends ChangeNotifierState<ConditionEditor> {
  @override
  Widget build(BuildContext context) {
    var conditionState = widget.prop.get("condition")?.get("state");
    var label = conditionState?.get("label")?.value;
    var value = conditionState?.get("value");
    var args = widget.prop.get("args");
    var type = widget.prop.get("type");
    var fileId = widget.prop.file;

    return Padding(
      padding: const EdgeInsets.all(4.0),
    child: Row(
        children: [
          const Text(
            "?",
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NestedContextMenu(
              buttons: [
                if (widget.showDetails)
                  optionalValPropButtonConfig(
                    widget.prop, "type", () => 0,
                    () => NumberProp(0, true, fileId: fileId)
                  ),
                if (label == null)
                  optionalValPropButtonConfig(
                    conditionState!, "label", () => 0,
                    () => StringProp("conditionLabel", fileId: fileId)
                  ),
                optionalValPropButtonConfig(
                  conditionState!, "value", () => conditionState.length,
                  () => NumberProp(1, true, fileId: fileId)
                ),
                optionalValPropButtonConfig(
                  widget.prop, "args", () => widget.prop.length,
                  () => StringProp("arg", fileId: fileId)
                ),
              ],
              child: Material(
                color: getTheme(context).formElementBgColor,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PuidReferenceEditor(prop: widget.prop.get("puid")!, showDetails: widget.showDetails),
                      Divider(color: getTheme(context).textColor!.withOpacity(0.5), thickness: 2,),
                      if (label != null)
                        makePropEditor<TransparentPropTextField>(label, PropTFOptions(
                          autocompleteOptions: () => conditionLabels
                            .map((l) => AutocompleteConfig(l))
                        )),
                      if (value != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: makeXmlPropEditor<TransparentPropTextField>(value, widget.showDetails),
                        ),
                      if (args != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: makeXmlPropEditor<TransparentPropTextField>(args, widget.showDetails),
                        ),
                      if (type != null && widget.showDetails)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: makeXmlPropEditor<TransparentPropTextField>(type, widget.showDetails),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ]
      ),
    );
  }
}


