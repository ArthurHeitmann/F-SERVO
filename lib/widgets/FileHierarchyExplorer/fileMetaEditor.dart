
import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../utils.dart';
import '../misc/SmoothSingleChildScrollView.dart';
import '../misc/smallButton.dart';
import '../propEditors/simpleProps/XmlPropEditorFactory.dart';
import '../propEditors/simpleProps/propEditorFactory.dart';
import '../propEditors/xmlActions/xmlArrayEditor.dart';

enum _EditorType {
  none,
  hapGroup,
  xmlScript,
}

const _editorTypeNames = {
  _EditorType.none: "Properties",
  _EditorType.hapGroup: "Group Editor",
  _EditorType.xmlScript: "Script Properties",
};

class FileMetaEditor extends ChangeNotifierWidget {
  FileMetaEditor({super.key}) : super(notifier: openHierarchyManager);

  @override
  State<FileMetaEditor> createState() => _FileMetaEditorState();
}

class _FileMetaEditorState extends ChangeNotifierState<FileMetaEditor> {
  _EditorType get editorType {
    var file = openHierarchyManager.selectedEntry;
    if (file == null)
      return _EditorType.none;
    if (file is HapGroupHierarchyEntry)
      return _EditorType.hapGroup;
    if (file is XmlScriptHierarchyEntry)
      return _EditorType.xmlScript;
    return _EditorType.none;
  }

  Widget Function(HierarchyEntry) getEditor() {
    switch (editorType) {
      case _EditorType.hapGroup:
        return makeGroupEditor;
      case _EditorType.xmlScript:
        return makeXmlScriptEditor;
      default:
        return makeFallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    var entry = openHierarchyManager.selectedEntry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        makeTopRow(),
        const Divider(height: 1),
        Expanded(
          key: Key(openHierarchyManager.selectedEntry?.name.value ?? "noGroup"),
          child: SmoothSingleChildScrollView(
            stepSize: 60,
            controller: ScrollController(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: entry != null ? getEditor()(entry) : makeFallback(null),
            ),
          ),
        ),
      ],
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

  Widget makeGroupEditor(HierarchyEntry groupEntry) {
    if (groupEntry is! HapGroupHierarchyEntry)
      throw Exception(":/");
    return ChangeNotifierBuilder(
      notifier: groupEntry.prop,
      builder: (context) {
        var tokens = groupEntry.prop.get("tokens");
        return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(flex: 1, child: Text("Name:")),
              Expanded(flex: 3, child: makePropEditor(groupEntry.name)),
            ],
          ),
          const SizedBox(height: 5),
          const Text("Tokens:"),
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
                groupEntry.prop.add(XmlProp.fromXml(makeXmlElement(
                  name: "tokens",
                  children: [
                    makeXmlElement(name: "size", text: "1"),
                    makeXmlElement(name: "value", children: [
                      makeXmlElement(name: "code", text: "0x0"),
                      makeXmlElement(name: "id", text: "0x0"),
                    ])
                  ]
                ), parentTags: groupEntry.prop.nextParents()));
              },
              constraints: const BoxConstraints(maxWidth: 60),
              child: const Icon(Icons.add, size: 20,),
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
      notifier: fileData,
      builder: (context) {
        if (fileData.loadingState == LoadingState.notLoaded || fileData is! XmlFileData) {
          fileData.load();
          return Container();
        }

        var xml = fileData.root!;
        var id = xml.get("id");
        var name = xml.get("name");
        var pakType = fileData.pakType;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name != null)
              makeXmlPropEditor(name, true),
            if (id != null)
              makeXmlPropEditor(id, true),
            if (pakType != null)
              Row(
                children: [
                  Text("pak file type", style: getTheme(context).propInputTextStyle,),
                  const SizedBox(width: 10),
                  Flexible(
                    child: makePropEditor(pakType),
                  ),
                ],
              )
          ],
        );
      },
    );
  }

  Widget makeFallback(_) {
    return Container();
  }
}
