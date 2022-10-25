
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/showOnHover.dart';
import 'XmlActionPresets.dart';

class ActionAddButton extends StatelessWidget {
  final XmlProp parent;
  final int index;

  const ActionAddButton({super.key, required this.parent, this.index = -1});

  @override
  Widget build(BuildContext context) {
    return ShowOnHover(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20, maxHeight: 20, maxWidth: 400),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -10,
              right: -10,
              bottom: -10,
              left: -10,
              child: Material(
                color: Colors.transparent,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: const Offset(15, 0),
                    child: IconButton(
                      constraints: BoxConstraints.tight(const Size(30, 30)),
                      padding: EdgeInsets.zero,
                      splashRadius: 15,
                      iconSize: 25,
                      onPressed: () async {
                        var newProp = await XmlActionPresets.action.withCxtV(parent).prop();
                        if (newProp == null)
                          return;
                        if (index == -1)
                          parent.add(newProp);
                        else {
                          var sizeIndex = parent.indexWhere((ch) => ch.tagName == "size");
                          parent.insert(index + sizeIndex + 1, newProp);
                        }
                        var sizeProp = parent.get("size")!.value as NumberProp;
                        sizeProp.value += 1;
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
