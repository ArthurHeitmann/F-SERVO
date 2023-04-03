

import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/onHoverBuilder.dart';
import '../../misc/smallButton.dart';
import 'XmlPropEditorFactory.dart';
import 'propEditorFactory.dart';
import 'propTextField.dart';

class OptionalPropEditor<T extends PropTextField> extends StatelessWidget {
  final XmlProp? prop;
  final XmlProp parent;
  final void Function() onAdd;

  const OptionalPropEditor({super.key, this.prop, required this.parent, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (prop == null) {
      return Padding(
        padding: const EdgeInsets.all(2.5),
        child: SmallButton(
          onPressed: onAdd,
          constraints: BoxConstraints.tight(const Size(25, 24)),
          child: const Icon(Icons.add, size: 17,),
        ),
      );
    }
    return OnHoverBuilder(
      builder: (context, isHovering) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (prop!.isEmpty)
            Flexible(child: makePropEditor<T>(prop!.value))
          else
            Flexible(child: makeXmlPropEditor<T>(prop!, true)),
          const SizedBox(width: 5),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: isHovering ? 1 : 0,
            child: SmallButton(
              onPressed: () => parent.remove(
                prop!
                  ..dispose()
              ),
              constraints: BoxConstraints.tight(const Size(25, 25)),
              child: const Icon(Icons.remove, size: 17,),
            ),
          ),
        ],
      ),
    );
  }
}
