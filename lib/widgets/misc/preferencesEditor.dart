
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../widgets/theme/customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/preferencesData.dart';
import '../propEditors/simpleProps/boolPropSwitch.dart';
import '../propEditors/simpleProps/primaryPropTextField.dart';
import '../propEditors/simpleProps/propTextField.dart';
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
          const Text("Preferences", style: TextStyle(fontWeight: FontWeight.w300, fontSize: 25),),
          const SizedBox(height: 20,),
          ...makeDataExportEditor(),
          ...makeIndexingEditor(),
          ...makeThemeEditor(),
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
      const Text("Data export path", style: sectionHeaderStyle,),
      const SizedBox(height: 10,),
      RowSeparated(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: PrimaryPropTextField(
              prop: exportPathProp,
              onValid: (value) => exportPathProp.value = value,
              validatorOnChange: (value) => value.isEmpty || Directory(value).existsSync() ? null : "Directory does not exist",
              options: const PropTFOptions(constraints: BoxConstraints(minHeight: 30)),
            ),
          ),
          SmallButton(
            constraints: BoxConstraints.tight(const Size(30, 30)),
            onPressed: () async {
              var dir = await FilePicker.platform.getDirectoryPath(
                dialogTitle: "Select Indexing Directory",
                initialDirectory: exportPathProp.value.isNotEmpty ? exportPathProp.value : null,
              );
              if (dir != null) {
                widget.prefs.dataExportPath!.value = dir;
              }
            },
            child: const Icon(Icons.folder, size: 17,),
          ),
        ],
      ),
      const SizedBox(height: 10,),
      Row(
        children: [
          const Text("ON EXPORT:", overflow: TextOverflow.ellipsis,),
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
      const SizedBox(height: 40,),
    ];
  }

  List<Widget> makeIndexingEditor() {
    return [
      const Text("Indexing paths:", style: sectionHeaderStyle,),
      const SizedBox(height: 10,),
      ...(widget.prefs.indexingPaths
        ?.map((path) => RowSeparated(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: PrimaryPropTextField(
                prop: path,
                onValid: (value) => widget.prefs.indexingPaths!.setPath(path, value),
                validatorOnChange: (value) => Directory(value).existsSync() ? null : "Directory does not exist",
                options: const PropTFOptions(constraints: BoxConstraints(minHeight: 30)),
              ),
            ),
            SmallButton(
              constraints: BoxConstraints.tight(const Size(30, 30)),
              onPressed: () async {
                var dir = await FilePicker.platform.getDirectoryPath(
                  dialogTitle: "Select Indexing Directory",
                  initialDirectory: path.value,
                );
                if (dir != null) {
                  widget.prefs.indexingPaths!.setPath(path, dir);
                }
              },
              child: const Icon(Icons.folder, size: 17,),
            ),
            SmallButton(
              constraints: BoxConstraints.tight(const Size(30, 30)),
              onPressed: () => widget.prefs.indexingPaths!.removePath(path),
              child: const Icon(Icons.remove, size: 17,),
            ),
          ],
        )) ?? []),
      const SizedBox(height: 15,),
      SmallButton(
        constraints: BoxConstraints.tight(const Size(30, 30)),
        onPressed: () async {
          var dir = await FilePicker.platform.getDirectoryPath(
            dialogTitle: "Select Indexing Directory",
          );
          if (dir != null) {
            widget.prefs.indexingPaths!.addPath(dir);
          }
        },
        child: const Icon(Icons.add, size: 17,),
      )
    ];
  }

  Widget makeThemeSelectable(BuildContext context, ThemeType type, Color primary, Color secondary) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(
          color: secondary.withOpacity(widget.prefs.themeType!.value == type ? 0.5 : 0),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: primary,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.prefs.themeType!.value = type,
          splashColor: secondary.withOpacity(0.5),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: secondary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> makeThemeEditor() {
    return [
      const Text("Theme:", style: sectionHeaderStyle,),
      const SizedBox(height: 10,),
      ChangeNotifierBuilder(
        notifier: widget.prefs.themeType!,
        builder: (context) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            makeThemeSelectable(context, ThemeType.dark, const Color.fromARGB(255, 50, 50, 50), Colors.white),
            makeThemeSelectable(context, ThemeType.nier, const Color.fromARGB(255, 218, 212, 187), const Color.fromARGB(255, 78, 75, 61)),
          ],
        ),
      ),
    ];
  }
}
