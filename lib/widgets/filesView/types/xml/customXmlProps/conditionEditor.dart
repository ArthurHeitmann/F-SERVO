import 'package:flutter/material.dart';

import '../../../../../stateManagement/Property.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../../../utils/labelsPresets.dart';
import '../../../../../utils/utils.dart';
import '../../../../misc/ChangeNotifierWidget.dart';
import '../../../../misc/nestedContextMenu.dart';
import '../../../../misc/selectionPopup.dart';
import '../../../../propEditors/propEditorFactory.dart';
import '../../../../propEditors/propTextField.dart';
import '../../../../propEditors/textFieldAutocomplete.dart';
import '../../../../propEditors/transparentPropTextField.dart';
import '../../../../theme/customTheme.dart';
import '../XmlPropEditorFactory.dart';
import 'conditionEnums.dart';
import 'puidReferenceEditor.dart';

class ConditionEditor extends ChangeNotifierWidget {
  final XmlProp prop;
  final bool showDetails;

  ConditionEditor({super.key, required this.prop, required this.showDetails})
    : super(
        notifiers: [
          prop,
          prop.get("condition")!,
          prop.get("condition")!.get("state")!,
        ],
      );

  @override
  State<ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends ChangeNotifierState<ConditionEditor> {
  @override
  Widget build(BuildContext context) {
    var conditionState = widget.prop.get("condition")?.get("state");
    var pred = widget.prop.get("condition")?.get("pred");
    var label = conditionState?.get("label");
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
                optionalValPropButtonConfig(
                  widget.prop,
                  "type",
                  () => 0,
                  () => NumberProp(0, true, fileId: fileId),
                ),
                if (label == null)
                  optionalValPropButtonConfig(
                    conditionState!,
                    "label",
                    () => 0,
                    () => StringProp("conditionLabel", fileId: fileId),
                  ),
                optionalValPropButtonConfig(
                  conditionState!,
                  "value",
                  () => conditionState.length,
                  () => NumberProp(1, true, fileId: fileId),
                ),
                optionalValPropButtonConfig(
                  widget.prop,
                  "args",
                  () => widget.prop.length,
                  () => StringProp("arg", fileId: fileId),
                ),
              ],
              child: Material(
                color: getTheme(context).formElementBgColor,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PuidReferenceEditor(
                        prop: widget.prop.get("puid")!,
                        showDetails: widget.showDetails,
                      ),
                      Divider(
                        color: getTheme(context).textColor!.withOpacity(0.5),
                        thickness: 2,
                      ),
                      if (label != null) _makeLabelEditor(label),
                      if (value != null) _makeXmlPropEditor(value),
                      if (args != null) _makeXmlPropEditor(args),
                      if (type != null) _makeTypeEditor(type),
                      if (pred != null) _makePredEditor(pred),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _makeLabelEditor(XmlProp label) {
    return makePropEditor<TransparentPropTextField>(
      label.value,
      PropTFOptions(
        autocompleteOptions:
            () => conditionLabels.map((l) => AutocompleteConfig(l)),
      ),
    );
  }

  Widget _makeXmlPropEditor(XmlProp prop) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: makeXmlPropEditor<TransparentPropTextField>(
        prop,
        widget.showDetails,
      ),
    );
  }

  Widget _makeConditionEnumEditor<T extends Enum>({
    required XmlProp prop,
    required String label,
    required List<T> values,
    required String Function(T) getDisplayName,
    String? Function(T)? getInfo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: _EnumSelector<T>(
        label: label,
        prop: prop,
        values: values,
        getDisplayName: getDisplayName,
        getInfo: getInfo,
      ),
    );
  }

  Widget _makeTypeEditor(XmlProp type) {
    return _makeConditionEnumEditor<ConditionType>(
      prop: type,
      label: "type",
      values: ConditionType.values,
      getDisplayName: (e) => e.displayName,
      getInfo: (e) => e.description,
    );
  }

  Widget _makePredEditor(XmlProp pred) {
    return _makeConditionEnumEditor<ConditionPredicate>(
      prop: pred,
      label: "pred",
      values: ConditionPredicate.values,
      getDisplayName: (e) => e.displayName,
    );
  }
}

class _EnumSelector<T extends Enum> extends StatelessWidget {
  final String label;
  final XmlProp prop;
  final List<T> values;
  final String Function(T) getDisplayName;
  final String? Function(T)? getInfo;

  const _EnumSelector({
    super.key,
    required this.label,
    required this.prop,
    required this.values,
    required this.getDisplayName,
    this.getInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text("$label "),
        TextButton(
          onPressed: () async {
            var result = await showSelectionPopup<int>(
              context,
              values
                  .asMap()
                  .entries
                  .map(
                    (e) => SelectionPopupConfig(
                      name: getDisplayName(e.value),
                      getValue: () => e.key,
                    ),
                  )
                  .toList(),
            );
            if (result != null) {
              (prop.value as NumberProp).value = result;
            }
          },
          child: Row(
            children: [
              Text(_getCurrentIntDisplayName()),
              const Icon(Icons.arrow_drop_down, size: 16),
            ],
          ),
        ),
        if (getInfo != null) _makeInfoTooltip(context),
      ],
    );
  }

  String _getCurrentIntDisplayName() {
    final val = int.tryParse(prop.value.toString());
    if (val != null && val >= 0 && val < values.length) {
      return getDisplayName(values[val]);
    }
    return "Invalid";
  }

  Widget _makeInfoTooltip(BuildContext context) {
    final val = int.tryParse(prop.value.toString());
    if (val == null || val < 0 || val >= values.length) {
      return const SizedBox.shrink();
    }
    final info = getInfo!(values[val]);
    if (info == null) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: info,
      child: const Padding(
        padding: EdgeInsets.only(left: 4.0),
        child: Icon(Icons.info_outline_sharp, size: 14),
      ),
    );
  }
}
