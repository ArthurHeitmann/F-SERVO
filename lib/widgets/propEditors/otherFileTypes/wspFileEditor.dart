
import 'package:flutter/material.dart';

import '../../../stateManagement/openFileTypes.dart';
import '../../misc/SmoothScrollBuilder.dart';
import 'wemFileEditor.dart';

class WspFileEditor extends StatefulWidget {
  final WspFileData wsp;

  const WspFileEditor({ super.key, required this.wsp });

  @override
  State<WspFileEditor> createState() => _WspFileEditorState();
}

class _WspFileEditorState extends State<WspFileEditor> {
  final controller = ScrollController();

  @override
  void initState() {
    widget.wsp.load().then((_) => setState(() {}));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothScrollBuilder(
      controller: controller,
      builder: (context, controller, physics) => ListView.builder(
        controller: controller,
        physics: physics,
        itemCount: widget.wsp.wems.length,
        cacheExtent: 250,
        itemBuilder: (context, i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i == 0)
              const SizedBox(height: 20),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            WemFileEditor(wem: widget.wsp.wems[i], lockControls: true),
            if (i != widget.wsp.wems.length - 1)
              const Divider(height: 30,),
          ],
        ),
      ),
    );
  }
}
