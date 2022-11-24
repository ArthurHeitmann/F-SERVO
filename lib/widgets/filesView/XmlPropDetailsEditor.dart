

import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../misc/Selectable.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../propEditors/xmlActions/XmlPropDetails.dart';

class XmlPropDetailsEditor extends ChangeNotifierWidget {
  XmlPropDetailsEditor({super.key}) : super(notifier: selectable.active);

  @override
  State<XmlPropDetailsEditor> createState() => _XmlPropDetailsEditorState();
}

class _XmlPropDetailsEditorState extends ChangeNotifierState<XmlPropDetailsEditor> {
  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    XmlProp? prop = selectable.active.value?.prop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        makeTopRow(),
        const Divider(height: 1),
        Expanded(
          child: SmoothSingleChildScrollView(
            stepSize: 60,
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: prop != null
                ? XmlPropDetails(key: ValueKey(prop), prop: prop)
                : Container(),
            ),
          ),
        ),
      ],
    );
  }

  Widget makeTopRow() {
    return Row(
      children: const [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text("PROPERTIES", 
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
