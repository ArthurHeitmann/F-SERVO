
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/ChangeNotifierWidget.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';

class ScriptIdEditor<T extends PropTextField> extends ChangeNotifierWidget {
  final XmlProp prop;

  ScriptIdEditor({ super.key, required this.prop })
    : super(notifier: prop[0]);

  @override
  State<ScriptIdEditor> createState() => _ScriptIdEditorState<T>();
}

class _ScriptIdEditorState<T extends PropTextField> extends ChangeNotifierState<ScriptIdEditor> {
  String? datPath;
  late final String? datName;

  HexProp get prop => widget.prop[0].value as HexProp;

  @override
  void initState() {
    super.initState();
    var propFile = areasManager.fromId(widget.prop.file);
    if (propFile == null)
      return;
    datPath = dirname(propFile.path);
    int i = 3;
    while (!datPath!.endsWith(".dat") && i > 0) {
      datPath = dirname(datPath!);
      i--;
    }
    if (i == 0)
      return;
    datName = basenameWithoutExtension(datPath!);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text("Script id"),
          const SizedBox(width: 10),
          makePropEditor<T>(prop),
          if (datName != null) ...[
            const SizedBox(width: 16),
            makeGoToScriptButton(context),
          ],
        ],
      ),
    );
  }

  Widget makeGoToScriptButton(BuildContext context) {
    var baseName = datName!;
    if (baseName == "corehap")
      baseName = "global";
    var scriptFileName = "${baseName}_${(prop.value).toRadixString(16)}_scp.bin.rb";
    return Flexible(
      child: OutlinedButton.icon(
        icon: Icon(Icons.description, size: 15, color: getTheme(context).filetypeDocColor),
        label: Text(scriptFileName, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: getTheme(context).textColor,
        ),
        onPressed: () {
          var scriptPath = join(datPath!, scriptFileName);
          areasManager.openFile(scriptPath);
        },
      ),
    );
  }
}
