
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
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
  late final BoolProp optAudioHierarchy;
  late final BoolProp optWems;
  late final BoolProp optStreaming;
  late final BoolProp optStreamingPrefetch;
  late final BoolProp optSeekTable;
  late final BoolProp optTranslate;
  late final BoolProp optNameId;
  late final BoolProp optNamePrefix;
  late final BoolProp optEvents;
  late final BoolProp optActions;
  late final BoolProp randomObjId;
  late final BoolProp randomWemId;
  late final StringProp projectName;
  late final StringProp savePath;
  late final List<String> bnkPaths;
  WwiseProjectGenerator? generator;
  bool hasStarted = false;
  final status = WwiseProjectGeneratorStatus();
  final logScrollController = ScrollController();
  bool isScrollQueued = false;
  bool isDroppingFile = false;

  @override
  void initState() {
    super.initState();
    var prefs = PreferencesData();
    var lastSettings = prefs.lastWwiseProjectSettings?.value ?? {};
    optAudioHierarchy = BoolProp(lastSettings["optAudioHierarchy"] as bool? ?? true, fileId: null);
    optWems = BoolProp(lastSettings["optWems"] as bool? ?? true, fileId: null);
    optStreaming = BoolProp(lastSettings["optStreaming"] as bool? ?? true, fileId: null);
    optStreamingPrefetch = BoolProp(lastSettings["optStreamingPrefetch"] as bool? ?? true, fileId: null);
    optSeekTable = BoolProp(widget.bnkName.contains("BGM"), fileId: null);
    optTranslate = BoolProp(lastSettings["optTranslate"] as bool? ?? true, fileId: null);
    optNameId = BoolProp(lastSettings["optNameId"] as bool? ?? false, fileId: null);
    optNamePrefix = BoolProp(lastSettings["optNamePrefix"] as bool? ?? true, fileId: null);
    optEvents = BoolProp(lastSettings["optEvents"] as bool? ?? true, fileId: null);
    optActions = BoolProp(lastSettings["optActions"] as bool? ?? true, fileId: null);
    randomObjId = BoolProp(lastSettings["randomObjId"] as bool? ?? false, fileId: null);
    randomWemId = BoolProp(lastSettings["randomWemId"] as bool? ?? false, fileId: null);
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
          Text("Generate Wwise project (experimental)", style: Theme.of(context).textTheme.titleLarge),
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
      Row(
        children: [
          const Text("Project name:"),
          const SizedBox(width: 10),
          UnderlinePropTextField(prop: projectName, options: const PropTFOptions(useIntrinsicWidth: true)),
        ],
      ),
      const SizedBox(height: 5),
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
      const SizedBox(height: 5),
      const Text("Source BNKs:"),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50, maxHeight: 200),
        child: DropTarget(
          onDragEntered: (_) => setState(() => isDroppingFile = true),
          onDragExited: (_) => setState(() => isDroppingFile = false),
          onDragDone: (details) {
            isDroppingFile = false;
            var newBnks = details.files
              .map((f) => f.path)
              .where((f) => f.endsWith(".bnk"))
              .where((f) => !bnkPaths.contains(f))
              .toList();
            bnkPaths.addAll(newBnks);
            setState(() {});
          },
          child: Stack(
            children: [
              _makeBnkList(context),
              if (isDroppingFile)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: DottedBorder(
                      strokeWidth: 2,
                      color: getTheme(context).textColor!.withOpacity(0.25),
                      radius: const Radius.circular(12),
                      borderType: BorderType.RRect,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.file_download_outlined, size: 20),
                            const SizedBox(width: 5),
                            Text("Drop BNK files", style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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

  Widget _makeBnkList(context) {
    return Row(
      children: [
        Expanded(
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
        Tooltip(
          message: "Drop BNK files here",
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: getTheme(context).textColor!.withOpacity(0.25), width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Icon(
              Icons.file_download_outlined,
              color: getTheme(context).textColor!.withOpacity(0.5),
              size: 30,
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
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
    var prefs = PreferencesData();
    prefs.lastWwiseProjectSettings!.value = {
      "optAudioHierarchy": optAudioHierarchy.value,
      "optWems": optWems.value,
      "optStreaming": optStreaming.value,
      "optStreamingPrefetch": optStreamingPrefetch.value,
      "optSeekTable": optSeekTable.value,
      "optTranslate": optTranslate.value,
      "optNameId": optNameId.value,
      "optNamePrefix": optNamePrefix.value,
      "optEvents": optEvents.value,
      "optActions": optActions.value,
      "randomObjId": randomObjId.value,
      "randomWemId": randomWemId.value,
    };
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
    if (isScrollQueued)
      return;
    isScrollQueued = true;
    waitForNextFrame().then((_) {
      try {
        logScrollController.jumpTo(logScrollController.position.maxScrollExtent);
      // ignore: empty_catches
      } catch (e) {}
      isScrollQueued = false;
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
