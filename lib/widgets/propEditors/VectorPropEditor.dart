
import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import '../misc/RowSeparated.dart';
import 'NumberPropTextField.dart';
import 'propTextField.dart';

const List<String> _coordChars = ["X", "Y", "Z"];
const List<Color> _coordColors = [Colors.red, Colors.green, Colors.blue];
BoxConstraints constraintsFromCount(int count, bool compactMode) {
  if (compactMode)
    return const BoxConstraints(minWidth: 15);
  if (count < 3)
    return const BoxConstraints(minWidth: 150, maxWidth: 150);
  else if (count == 3)
    return const BoxConstraints(minWidth: 100, maxWidth: 100);
  else
    return const BoxConstraints(minWidth: 35, maxWidth: 60);
}

class VectorPropTFOptions extends PropTFOptions {
  final List<String>? chars;
  final List<Color>? colors;

  const VectorPropTFOptions({
    super.key,
    super.constraints = const BoxConstraints(minWidth: 50),
    super.isMultiline = false,
    super.useIntrinsicWidth = true,
    super.hintText,
    super.autocompleteOptions,
    this.chars,
    this.colors,
  });
}

class VectorPropEditor<T extends PropTextField> extends StatelessWidget {
  final VectorProp prop;
  final PropTFOptions options;
  final List<String> coordChars;
  final List<Color> coordColors;

  VectorPropEditor({Key? key, required this.prop, this.options = const VectorPropTFOptions()}) :
    coordChars = (options is VectorPropTFOptions ? options.chars : null) ?? _coordChars,
    coordColors = (options is VectorPropTFOptions ? options.colors : null) ?? _coordColors,
    super(key: options.key ?? key);

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
                        options: options.copyWith(constraints: constraintsFromCount(prop.length, compact)),
                        left: prop.length == 3 && !compact
                          ? Padding(
                            padding: const EdgeInsets.only(right: 4, left: 6),
                            child: Opacity(
                              opacity: 0.4,
                              child: Text(
                                coordChars[i], style: TextStyle(
                                  color: coordColors[i],
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
              : PropTextField.make<T>(prop: prop, options: options);
            }
          ),
        );
      }
    );
  }
}
