
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/openFileTypes.dart';

class McdEditor extends ChangeNotifierWidget {
  final McdFileData file;

  McdEditor ({super.key, required this.file }) : super(notifier: file);

  @override
  State<McdEditor> createState() => _McdEditorState();
}

class _McdEditorState extends ChangeNotifierState<McdEditor> {

  @override
  void initState() {
    widget.file.load()
      .then((value) {
        print("Loaded MCD file");
        setState(() {});
      });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.file.loadingState != LoadingState.loaded) {
      return const LinearProgressIndicator();
    }

    return ListView(
      children: widget.file.mcdData!.events.map((e) => 
        Text(e.toString())
      ).toList(),
    );
  }
}
