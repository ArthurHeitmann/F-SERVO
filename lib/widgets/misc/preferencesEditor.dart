
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../stateManagement/preferencesData.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../propEditors/boolPropSwitch.dart';
import '../propEditors/primaryPropTextField.dart';
import '../propEditors/propTextField.dart';
import 'ChangeNotifierWidget.dart';
import 'RowSeparated.dart';
import 'SmoothScrollBuilder.dart';
import 'smallButton.dart';

class PreferencesEditor extends ChangeNotifierWidget {
  final PreferencesData prefs;

  PreferencesEditor({super.key, required this.prefs})
    : super(notifiers: [prefs.loadingState, prefs.indexingPaths!]);

  @override
  State<PreferencesEditor> createState() => _PreferencesEditorState();
}

class _PreferencesEditorState extends ChangeNotifierState<PreferencesEditor> {
  static const sectionHeaderStyle = TextStyle(fontWeight: FontWeight.w300, fontSize: 18);

  @override
  Widget build(BuildContext context) {
    return SmoothSingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Preferences", style: TextStyle(fontWeight: FontWeight.w300, fontSize: 25),),
            const SizedBox(height: 20,),
            ...makeDataExportEditor(context),
            // ...makeIndexingEditor(),
            ...makeThemeEditor(),
            ...makeMusicEditor(),
          ],
        ),
      ),
    );
  }

  Widget makeFilePickerButton(String dialogTitle, String? initialDir, void Function(String) onPick) {
    return SmallButton(
      constraints: BoxConstraints.tight(const Size(30, 30)),
      onPressed: () async {
        var dir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: dialogTitle,
          initialDirectory: initialDir,
        );
        if (dir != null)
          onPick(dir);
      },
      child: const Icon(Icons.folder, size: 17,),
    );
  }

  List<Widget> makeDataExportEditor(BuildContext context) {
    var exportPathProp = widget.prefs.dataExportPath;
    var exportOptions = [
      widget.prefs.exportDats,
      // widget.prefs.exportPaks,
      // widget.prefs.convertXmls,
    ];
    const exportOptionLabels = [
      "Export changed .dat files",
      // "Export .pak files",
      // "Convert .xml to .yax files",
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
              options: const PropTFOptions(constraints: BoxConstraints(minHeight: 30), isFolderPath: true),
            ),
          ),
          makeFilePickerButton(
            "Select Indexing Directory",
            exportPathProp.value.isNotEmpty ? exportPathProp.value : null,
            (dir) => widget.prefs.dataExportPath!.value = dir,
          ),
        ],
      ),
      const SizedBox(height: 10,),
      Row(
        children: [
          const Text("ON SAVE:", overflow: TextOverflow.ellipsis,),
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
      const SizedBox(height: 10,),
      Row(
        children: [
          const Text("When extracting DAT, overwrite all files:", overflow: TextOverflow.ellipsis,),
          BoolPropSwitch(prop: widget.prefs.datReplaceOnExtract!),
        ],
      ),
      const SizedBox(height: 40,),
      const Text("Text editor:", style: sectionHeaderStyle,),
      const SizedBox(height: 10,),
      Row(
        children: [
          const Text("Use builtin VS Code editor:", overflow: TextOverflow.ellipsis,),
          BoolPropSwitch(prop: widget.prefs.useMonacoEditor!),
        ],
      ),
      Row(
        children: [
          const Text("Prefer opening text files in VS Code:", overflow: TextOverflow.ellipsis,),
          BoolPropSwitch(prop: widget.prefs.preferVsCode!),
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
          key: Key(path.uuid),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: PrimaryPropTextField(
                prop: path,
                onValid: (value) => widget.prefs.indexingPaths!.setPath(path, value),
                validatorOnChange: (value) => Directory(value).existsSync() ? null : "Directory does not exist",
                options: const PropTFOptions(constraints: BoxConstraints(minHeight: 30), isFolderPath: true),
              ),
            ),
            makeFilePickerButton(
              "Select Indexing Directory",
              path.value.isNotEmpty ? path.value : null,
              (dir) => widget.prefs.indexingPaths!.setPath(path, dir),
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
      const SizedBox(height: 20,),
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
      const SizedBox(height: 20,),
      Row(
        children: [
          const Text("Move file properties to right sidebar", overflow: TextOverflow.ellipsis,),
          BoolPropSwitch(prop: widget.prefs.moveFilePropertiesToRight!),
        ],
      ),
    ];
  }

  List<Widget> makeMusicEditor() {
    return [
      const SizedBox(height: 40,),
      const Text("Music preferences:", style: sectionHeaderStyle,),
      const SizedBox(height: 10,),
      // RowSeparated(
      //   crossAxisAlignment: CrossAxisAlignment.center,
      //   children: [
      //     const Text("WAI Extract Directory:", overflow: TextOverflow.ellipsis,),
      //     Expanded(
      //       child: PrimaryPropTextField(
      //         prop: widget.prefs.waiExtractDir!,
      //         onValid: (value) => widget.prefs.waiExtractDir!.value = value,
      //         validatorOnChange: (value) => value.isEmpty || Directory(value).existsSync() ? null : "Directory does not exist",
      //         options: const PropTFOptions(constraints: BoxConstraints(minHeight: 30)),
      //       ),
      //     ),
      //     makeFilePickerButton(
      //       "Select WAI Extract Directory",
      //       widget.prefs.waiExtractDir!.value.isNotEmpty ? widget.prefs.waiExtractDir!.value : null,
      //       (dir) => widget.prefs.waiExtractDir!.value = dir,
      //     ),
      //   ],
      // ),
      RowSeparated(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("WEM Extract Directory:", overflow: TextOverflow.ellipsis,),
          Expanded(
            child: PrimaryPropTextField(
              prop: widget.prefs.wemExtractDir!,
              onValid: (value) => widget.prefs.wemExtractDir!.value = value,
              validatorOnChange: (value) => value.isEmpty || Directory(value).existsSync() ? null : "Directory does not exist",
              options: const PropTFOptions(constraints: BoxConstraints(minHeight: 30), isFolderPath: true),
            ),
          ),
          makeFilePickerButton(
            "Select WEM Extract Directory",
            widget.prefs.wemExtractDir!.value.isNotEmpty ? widget.prefs.wemExtractDir!.value : null,
                (dir) => widget.prefs.wemExtractDir!.value = dir,
          ),
        ],
      ),
      const Row(
        children: [
          SizedBox(width: 20,),
          Text("Folder where sound stream cpk files are extracted to"),
        ],
      ),
      RowSeparated(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("Wwise CLI Path (2012):", overflow: TextOverflow.ellipsis,),
          Expanded(
            child: PrimaryPropTextField(
              prop: widget.prefs.wwise2012CliPath!,
              onValid: (value) => widget.prefs.wwise2012CliPath!.value = value.isNotEmpty ? findWwiseCliExe(value)! : "",
              validatorOnChange: (value) => value.isEmpty || findWwiseCliExe(value) != null ? null : "Directory does not exist",
              options: const PropTFOptions(constraints: BoxConstraints(minHeight: 30), isFolderPath: true, isFilePath: true),
            ),
          ),
          makeFilePickerButton(
            "Select Wwise install directory",
            widget.prefs.wwise2012CliPath!.value.isNotEmpty ? widget.prefs.wwise2012CliPath!.value : null,
            (dir) {
              var cliExe = findWwiseCliExe(dir);
              if (cliExe != null)
                widget.prefs.wwise2012CliPath!.value = cliExe;
              else {
                widget.prefs.wwise2012CliPath!.value = "";
                showToast("Could not find Wwise CLI executable in directory");
              }
            },
          ),
        ],
      ),
      Row(
        children: [
          const SizedBox(width: 20,),
          const Text("Download for example from "),
          TextButton(
            onPressed: () => launchUrl(Uri.parse("https://www.saintsrowmods.com/forum/pages/wwise-sriv/#:~:text=I%20agree%2C%20download%20Wwise")),
            child: Text("here", style: TextStyle(decoration: TextDecoration.underline),),
          ),
        ],
      ),
      Row(
        children: [
          const Text("Pause audio playback when switching files:", overflow: TextOverflow.ellipsis,),
          BoolPropSwitch(prop: widget.prefs.pauseAudioOnFileChange!),
        ],
      ),
    ];
  }
}
