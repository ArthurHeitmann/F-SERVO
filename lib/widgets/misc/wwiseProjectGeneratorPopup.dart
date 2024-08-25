
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../main.dart';
import '../../stateManagement/Property.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/utils.dart';
import '../../utils/wwiseProjectGenerator/wwiseProjectGenerator.dart';
import '../propEditors/boolPropCheckbox.dart';
import '../propEditors/primaryPropTextField.dart';
import '../propEditors/propTextField.dart';
import '../theme/customTheme.dart';
import 'ChangeNotifierWidget.dart';
import 'SmoothScrollBuilder.dart';
import 'smallButton.dart';

void showWwiseProjectGeneratorPopup(String bnkPath) {
  showDialog(
    context: getGlobalContext(),
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: getTheme(context).sidebarBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _WwiseProjectGeneratorPopup(bnkPath)
        ),
      ),
    )
  );
}

class _WwiseProjectGeneratorPopup extends StatefulWidget {
  final String bnkPath;
  String get bnkName => basename(bnkPath);

  const _WwiseProjectGeneratorPopup(this.bnkPath);

  @override
  State<_WwiseProjectGeneratorPopup> createState() => __WwiseProjectGeneratorPopupState();
}

class __WwiseProjectGeneratorPopupState extends State<_WwiseProjectGeneratorPopup> {
  final optAudioHierarchy = BoolProp(true, fileId: null);
  final optWems = BoolProp(true, fileId: null);
  final optStreaming = BoolProp(true, fileId: null);
  final optStreamingPrefetch = BoolProp(true, fileId: null);
  final optSeekTable = BoolProp(true, fileId: null);
  final optTranslate = BoolProp(true, fileId: null);
  final optNameId = BoolProp(false, fileId: null);
  final optNamePrefix = BoolProp(true, fileId: null);
  final optEvents = BoolProp(true, fileId: null);
  final optActions = BoolProp(true, fileId: null);
  final savePath = StringProp("", fileId: null);
  WwiseProjectGenerator? generator;
  bool hasStarted = false;
  final status = WwiseProjectGeneratorStatus();
  final logScrollController = ScrollController();
  bool isScrollQueue = false;

  @override
  void initState() {
    super.initState();
    if (!widget.bnkName.contains("BGM"))
      optSeekTable.value = false;
    var prefs = PreferencesData();
    savePath.value = prefs.lastWwiseProjectDir?.value ?? "";
    status.logs.addListener(onNewLog);
    status.isDone.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Generate Wwise project for ${widget.bnkName}", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 15),
        if (!hasStarted)
          ..._makeOptions(context)
        else
          ..._makeStatus(context),
      ],
    );
  }

  List<Widget> _makeOptions(BuildContext context) {
    var labeledOptions = [
      ("Actor-Mixer & Interactive Music Hierarchy", optAudioHierarchy),
      ("Events", optEvents),
      ("Actions", optActions),
      ("WAV sources (requires \"WEM Extract Directory\" from settings)", optWems),
      ("Use seek table for wems", optSeekTable),
      ("Copy streaming settings", optStreaming),
      ("Copy streaming zero latency settings", optStreamingPrefetch),
      ("Translate Japanese notes", optTranslate),
    ];
    var labeledNameOptions = [
      ("Parent state  as prefix", optNamePrefix),
      ("Object ID", optNameId),
    ];
    return [
      Row(
        children: [
          Expanded(
            child: PrimaryPropTextField(prop: savePath, options: const PropTFOptions(hintText: "Projects save path"))
          ),
          const SizedBox(width: 10),
          SmallButton(
            constraints: BoxConstraints.tight(const Size(30, 30)),
            onPressed: () async {
              var dir = await FilePicker.platform.getDirectoryPath(
                dialogTitle: "Select project save path",
              );
              if (dir == null)
                return;
              savePath.value = dir;
              PreferencesData().lastWwiseProjectDir!.value = dir;
            },
            child: const Icon(Icons.folder, size: 17,),
          )
        ],
      ),
      const SizedBox(height: 15),
      Text("Include from BNK:", style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 2),
      for (var (label, prop) in labeledOptions)
        Row(
          children: [
            BoolPropCheckbox(prop: prop),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => prop.value = !prop.value,
                child: Text(label, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      Row(
        children: [
          Text("Name settings: ", style: Theme.of(context).textTheme.bodyMedium),
          for (var (label, prop) in labeledNameOptions)
            Row(
              children: [
                BoolPropCheckbox(prop: prop),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => prop.value = !prop.value,
                  child: Text(label, style: Theme.of(context).textTheme.bodyMedium)
                ),
              ],
            ),
        ],
      ),
      ChangeNotifierBuilder(
        notifiers: [optNameId, optNamePrefix],
        builder: (context) => Text(
          "Preview: "
          "${(optNamePrefix.value ? "[Intro] " : "")}"
          "Stage_Prologue "
          "${(optNameId.value ? "(715346925)" : "")}",
        ),
      ),
      const SizedBox(height: 15),
      Align(
        alignment: Alignment.center,
        child: ElevatedButton(
          onPressed: generate,
          style: getTheme(context).dialogPrimaryButtonStyle,
          child: const Text("Generate"),
        ),
      ),
    ];
  }

  List<Widget> _makeStatus(BuildContext context) {
    return [
      SizedBox(
        height: 300,
        child: SmoothSingleChildScrollView(
          controller: logScrollController,
          child: ListenableBuilder(
            listenable: status.logs,
            builder: (context, _) {
              return SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var log in status.logs)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: log.severity.toString().split(".").last.toUpperCase(),
                              style: TextStyle(color: getSeverityColor(context, log.severity), fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " ${log.message}"),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 15),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChangeNotifierBuilder(
            notifier: status.currentMsg,
            builder: (context) => Text(status.currentMsg.value, style: Theme.of(context).textTheme.bodyLarge)
          ),
          if (status.isDone.value)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: getTheme(context).dialogSecondaryButtonStyle,
              child: const Text("Close"),
            ),
        ],
      )
    ];
  }

  void generate() async {
    if (!await Directory(savePath.value).exists()) {
      showToast("Project save path is invalid");
      return;
    }
    var options = WwiseProjectGeneratorOptions(
      audioHierarchy: optAudioHierarchy.value,
      wems: optWems.value,
      streaming: optStreaming.value,
      streamingPrefetch: optStreamingPrefetch.value,
      seekTable: optSeekTable.value,
      translate: optTranslate.value,
      events: optEvents.value,
      actions: optActions.value,
      nameId: optNameId.value,
      namePrefix: optNamePrefix.value,
    );
    hasStarted = true;
    setState(() {});
    generator = await WwiseProjectGenerator.generateFromBnk(widget.bnkPath, savePath.value, options, status);
    if (generator == null)
      return;
    setState(() {});
  }

  void onNewLog() {
    if (isScrollQueue)
      return;
    isScrollQueue = true;
    waitForNextFrame().then((_) {
      try {
        logScrollController.jumpTo(logScrollController.position.maxScrollExtent);
      // ignore: empty_catches
      } catch (e) {}
      isScrollQueue = false;
    });
  }

  Color getSeverityColor(BuildContext context, WwiseLogSeverity severity) {
    switch (severity) {
      case WwiseLogSeverity.info:
        return getTheme(context).textColor!;
      case WwiseLogSeverity.warning:
        return Colors.orange;
      case WwiseLogSeverity.error:
        return Colors.red;
    }
  }
}
