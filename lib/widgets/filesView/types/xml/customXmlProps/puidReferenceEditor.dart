

import 'package:flutter/material.dart';

import '../../../../../background/IdLookup.dart';
import '../../../../../background/IdsIndexer.dart';
import '../../../../../stateManagement/Property.dart';
import '../../../../../stateManagement/events/jumpToEvents.dart';
import '../../../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../../../utils/puidPresets.dart';
import '../../../../../utils/utils.dart';
import '../../../../misc/ChangeNotifierWidget.dart';
import '../../../../misc/contextMenuBuilder.dart';
import '../../../../misc/nestedContextMenu.dart';
import '../../../../misc/puidDraggable.dart';
import '../../../../propEditors/UnderlinePropTextField.dart';
import '../../../../propEditors/propEditorFactory.dart';
import '../../../../propEditors/propTextField.dart';
import '../../../../propEditors/textFieldAutocomplete.dart';
import '../../../../theme/customTheme.dart';
import '../XmlPropEditorFactory.dart';
import 'objIdEditor.dart';

class PuidReferenceEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlProp prop;
  final bool initiallyShowLookup;

  PuidReferenceEditor({super.key, required this.prop, required this.showDetails, this.initiallyShowLookup = true})
    : super(notifiers: [prop.get("code")!, prop.get("id") ?? prop.get("value")!]);

  @override
  State<PuidReferenceEditor> createState() => _PuidReferenceEditorState();
}

class _PuidReferenceEditorState extends ChangeNotifierState<PuidReferenceEditor> {
  late bool showLookup;
  Future<List<IndexedIdData>>? lookupFuture;
  StringProp objIdProp = StringProp("", fileId: null);
  bool isDragging = false;

  @override
  void initState() {
    showLookup = widget.initiallyShowLookup;
    var id = widget.prop.get("id") ?? widget.prop.get("value")!;
    var idProp = id.value;
    if (idProp is HexProp) {
      idLookup.lookupId(idProp.value);
      
      idProp.addListener(updateLookup);
      updateLookup();
    }
    else {
      showLookup = false;
    }

    super.initState();
  }

  @override
  void dispose() {
    var id = widget.prop.get("id") ?? widget.prop.get("value")!;
    var idProp = id.value;
    idProp.removeListener(updateLookup);
    objIdProp.dispose();

    super.dispose();
  }

  void updateLookup() async {
    var id = widget.prop.get("id") ?? widget.prop.get("value")!;
    var idProp = id.value;
    if (idProp is HexProp) {
      lookupFuture = idLookup.lookupId(idProp.value);
      await lookupFuture;
      if (mounted)
        setState(() {});
    }
    else {
      showLookup = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    var code = widget.prop.get("code")!;
    var codeProp = code.value as HexProp;
    var id = widget.prop.get("id") ?? widget.prop.get("value")!;
    var idProp = id.value is HexProp ? id.value as HexProp : null;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: interactionsWrapper(context,
        child: Material(
          color: getTheme(context).formElementBgColor,
          borderRadius: BorderRadius.circular(5),
          child: puidDraggableWrapper(
            codeProp, idProp,
            isDraggable: showLookup && idProp is HexProp,
            isDragTarget: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  puidDraggableWrapper(
                    codeProp, idProp,
                    isDraggable: !showLookup && idProp is HexProp,
                    isDragTarget: false,
                    child: const Icon(Icons.link, size: 25,)
                  ),
                  const SizedBox(width: 4,),
                  showLookup && idProp is HexProp
                    ? makeLookup(codeProp, idProp)
                    : makeEditor(code, id),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget interactionsWrapper(BuildContext context, { required Widget child }) {
    return NestedContextMenu(
      buttons: [
        ContextMenuConfig(label: "Copy PUID ref", icon: const Icon(Icons.content_copy, size: 14), action: copyRef),
        ContextMenuConfig(label: "Paste PUID ref", icon: const Icon(Icons.content_paste, size: 14), action: pasteRef),
        ContextMenuConfig(label: "Go to Reference", icon: const Icon(Icons.east, size: 14), shortcutLabel: "(ctrl + click)", action: goToReference),
        ContextMenuConfig(label: "Toggle Editing", icon: const Icon(Icons.edit, size: 14), shortcutLabel: "(double click)", action: () => setState(() => showLookup = !showLookup)),
        null,
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

  Widget makeLookup(HexProp codeProp, HexProp idProp) {
    return lookupBuilder(
      codeProp, idProp,
      builder: (context, IndexedIdData lookup) => Expanded(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 25),
              child: Text(
                lookup.type,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4,),
            if (lookup is IndexedActionIdData)
              Text(lookup.actionName, overflow: TextOverflow.ellipsis,)
            else if (lookup is IndexedHapIdData)
              Text(lookup.name, overflow: TextOverflow.ellipsis,)
            else if (lookup is IndexedEntityIdData)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ObjIdIcon(key: Key(lookup.objId), objId: objIdProp, size: 28,),
                  Text(lookup.objId),
                  if (lookup.name != null)
                    Flexible(child: Text(" (${lookup.name})", overflow: TextOverflow.ellipsis,)),
                  if (lookup.level != null)
                    Text(" (lvl ${lookup.level})"),
                ],
              )
            else
              Text(idProp.isHashed ? idProp.strVal! : idProp.toString()),
          ],
        ),
      )
    );
  }

  Widget lookupBuilder(HexProp codeProp, HexProp idProp, 
    { required Widget Function(BuildContext, IndexedIdData) builder }
  ) {
    return FutureBuilder(
      future: lookupFuture,
      builder: (context, AsyncSnapshot<List<IndexedIdData>> snapshot) {
        var lookup = snapshot.data;
        if (lookup == null || lookup.isEmpty)
          lookup = [IndexedIdData(idProp.value, codeProp.isHashed ? codeProp.strVal! : codeProp.toString(), "", "", "")];
        var puidRef = lookup.first;
        if (puidRef is IndexedEntityIdData)
          objIdProp.value = puidRef.objId;
        return builder(context, puidRef);
      },
    );
  }

  Widget puidDraggableWrapper(HexProp code, HexProp? id, {
    required Widget child,
    required bool isDraggable,
    required bool isDragTarget,
  }) {
    if (id != null) {
      if (isDraggable)
        child = PuidDraggable(
          code: code.strVal ?? "",
          id: id.value,
          onDragStarted: () => isDragging = false,
          onDragEnd: () => isDragging = false,
          child: child,
        );
    }
    if (!isDragTarget)
      return child;
    return DragTarget<PuidRefData>(
      onAccept: (data) {
        if (isDragging)
          return;
        code.setValueAndStr(crc32(data.code), data.code);
        if (id != null)
          id.value = data.id;
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: candidateData.isNotEmpty
                ? getTheme(context).textColor!.withOpacity(0.25)
                : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: child,
        );
      }
    );
  }

  Widget makeEditor(XmlProp code, XmlProp id) {
    var codeStr = (code.value as HexProp).strVal ?? "";
    var preset = puidPresetsMap[codeStr];
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          makePropEditor<UnderlinePropTextField>(code.value, PropTFOptions(
            autocompleteOptions: () => puidPresets.map((p) => AutocompleteConfig(p.code)),
          )),
          if (id.value is HexProp)
            makePropEditor<UnderlinePropTextField>(id.value, PropTFOptions(
              key: Key(codeStr),
              autocompleteOptions: preset?.getIds != null 
                ? () async => (await preset!.getIds!.call()).map((id) => AutocompleteConfig(id))
                : null,
            ))
          else
            makeXmlPropEditor<UnderlinePropTextField>(id, widget.showDetails),
        ],
      ),
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
    var idProp = id.value;
    if (idProp is! HexProp) {
      showToast("No reference to go to");
      return;
    }
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

      jumpToStream.add(JumpToIdEvent(
        openFile,
        result.id,
        actionId,
      ));
    }
    else {
      jumpToStream.add(JumpToIdEvent(
        openFile,
        result.id,
      ));
    }
  }

  Future<void> copyRef() {
    var code = widget.prop.get("code")!.value as HexProp;
    var id = (widget.prop.get("id") ?? widget.prop.get("value")!).value;
    if (id is! HexProp) {
      showToast("No reference to copy");
      return Future.value();
    }
    return copyPuidRef(
      code.strVal!,
      id.value
    );
  }

  Future<void> pasteRef() async {
    var puidRef = await getClipboardPuidRefData();
    if (puidRef == null) {
      showToast("No PUID ref in clipboard");
      return;
    }
    var code = widget.prop.get("code")!.value as HexProp;
    var id = (widget.prop.get("id") ?? widget.prop.get("value")!).value;
    if (id is! HexProp) {
      showToast("No reference to paste");
      return;
    }
    code.value = puidRef.codeHash;
    id.value = puidRef.id;
  }
}
