import 'package:flutter/material.dart';

class ResizablePanel extends StatefulWidget {
  final Widget child;
  final bool dragTop, dragRight, dragBottom, dragLeft;
  final double initWidth, initHeight;

  const ResizablePanel({Key? key, required this.child,
                        this.dragTop = false, this.dragRight = false, this.dragBottom = false, this.dragLeft = false,
                        this.initWidth = 200, this.initHeight = 200}
                        )
    : super(key: key);

  @override
  State<ResizablePanel> createState() => ResizablePanelState();
}

class ResizablePanelState extends State<ResizablePanel> {
  double width = 0, height = 0;

  @override
  void initState() {
    super.initState();

    width = widget.initWidth;
    height = widget.initHeight;
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: widget.dragLeft || widget.dragRight ?
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
        )
        : BoxConstraints(
          minHeight: height,
          maxHeight: height,
        ),
      child: widget.child,
    );
  }
}

