
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../misc/RowSeparated.dart';
import 'NumberPropTextField.dart';

const List<String> _coordChars = ["X", "Y", "Z"];
const List<Color> _coordColors = [Colors.red, Colors.green, Colors.blue];
BoxConstraints constraintsFromCount(int count) {
  if (count < 3)
    return BoxConstraints(minWidth: 150, maxWidth: 150);
  else if (count == 3)
    return BoxConstraints(minWidth: 100, maxWidth: 100);
  else
    return BoxConstraints(minWidth: 35, maxWidth: 60);
}

class VectorPropEditor extends StatelessWidget {
  final VectorProp prop;

  const VectorPropEditor({super.key, required this.prop});

  @override
  Widget build(BuildContext context) {
    return RowSeparated(
      mainAxisSize: MainAxisSize.min,
      separatorWidth: 5,
      children: [
        for (var i = 0; i < prop.length; i++)
          Flexible(
            child: NumberPropTextField(
              prop: prop[i],
              constraints: constraintsFromCount(prop.length),
              left: prop.length == 3
                ? Padding(
                  padding: const EdgeInsets.only(right: 4, left: 6),
                  child: Opacity(
                    opacity: 0.4,
                    child: Text(
                      _coordChars[i], style: TextStyle(
                        color: _coordColors[i],
                        fontWeight: FontWeight.w900,
                        fontSize: 13
                      )
                    )
                  ),
                )
                : null
            ),
          ),
      ],
    );
  }
}
