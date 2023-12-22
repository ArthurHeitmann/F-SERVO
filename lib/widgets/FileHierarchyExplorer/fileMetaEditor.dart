
import 'package:flutter/material.dart';

import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../../stateManagement/hierarchy/types/BnkHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/PakHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/XmlScriptHierarchyEntry.dart';
import '../../stateManagement/openFiles/openFileTypes.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../stateManagement/openFiles/types/xml/XmlFileData.dart';
import '../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../filesView/types/xml/XmlPropEditorFactory.dart';
import '../filesView/types/xml/customXmlProps/optionalPropEditor.dart';
import '../filesView/types/xml/xmlActions/xmlArrayEditor.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../misc/onHoverBuilder.dart';
import '../misc/smallButton.dart';
import '../propEditors/propEditorFactory.dart';

enum _EditorType {
  none,
  hapGroup,
  xmlScript,
  hircObject,
}

const _editorTypeNames = {
  _EditorType.none: "Properties",
  _EditorType.hapGroup: "Group Editor",
  _EditorType.xmlScript: "Script Properties",
  _EditorType.hircObject: "Object Properties",
};

class FileMetaEditor extends ChangeNotifierWidget {
  FileMetaEditor({super.key}) : super(notifier: openHierarchyManager.selectedEntry);

  @override
  State<FileMetaEditor> createState() => _FileMetaEditorState();
}

class _FileMetaEditorState extends ChangeNotifierState<FileMetaEditor> {
  _EditorType get editorType {
    var file = openHierarchyManager.selectedEntry.value;
    if (file == null)
      return _EditorType.none;
    if (file is HapGroupHierarchyEntry)
      return _EditorType.hapGroup;
    if (file is XmlScriptHierarchyEntry)
      return _EditorType.xmlScript;
    if (file is BnkHircHierarchyEntry)
      return _EditorType.hircObject;
    return _EditorType.none;
  }

  Widget Function(HierarchyEntry) getEditor() {
    switch (editorType) {
      case _EditorType.hapGroup:
        return makeGroupEditor;
      case _EditorType.xmlScript:
        return makeXmlScriptEditor;
      case _EditorType.hircObject:
        return makeBnkHircObjectEditor;
      default:
        return makeFallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    var entry = openHierarchyManager.selectedEntry.value;
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          makeTopRow(),
          const Divider(height: 1),
          Expanded(
            key: Key(openHierarchyManager.selectedEntry.value?.uuid ?? "noGroup"),
            child: SmoothSingleChildScrollView(
              stepSize: 60,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: entry != null ? getEditor()(entry) : makeFallback(null),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget makeTopRow() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text(
              _editorTypeNames[editorType]!.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> makeActionsBar(HierarchyEntry entry) {
    var actions = entry.getActions();
    if (actions.isEmpty)
      return [];
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((e) => Flexible(
          child: TextButton.icon(
            onPressed: e.action,
            icon: Icon(e.icon, size: 20),
            label: Text(e.name, overflow: TextOverflow.ellipsis),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                  width: 2,
                ),
              ),
            )
          ),
        )).toList(),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget makeGroupEditor(HierarchyEntry groupEntry) {
    if (groupEntry is! HapGroupHierarchyEntry)
      throw Exception(":/");
    return ChangeNotifierBuilder(
      notifier: groupEntry.prop,
      builder: (context) {
        var tokens = groupEntry.prop.get("tokens");
        var attribute = groupEntry.prop.get("attribute");
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...makeActionsBar(groupEntry),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(flex: 1, child: Text("Name:")),
                Expanded(flex: 3, child: makePropEditor(groupEntry.name)),
              ],
            ),
            const SizedBox(height: 5),
            const Text("Conditions:"),
            const SizedBox(height: 5),
            if (tokens != null)
              XmlArrayEditor(
                tokens,
                XmlPresets.codeAndId.withCxtV(groupEntry.prop),
                tokens[0], "value", true
              )
            else
              SmallButton(
                onPressed: () {
                  groupEntry.prop.add(XmlProp.fromXml(
                    makeXmlElement(
                      name: "tokens",
                      children: [
                        makeXmlElement(name: "size", text: "1"),
                        makeXmlElement(name: "value", children: [
                          makeXmlElement(name: "code", text: "0x0"),
                          makeXmlElement(name: "id", text: "0x0"),
                        ])
                      ]
                    ),
                    parentTags: groupEntry.prop.nextParents(),
                    file: groupEntry.prop.file
                  ));
                },
                constraints: const BoxConstraints(maxWidth: 60),
                child: const Icon(Icons.add, size: 20,),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Text("Attribute:"),
                  const SizedBox(width: 10),
                  Flexible(
                    child: OptionalPropEditor(
                      parent: groupEntry.prop,
                      prop: attribute,
                      onAdd: () {
                        groupEntry.prop.add(XmlProp.fromXml(
                          makeXmlElement(name: "attribute", text: "0x2"),
                          parentTags: groupEntry.prop.nextParents(),
                          file: groupEntry.prop.file
                        ));
                      },
                    ),
                  ),
                ],
              ),
          ]
        );
      },
    );
  }

  Widget makeXmlScriptEditor(HierarchyEntry scriptEntry) {
    if (scriptEntry is! XmlScriptHierarchyEntry)
      throw Exception(":/");
    
    var fileData = areasManager.openFileAsHidden(scriptEntry.path);

    return ChangeNotifierBuilder(
      notifier: fileData.loadingState,
      builder: (context) {
        if (fileData.loadingState.value == LoadingState.notLoaded || fileData is! XmlFileData) {
          fileData.load();
          return Container();
        }

        var xml = fileData.root;
        var id = xml?.get("id");
        var name = xml?.get("name");

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...makeActionsBar(scriptEntry),
            if (name != null)
              makeXmlPropEditor(name, true),
            if (id != null)
              makeXmlPropEditor(id, true),
          ],
        );
      },
    );
  }

  Widget makeBnkHircObjectEditor(HierarchyEntry hircObject) {
    if (hircObject is! BnkHircHierarchyEntry)
      throw Exception(":/");

    if (hircObject.properties == null)
      return const SizedBox();

    var props = hircObject.properties!;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...makeActionsBar(hircObject),
          for (var propRow in props) ...[
            if (!propRow.$1 && props.first != propRow)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Divider(height: 1, color: getTheme(context).dividerColor),
              ),
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  for (var prop in propRow.$2)
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(prop, style: getTheme(context).propInputTextStyle, overflow: TextOverflow.ellipsis,)
                          ),
                          if (propRow.$1)
                            OnHoverBuilder(
                              builder: (context, isHovering) => AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: isHovering ? 0.66 : 0.33,
                                child: IconButton(
                                  splashRadius: 18,
                                  icon: const Icon(Icons.copy, size: 16,),
                                  onPressed: () => copyToClipboard(prop),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                ]
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget makeFallback(HierarchyEntry? entry) {
    if (entry == null)
      return const SizedBox();
    var actions = makeActionsBar(entry);
    if (actions.isEmpty)
      return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: actions,
    );
  }
}
