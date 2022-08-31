import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/ResizablePanel.dart';

enum Side { left, right }

class Sidebar extends StatelessWidget {
  final Widget child;
  final Side position;

  const Sidebar({Key? key, required this.child, required this.position}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color.fromRGBO(35, 35, 35, 1),
      ),
      child: ResizablePanel(
        dragRight: position == Side.left,
        dragLeft: position == Side.right,
        initWidth: 250,
        child: child
      ),
    );
  }
}
