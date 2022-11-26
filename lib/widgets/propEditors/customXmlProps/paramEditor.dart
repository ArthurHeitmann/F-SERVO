
import 'package:flutter/material.dart';

import '../../../background/IdLookup.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/openFilesManager.dart';
import '../../../utils/paramPresets.dart';
import '../../../utils/utils.dart';
import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../simpleProps/XmlPropEditor.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';
import '../simpleProps/textFieldAutocomplete.dart';

class ParamsEditor extends StatelessWidget {
  final bool showDetails;
  final XmlProp prop;

  const ParamsEditor({super.key, required this.prop, required this.showDetails});

  StringProp get nameProp => prop[0].value as StringProp;
  HexProp get codeProp => prop[1].value as HexProp;
  Prop get bodyProp => prop[2].value;

  @override
  Widget build(BuildContext context) {
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
              makePropEditor(nameProp, nameAutocompleteOptions),
              if (showDetails || codeProp.strVal == "type")
                makePropEditor(codeProp, codeAutocompleteOptions),
              if (prop[2].isEmpty)
                makePropEditor(bodyProp)
              else
                XmlPropEditor(prop: prop[2], showDetails: false, showTagName: false,),
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
