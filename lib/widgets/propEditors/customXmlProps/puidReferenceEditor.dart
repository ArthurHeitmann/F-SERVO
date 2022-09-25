

import 'package:flutter/material.dart';

import '../../../background/IdLookup.dart';
import '../../../background/IdsIndexer.dart';
import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../simpleProps/propEditorFactory.dart';

class PuidReferenceEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlProp prop;

  PuidReferenceEditor({super.key, required this.prop, required this.showDetails})
    : super(notifiers: [prop.get("code")!, prop.get("id") ?? prop.get("value")!]);

  @override
  State<PuidReferenceEditor> createState() => _PuidReferenceEditorState();
}

class _PuidReferenceEditorState extends ChangeNotifierState<PuidReferenceEditor> {
  @override
  Widget build(BuildContext context) {
    var code = widget.prop.get("code")!;
    var codeProp = code.value as HexProp;
    var id = widget.prop.get("id") ?? widget.prop.get("value")!;
    var idProp = id.value as HexProp;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).formElementBgColor,
          borderRadius: BorderRadius.circular(5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.link, size: 25,),
            SizedBox(width: 4,),
            !widget.showDetails ? FutureBuilder(
              future: idLookup.lookupId(idProp.value),
              builder: (context, AsyncSnapshot<IndexedIdData?> snapshot) {
                var lookup = snapshot.data;
                lookup ??= IndexedIdData(idProp.value, codeProp.isHashed ? codeProp.strVal! : codeProp.toString(), "", "", "");
                return Expanded(
                  child: Column(
                    children: [
                      Text(lookup.type, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),),
                      SizedBox(height: 4,),
                      if (lookup is IndexedActionIdData)
                        Text(lookup.actionName, overflow: TextOverflow.ellipsis,),
                      if (lookup is IndexedEntityIdData)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(lookup.objId),
                            if (lookup.name != null)
                              Flexible(child: Text(" (${lookup.name})", overflow: TextOverflow.ellipsis,)),
                            if (lookup.level != null)
                              Text(" (lvl ${lookup.level})"),
                          ],
                        ),
                      if (lookup is! IndexedActionIdData && lookup is! IndexedEntityIdData)
                        Text(idProp.isHashed ? idProp.strVal! : idProp.toString()),
                    ],
                  ),
                );
              }
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                makePropEditor(code.value),
                makePropEditor(id.value),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
