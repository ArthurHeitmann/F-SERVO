
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../misc/RowSeparated.dart';
import 'NumberPropTextField.dart';
import 'propTextField.dart';

const List<String> _coordChars = ["X", "Y", "Z"];
const List<Color> _coordColors = [Colors.red, Colors.green, Colors.blue];
BoxConstraints constraintsFromCount(int count, bool compactMode) {
  if (compactMode)
    return BoxConstraints(minWidth: 15);
  if (count < 3)
    return BoxConstraints(minWidth: 150, maxWidth: 150);
  else if (count == 3)
    return BoxConstraints(minWidth: 100, maxWidth: 100);
  else
    return BoxConstraints(minWidth: 35, maxWidth: 60);
}

class VectorPropEditor<T extends PropTextField> extends StatelessWidget {
  final VectorProp prop;

  const VectorPropEditor({super.key, required this.prop});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool compact = constraints.maxWidth / prop.length < 60;
              bool veryCompact = constraints.maxWidth / prop.length < 25;
              return !veryCompact ? RowSeparated(
                mainAxisSize: MainAxisSize.min,
                separatorWidth: compact ? 1 : 5,
                children: [
                  for (var i = 0; i < prop.length; i++)
                    Flexible(
                      child: NumberPropTextField<T>(
                        prop: prop[i],
                        constraints: constraintsFromCount(prop.length, compact),
                        left: prop.length == 3 && !compact
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
              )
              : PropTextField.make<T>(prop: prop);
            }
          ),
        );
      }
    );
  }
}
