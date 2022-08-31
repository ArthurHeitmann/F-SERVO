import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/OpenFileArea.dart';
import 'package:nier_scripts_editor/ResizablePanel.dart';
import 'package:nier_scripts_editor/Sidebar.dart';

class EditorLayout extends StatelessWidget {
  const EditorLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Sidebar(position: Side.left, child: Text("left")),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Color.fromRGBO(18, 18, 18, 1),
            ),
            child: OpenFileArea(),
          )
        ),
        Sidebar(position: Side.right, child: Text("right")),
      ],
    );
  }
}
