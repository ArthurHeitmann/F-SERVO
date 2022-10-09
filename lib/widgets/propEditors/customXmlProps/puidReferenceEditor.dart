

import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../background/IdLookup.dart';
import '../../../background/IdsIndexer.dart';
import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFilesManager.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/UnderlinePropTextField.dart';
import '../simpleProps/propEditorFactory.dart';
import '../xmlActions/XmlActionEditor.dart';

class PuidReferenceEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlProp prop;

  PuidReferenceEditor({super.key, required this.prop, required this.showDetails})
    : super(notifiers: [prop.get("code")!, prop.get("id") ?? prop.get("value")!]);

  @override
  State<PuidReferenceEditor> createState() => _PuidReferenceEditorState();
}

class _PuidReferenceEditorState extends ChangeNotifierState<PuidReferenceEditor> {
  bool showLookup = true;

  @override
  Widget build(BuildContext context) {
    var code = widget.prop.get("code")!;
    var codeProp = code.value as HexProp;
    var id = widget.prop.get("id") ?? widget.prop.get("value")!;
    var idProp = id.value as HexProp;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: interactionsWrapper(context,
        child: Container(
          decoration: BoxDecoration(
            color: getTheme(context).formElementBgColor,
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 25,),
              SizedBox(width: 4,),
              showLookup ? FutureBuilder(
                future: idLookup.lookupId(idProp.value),
                builder: (context, AsyncSnapshot<List<IndexedIdData>> snapshot) {
                  var lookup = snapshot.data;
                  if (lookup == null || lookup.isEmpty)
                    lookup = [IndexedIdData(idProp.value, codeProp.isHashed ? codeProp.strVal! : codeProp.toString(), "", "", "")];
                  var puidRef = lookup.first;
                  return Expanded(
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 25),
                          child: Text(
                            puidRef.type,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: 4,),
                        if (puidRef is IndexedActionIdData)
                          Text(puidRef.actionName, overflow: TextOverflow.ellipsis,),
                        if (puidRef is IndexedEntityIdData)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(puidRef.objId),
                              if (puidRef.name != null)
                                Flexible(child: Text(" (${puidRef.name})", overflow: TextOverflow.ellipsis,)),
                              if (puidRef.level != null)
                                Text(" (lvl ${puidRef.level})"),
                            ],
                          ),
                        if (puidRef is! IndexedActionIdData && puidRef is! IndexedEntityIdData)
                          Text(idProp.isHashed ? idProp.strVal! : idProp.toString()),
                      ],
                    ),
                  );
                }
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  makePropEditor<UnderlinePropTextField>(code.value),
                  makePropEditor<UnderlinePropTextField>(id.value),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget interactionsWrapper(BuildContext context, { required Widget child }) {
    return NestedContextMenu(
      buttons: [
        ContextMenuButtonConfig("Paste PUID ref", icon: Icon(Icons.content_paste, size: 14), onPressed: pasteRef),
        ContextMenuButtonConfig("Go to Reference", icon: Icon(Icons.east, size: 14), shortcutLabel: "(ctrl + click)", onPressed: goToReference),
        ContextMenuButtonConfig("Toggle Editing", icon: Icon(Icons.edit, size: 14), shortcutLabel: "(double click)", onPressed: () => setState(() => showLookup = !showLookup)),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onClick,
          child: child,
        ),
      )
    );
  }

  int lastClickAt = 0;

  bool isDoubleClick({ int intervalMs = 500 }) {
    int time = DateTime.now().millisecondsSinceEpoch;
    return time - lastClickAt < intervalMs;
  }

  void onClick() {
    if (isDoubleClick())
      setState(() => showLookup = !showLookup);
    else if (isCtrlPressed() || isShiftPressed())
      goToReference();

    lastClickAt = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> goToReference() async {
    var id = widget.prop.get("id") ?? widget.prop.get("value")!;
    var idProp = id.value as HexProp;
    var indexedData = await idLookup.lookupId(idProp.value);
    if (indexedData.isEmpty) {
      showToast("Couldn't find Reference");
      return;
    }

    var result = indexedData.first;
    var openFile = areasManager.openFile(result.xmlPath);
    if (result is IndexedActionIdData || result is IndexedEntityIdData) {
      await openFile.load();
      areasManager.ensureFileIsVisible(openFile);
      int actionId;
      if (result is IndexedActionIdData)
        actionId = result.id;
      else if (result is IndexedEntityIdData)
        actionId = result.actionId;
      else
        throw Exception("Big bad");
      
      await waitForNextFrame();

      var actionContext = getActionKey(actionId)?.currentContext;
      if (actionContext == null) {
        showToast("Couldn't find Action");
        return;
      }

      scrollIntoView(actionContext, duration: Duration(milliseconds: 400), viewOffset: 45);
    }
  }

  Future<void> pasteRef() async {
    var puidRef = await getClipboardPuidRefData();
    var code = widget.prop.get("code")!.value as HexProp;
    var id = (widget.prop.get("id") ?? widget.prop.get("value")!).value as HexProp;
    code.value = puidRef.codeHash;
    id.value = puidRef.id;
  }
}
