import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/filesView/OpenFilesAreas.dart';
import 'package:nier_scripts_editor/ResizablePanel.dart';
import 'package:nier_scripts_editor/Sidebar.dart';

class EditorLayout extends StatelessWidget {
  const EditorLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      var maxColWidth = constraints.maxWidth * 0.4;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sidebar(
            position: Side.left,
            maxWidth: maxColWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("Files")),
                ResizablePanel(
                  dragTop: true,
                  maxHeight: constraints.maxHeight * 0.6,
                  child: Text("Group Editor"),
                )
              ],
            ),
          ),
          Expanded(
              child: Container(
                // color: Color.fromRGBO(18, 18, 18, 1),
                child: OpenFilesAreas(),
            )
          ),
          Sidebar(
              position: Side.right,
              maxWidth: maxColWidth,
              child: Text("right"),
            ),
        ],
      );
    });
  }
}
