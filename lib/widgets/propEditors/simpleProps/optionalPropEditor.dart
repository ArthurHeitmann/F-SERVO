

import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/smallButton.dart';
import 'propEditorFactory.dart';

class OptionalPropEditor extends StatefulWidget {
  final XmlProp? prop;
  final XmlProp parent;
  final void Function() onAdd;

  const OptionalPropEditor({super.key, this.prop, required this.parent, required this.onAdd});

  @override
  State<OptionalPropEditor> createState() => _OptionalPropEditorState();
}

class _OptionalPropEditorState extends State<OptionalPropEditor> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.prop == null) {
      return Padding(
        padding: const EdgeInsets.all(2.5),
        child: SmallButton(
          onPressed: widget.onAdd,
          constraints: BoxConstraints.tight(Size(25, 24)),
          child: Icon(Icons.add, size: 17,),
        ),
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(child: makePropEditor(widget.prop!.value)),
          SizedBox(width: 5),
          AnimatedOpacity(
            duration: Duration(milliseconds: 100),
            opacity: isHovered ? 1 : 0,
            child: SmallButton(
              onPressed: () => widget.parent.remove(widget.prop!),
              constraints: BoxConstraints.tight(Size(25, 25)),
              child: Icon(Icons.remove, size: 17,),
            ),
          ),
        ],
      ),
    );
  }
}
