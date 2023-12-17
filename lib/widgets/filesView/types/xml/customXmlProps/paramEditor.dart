
import 'package:flutter/material.dart';

import '../../../../../background/IdLookup.dart';
import '../../../../../stateManagement/Property.dart';
import '../../../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../../../utils/paramPresets.dart';
import '../../../../../utils/utils.dart';
import '../../../../misc/ChangeNotifierWidget.dart';
import '../../../../propEditors/propEditorFactory.dart';
import '../../../../propEditors/propTextField.dart';
import '../../../../propEditors/textFieldAutocomplete.dart';
import '../../../../propEditors/transparentPropTextField.dart';
import '../../../../theme/customTheme.dart';
import '../XmlPropEditor.dart';

class ParamsEditor extends StatefulWidget {
  final bool showDetails;
  final XmlProp prop;

  const ParamsEditor({super.key, required this.prop, required this.showDetails});

  @override
  State<ParamsEditor> createState() => _ParamsEditorState();
}

class _ParamsEditorState extends State<ParamsEditor> {
  String? prevValidName;

  StringProp get nameProp => widget.prop[0].value as StringProp;
  HexProp get codeProp => widget.prop[1].value as HexProp;
  Prop get bodyProp => widget.prop[2].value;

  @override
  void initState() {
    _onNameChange();
    nameProp.addListener(_onNameChange);
    super.initState();
  }

  @override
  void dispose() {
    nameProp.removeListener(_onNameChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var paramPreset = paramPresetsMap[nameProp.value];
    var presetBody = paramPreset?.body;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).formElementBgColor,
          border: Border.all(color: getTheme(context).propBorderColor!, width: 0.5),
          borderRadius: const BorderRadius.all(Radius.circular(10))
        ),
        padding: const EdgeInsets.only(right: 15),
        child: IntrinsicWidth(
          child: Wrap(
            direction: Axis.horizontal,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              makePropEditor<TransparentPropTextField>(nameProp, nameAutocompleteOptions),
              if (widget.showDetails || codeProp.strVal == "type")
                makePropEditor<TransparentPropTextField>(codeProp, codeAutocompleteOptions),
              if (widget.prop[2].isEmpty)
                makePropEditor<TransparentPropTextField>(bodyProp, PropTFOptions(
                  key: Key(nameProp.value),
                  autocompleteOptions: presetBody != null ? () => presetBody() : null,
                ))
              else
                XmlPropEditor(prop: widget.prop[2], showDetails: false, showTagName: false,),
              ChangeNotifierBuilder(
                notifier: nameProp,
                builder: (context) {
                  var code = nameProp;
                  if (code.value != "NameTag")
                    return const SizedBox();
                  return IconButton(
                    onPressed: _onNameTagPressed,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 10),
                    iconSize: 15,
                    splashRadius: 15,
                    icon: const Icon(Icons.edit),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  void _onNameChange() {
    var name = nameProp.value;
    var preset = paramPresetsMap[name];
    if (preset?.name != prevValidName)
      setState(() {});
    prevValidName = preset?.name;
  }

  void _onNameTagPressed() async {
    const int charNamesId = 0x75445849;
    var charNamesLookup = await idLookup.lookupId(charNamesId);
    if (charNamesLookup.isEmpty) {
      showToast("CharNames from corehap.dat not found! Check indexing settings.", const Duration(seconds: 6));
      return;
    }
    var charNamesResult = charNamesLookup[0];
    areasManager.openFile(charNamesResult.xmlPath);
  }

  PropTFOptions get nameAutocompleteOptions => PropTFOptions(
    autocompleteOptions: () => paramPresets
      .map((p) => AutocompleteConfig(p.name))
  );

  PropTFOptions get codeAutocompleteOptions => PropTFOptions(
    autocompleteOptions: () => paramCodes
      .map((c) => AutocompleteConfig(c, insertText: "0x${crc32(c).toRadixString(16)}"))
  );
}
