
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/preferencesData.dart';
import '../propEditors/simpleProps/boolPropSwitch.dart';
import '../propEditors/simpleProps/primaryPropTextField.dart';
import 'RowSeparated.dart';
import 'smallButton.dart';

class PreferencesEditor extends ChangeNotifierWidget {
  final PreferencesData prefs;

  PreferencesEditor({super.key, required this.prefs})
    : super(notifiers: [prefs, prefs.indexingPaths!]);

  @override
  State<PreferencesEditor> createState() => _PreferencesEditorState();
}

class _PreferencesEditorState extends ChangeNotifierState<PreferencesEditor> {
  static const sectionHeaderStyle = TextStyle(fontWeight: FontWeight.w300, fontSize: 18);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Preferences", style: TextStyle(fontWeight: FontWeight.w300, fontSize: 25),),
          SizedBox(height: 20,),
          ...makeDataExportEditor(),
          ...makeIndexingEditor(),
        ],
      ),
    );
  }

  List<Widget> makeDataExportEditor() {
    var exportPathProp = widget.prefs.dataExportPath;
    var exportOptions = [
      widget.prefs.exportDats,
      widget.prefs.exportPaks,
      widget.prefs.convertXmls,
    ];
    const exportOptionLabels = [
      "Export .dat files",
      "Export .pak files",
      "Convert .xml to .yax files",
    ];
    if (exportPathProp == null || exportOptions.any((e) => e == null))
      return [];

    return [
      Text("Data export path", style: sectionHeaderStyle,),
      SizedBox(height: 10,),
      RowSeparated(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: PrimaryPropTextField(
              prop: exportPathProp,
              onValid: (value) => exportPathProp.value = value,
              validatorOnChange: (value) => value.isEmpty || Directory(value).existsSync() ? null : "Directory does not exist",
              constraints: BoxConstraints(minHeight: 30),
            ),
          ),
          SmallButton(
            constraints: BoxConstraints.tight(Size(30, 30)),
            onPressed: () async {
              var dir = await FilePicker.platform.getDirectoryPath(
                dialogTitle: "Select Indexing Directory",
                initialDirectory: exportPathProp.value.isNotEmpty ? exportPathProp.value : null,
              );
              if (dir != null) {
                widget.prefs.dataExportPath!.value = dir;
              }
            },
            child: Icon(Icons.folder, size: 17,),
          ),
        ],
      ),
      SizedBox(height: 10,),
      Row(
        children: [
          Text("ON EXPORT:", overflow: TextOverflow.ellipsis,),
          Expanded(
            child: RowSeparated(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              separator: (_) => SizedBox(
                height: 20,
                child: VerticalDivider(color: getTheme(context).textColor!.withOpacity(0.25),),
              ),
              children: [
                for (var i = 0; i < exportOptions.length; i++)
                  Expanded(
                    child: Row(
                      children: [
                        BoolPropSwitch(prop: exportOptions[i]!),
                        Flexible(
                          child: Text(exportOptionLabels[i], overflow: TextOverflow.ellipsis,)
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
      SizedBox(height: 40,),
    ];
  }

  List<Widget> makeIndexingEditor() {
    return [
      Text("Indexing paths:", style: sectionHeaderStyle,),
      SizedBox(height: 10,),
      ...(widget.prefs.indexingPaths
        ?.map((path) => RowSeparated(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: PrimaryPropTextField(
                prop: path,
                onValid: (value) => widget.prefs.indexingPaths!.setPath(path, value),
                validatorOnChange: (value) => Directory(value).existsSync() ? null : "Directory does not exist",
                constraints: BoxConstraints(minHeight: 30),
              ),
            ),
            SmallButton(
              constraints: BoxConstraints.tight(Size(30, 30)),
              onPressed: () async {
                var dir = await FilePicker.platform.getDirectoryPath(
                  dialogTitle: "Select Indexing Directory",
                  initialDirectory: path.value,
                );
                if (dir != null) {
                  widget.prefs.indexingPaths!.setPath(path, dir);
                }
              },
              child: Icon(Icons.folder, size: 17,),
            ),
            SmallButton(
              constraints: BoxConstraints.tight(Size(30, 30)),
              onPressed: () => widget.prefs.indexingPaths!.removePath(path),
              child: Icon(Icons.remove, size: 17,),
            ),
          ],
        )) ?? []),
      SizedBox(height: 15,),
      SmallButton(
        constraints: BoxConstraints.tight(Size(30, 30)),
        onPressed: () async {
          var dir = await FilePicker.platform.getDirectoryPath(
            dialogTitle: "Select Indexing Directory",
          );
          if (dir != null) {
            widget.prefs.indexingPaths!.addPath(dir);
          }
        },
        child: Icon(Icons.add, size: 17,),
      )
    ];
  }
}
