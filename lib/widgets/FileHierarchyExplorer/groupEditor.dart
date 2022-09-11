
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';

class GroupEditor extends ChangeNotifierWidget {
  GroupEditor({super.key}) : super(notifier: openHierarchyManager);

  @override
  State<GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ChangeNotifierState<GroupEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        makeTopRow(),
        Divider(height: 1),
        Expanded(
          key: Key(openHierarchyManager.selectedEntry?.name ?? "noGroup"),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              children: openHierarchyManager.selectedEntry is HapGroupHierarchyEntry ? [
                Container(
                  decoration: BoxDecoration(
                    color: getTheme(context).textFieldBgColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: TextFormField(
                    initialValue: openHierarchyManager.selectedEntry!.name,
                  ),
                ),
                Text("Tokens:"),
                for (var token in (openHierarchyManager.selectedEntry as HapGroupHierarchyEntry).tokens)
                  Row(
                    children: [
                      Text(token.item1.toString()),
                      SizedBox(width: 5),
                      Text(token.item2.toString()),
                    ],
                  ),
              ]
              : [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("No group selected"),
                )
              ],
            ),
          )
        )
      ],
    );
  }

  Widget makeTopRow() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text("GROUP EDITOR", 
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Row(
          children: [
            // Tooltip(
            //   message: "Expand all",
            //   waitDuration: Duration(milliseconds: 500),
            //   child: IconButton(
            //     padding: EdgeInsets.all(5),
            //     constraints: BoxConstraints(),
            //     iconSize: 20,
            //     splashRadius: 20,
            //     icon: Icon(Icons.unfold_more),
            //     onPressed: openHierarchyManager.expandAll,
            //   ),
            // ),
            // Tooltip(
            //   message: "Collapse all",
            //   waitDuration: Duration(milliseconds: 500),
            //   child: IconButton(
            //     padding: EdgeInsets.all(5),
            //     constraints: BoxConstraints(),
            //     iconSize: 20,
            //     splashRadius: 20,
            //     icon: Icon(Icons.unfold_less),
            //     onPressed: openHierarchyManager.collapseAll,
            //   ),
            // ),
          ],
        ),
      ],
    );
  }
}
