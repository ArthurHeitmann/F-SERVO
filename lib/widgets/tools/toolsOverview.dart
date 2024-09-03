
import 'package:flutter/material.dart';

import '../misc/SmoothScrollBuilder.dart';
import '../theme/customTheme.dart';
import 'ExtractFileTool.dart';
import 'ddsTools.dart';

class ToolsOverview extends StatefulWidget {
  const ToolsOverview({super.key});

  @override
  State<ToolsOverview> createState() => _ToolsOverviewState();
}

class _ToolsOverviewState extends State<ToolsOverview> {
  final extractToolKey = const PageStorageKey("extractTool");
  final textureToolKey = const PageStorageKey("textureToolKey");

  @override
  Widget build(BuildContext context) {
    return SmoothSingleChildScrollView(
      child: Column(
        children: [
          ExpansionTile(
            key: extractToolKey,
            title: const Text("Extract Files"),
            initiallyExpanded: true,
            textColor: getTheme(context).textColor,
            maintainState: true,
            children: const [
              ExtractFilesTool(),
            ],
          ),
          ExpansionTile(
            key: textureToolKey,
            title: const Text("Convert Textures"),
            initiallyExpanded: true,
            textColor: getTheme(context).textColor,
            maintainState: true,
            children: const [
              DdsTool(),
            ],
          ),
        ],
      )
    );
  }
}

