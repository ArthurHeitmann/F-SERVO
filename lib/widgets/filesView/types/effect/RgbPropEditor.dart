
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../propEditors/VectorPropEditor.dart';
import '../../../propEditors/propEditorFactory.dart';

class RgbPropEditor extends StatelessWidget {
  final VectorProp prop;
  final bool showTextFields;

  const RgbPropEditor({super.key, required this.prop, this.showTextFields = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChangeNotifierBuilder(
          notifier: prop,
          builder: (context) {
            double maxVal = prop
              .map((e) => e.value.toDouble())
              .reduce(max);
            maxVal = max(maxVal, 1.0);
            return Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Color.fromARGB(
                  255,
                  (prop[0].value.toDouble() / maxVal * 255).toInt(),
                  (prop[1].value.toDouble() / maxVal * 255).toInt(),
                  (prop[2].value.toDouble() / maxVal * 255).toInt(),
                ),
                border: Border.all(
                  color: Colors.black,
                ),
              ),
            );
          }
        ),
        if (showTextFields) ...[
          const SizedBox(width: 10),
          Flexible(
            child: makePropEditor(
              prop,
              const VectorPropTFOptions(
                chars: ["R", "G", "B"],
              )
            ),
          ),
        ],
      ],
    );
  }
}
