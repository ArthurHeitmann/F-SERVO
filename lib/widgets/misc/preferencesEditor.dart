

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/preferencesData.dart';
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
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Preferences", style: TextStyle(fontWeight: FontWeight.w300, fontSize: 25),),
          SizedBox(height: 20,),
          Text("Indexing paths:", style: TextStyle(fontWeight: FontWeight.w300, fontSize: 18),),
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
          ),
        ],
      ),
    );
  }
}
