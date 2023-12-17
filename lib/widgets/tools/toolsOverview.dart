
import 'package:flutter/material.dart';

import '../misc/SmoothScrollBuilder.dart';
import '../theme/customTheme.dart';
import 'ExtractFileTool.dart';

class ToolsOverview extends StatefulWidget {
  const ToolsOverview({super.key});

  @override
  State<ToolsOverview> createState() => _ToolsOverviewState();
}

class _ToolsOverviewState extends State<ToolsOverview> {
  final scrollController = ScrollController();
  final extractToolKey = const PageStorageKey("extractTool");

  @override
  Widget build(BuildContext context) {
    return SmoothSingleChildScrollView(
      controller: scrollController,
      child: Column(
        children: [
          ExpansionTile(
            key: extractToolKey,
            title: const Text("Extract Files"),
            initiallyExpanded: true,
            textColor: getTheme(context).textColor,
            maintainState: true,
            children: [
              ExtractFilesTool()
            ],
          )
        ],
      )
    );
  }
}

