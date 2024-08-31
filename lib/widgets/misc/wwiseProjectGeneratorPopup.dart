
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../main.dart';
import '../../stateManagement/Property.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/utils.dart';
import '../../utils/wwiseProjectGenerator/wwiseProjectGenerator.dart';
import '../propEditors/UnderlinePropTextField.dart';
import '../propEditors/boolPropCheckbox.dart';
import '../propEditors/propTextField.dart';
import '../theme/customTheme.dart';
import 'ChangeNotifierWidget.dart';
import 'SmoothScrollBuilder.dart';

void showWwiseProjectGeneratorPopup(String bnkPath) {
  showDialog(
    context: getGlobalContext(),
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: getTheme(context).sidebarBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.of(context).size.height - 100),
          child: _WwiseProjectGeneratorPopup(bnkPath),
        ),
      ),
    )
  );
}

class _WwiseProjectGeneratorPopup extends StatefulWidget {
  final String bnkPath;
  String get bnkName => basenameWithoutExtension(bnkPath);

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
  final randomObjId = BoolProp(false, fileId: null);
  final randomWemId = BoolProp(false, fileId: null);
  late final StringProp projectName;
  late final StringProp savePath;
  late final List<String> bnkPaths;
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
    projectName = StringProp(widget.bnkName, fileId: null);
    savePath = StringProp(prefs.lastWwiseProjectDir?.value ?? "", fileId: null);
    status.logs.addListener(onNewLog);
    status.isDone.addListener(() => setState(() {}));
    bnkPaths = [widget.bnkPath];
  }

  @override
  void dispose() {
    optAudioHierarchy.dispose();
    optWems.dispose();
    optStreaming.dispose();
    optStreamingPrefetch.dispose();
    optSeekTable.dispose();
    optTranslate.dispose();
    optNameId.dispose();
    optNamePrefix.dispose();
    optEvents.dispose();
    optActions.dispose();
    randomObjId.dispose();
    randomWemId.dispose();
    projectName.dispose();
    savePath.dispose();
    status.dispose();
    logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothSingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Generate Wwise project", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 15),
          if (!hasStarted)
            ..._makeOptions(context)
          else
            ..._makeStatus(context),
        ],
      ),
    );
  }

  List<Widget> _makeOptions(BuildContext context) {
    var includeOptions = [
      ("Object Hierarchy", optAudioHierarchy, Icons.account_tree_rounded, null),
      ("Events", optEvents, Icons.priority_high, null),
      ("Actions", optActions, Icons.keyboard_double_arrow_right, null),
      ("WAV sources*", optWems, Icons.audio_file, "requires \"WEM Extract Directory\" from settings"),
    ];
    var audioOptions = [
      ("Seek table", optSeekTable, Icons.skip_next_rounded),
      ("Enable streaming", optStreaming, Icons.download),
      ("Enable zero latency", optStreamingPrefetch, Icons.bolt),
    ];
    var labeledNameOptions = [
      ("Parent state as prefix", optNamePrefix),
      ("Object ID", optNameId),
    ];
    var randomOptions = [
      ("Object IDs", randomObjId),
      ("WEM IDs", randomWemId),
    ];
    return [
      const Text("Source BNKs:"),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SmoothSingleChildScrollView(
          child: Column(
            children: [
              for (var (i, bnkPath) in bnkPaths.indexed)
                Row(
                  key: Key(bnkPath),
                  children: [
                    const SizedBox(width: 20),
                    Text(basename(bnkPath)),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      splashRadius: 16,
                      constraints: BoxConstraints.tight(const Size(30, 30)),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        bnkPaths.removeAt(i);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              Row(
                children: [
                  const SizedBox(width: 15),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tight(const Size(30, 30)),
                    onPressed: () async {
                      var files = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ["bnk"],
                        allowMultiple: true,
                        dialogTitle: "Select BNKs",
                      );
                      if (files == null)
                        return;
                      bnkPaths.addAll(files.paths.whereType<String>());
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          )
        ),
      ),
      const SizedBox(height: 15),
      const Text("Projects save path:"),
      Row(
        children: [
          Expanded(
            child: UnderlinePropTextField(prop: savePath)
          ),
          const SizedBox(width: 10),
          IconButton(
            constraints: BoxConstraints.tight(const Size(30, 30)),
            splashRadius: 17,
            padding: EdgeInsets.zero,
            onPressed: () async {
              var dir = await FilePicker.platform.getDirectoryPath(
                dialogTitle: "Select project save path",
              );
              if (dir == null)
                return;
              savePath.value = dir;
              PreferencesData().lastWwiseProjectDir!.value = dir;
            },
            icon: const Icon(Icons.folder, size: 17,),
          )
        ],
      ),
      Row(
        children: [
          const Text("Project name:"),
          const SizedBox(width: 10),
          UnderlinePropTextField(prop: projectName, options: const PropTFOptions(useIntrinsicWidth: true)),
        ],
      ),
      const SizedBox(height: 15),
      const Text("Include from BNK:"),
      const SizedBox(height: 2),
      Row(
        children: [
          for (var (label, prop, icon, tooltip) in includeOptions)
            ..._makePropCheckbox(prop, label, tooltip: tooltip, icon: icon),
        ],
      ),
      const SizedBox(height: 15),
      const Text("Audio settings:"),
      Row(
        children: [
          for (var (label, prop, icon) in audioOptions)
            ..._makePropCheckbox(prop, label, icon: icon),
        ],
      ),
      const SizedBox(height: 15),
      const Text("Other settings:"),
      const SizedBox(height: 2),
      Row(
        children: [
          const Text("Randomize      "),
          for (var (label, prop) in randomOptions)
            ..._makePropCheckbox(prop, label),
        ],
      ),
      Row(
        children: [
          const Text("Name settings  "),
          for (var (label, prop) in labeledNameOptions)
            ..._makePropCheckbox(prop, label),
        ],
      ),
      ChangeNotifierBuilder(
        notifiers: [optNameId, optNamePrefix],
        builder: (context) => Text(
          "                Preview: "
          "${(optNamePrefix.value ? "[Intro] " : "")}"
          "Stage_Prologue "
          "${(optNameId.value ? "(715346925)" : "")}",
        ),
      ),
      Row(
        children: [
          const Text("Translate notes"),
            ..._makePropCheckbox(optTranslate, "Japanese to English", icon: Icons.translate_rounded),
        ],
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

  List<Widget> _makePropCheckbox(BoolProp prop, String label, {IconData? icon, String? tooltip}) {
    return [
      BoolPropCheckbox(prop: prop),
      GestureDetector(
        onTap: () => prop.value = !prop.value,
        child: Row(
          children: [
            if (icon != null) ...[
              // const SizedBox(width: 2),
              Icon(icon, size: 16),
            ],
            const SizedBox(width: 5),
            tooltip == null
              ? Text(label, overflow: TextOverflow.ellipsis)
              : Tooltip(
                  message: tooltip,
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
            const SizedBox(width: 5),
          ],
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
      randomObjId: randomObjId.value,
      randomWemId: randomWemId.value,
    );
    hasStarted = true;
    setState(() {});
    generator = await WwiseProjectGenerator.generateFromBnks(
      projectName.value,
      bnkPaths,
      savePath.value,
      options,
      status,
    );
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
