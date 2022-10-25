

import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../stateManagement/xmlProps/xmlActionProp.dart';
import '../misc/Selectable.dart';
import '../misc/SmoothSingleChildScrollView.dart';
import '../propEditors/xmlActions/XmlActionDetails.dart';

class XmlActionDetailsEditor extends ChangeNotifierWidget {
  XmlActionDetailsEditor({super.key}) : super(notifier: selectable);

  @override
  State<XmlActionDetailsEditor> createState() => _XmlActionDetailsEditorState();
}

class _XmlActionDetailsEditorState extends ChangeNotifierState<XmlActionDetailsEditor> {
  @override
  Widget build(BuildContext context) {
    XmlActionProp? action = selectable.get<XmlActionProp>(areasManager.activeArea);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        makeTopRow(),
        const Divider(height: 1),
        Expanded(
          child: SmoothSingleChildScrollView(
            stepSize: 60,
            controller: ScrollController(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: action != null
                ? XmlActionDetails(key: ValueKey(action), action: action)
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
            child: Text("ACTION PROPERTIES", 
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
