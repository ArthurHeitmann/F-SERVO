
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/otherFileTypes/EstFileData.dart';
import '../../simpleProps/VectorPropEditor.dart';
import '../../simpleProps/propEditorFactory.dart';

class EstEntryDetailsEditor extends StatefulWidget {
  final EstEntryWrapper entry;

  EstEntryDetailsEditor({required this.entry})
    : super(key: Key(entry.uuid));

  @override
  State<EstEntryDetailsEditor> createState() => _EstEntryDetailsEditorState();
}

class _EstEntryDetailsEditorState extends State<EstEntryDetailsEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: _getWidgets(),
    );
  }

  List<Widget> _getWidgets() {
    var entry = widget.entry;
    if (entry is EstMoveEntryWrapper)
      return _getMoveWidgets(entry);
    else if (entry is EstEmifEntryWrapper)
      return _getEmifWidgets(entry);
    else if (entry is EstTexEntryWrapper)
      return _getTexWidgets(entry);
    else if (entry is EstFwkEntryWrapper)
      return _getFwkWidgets(entry);
    else
      return [];
  }
  
  List<Widget> _getMoveWidgets(EstMoveEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Offset", prop: entry.offset),
      _EntryPropEditor(label: "Top pos 1", prop: entry.topPos1),
      _EntryPropEditor(label: "Right pos 1", prop: entry.rightPos1),
      _EntryPropEditor(label: "Move speed", prop: entry.moveSpeed),
      _EntryPropEditor(label: "Move small speed", prop: entry.moveSmallSpeed),
      _EntryPropEditor(label: "Angle (°)", prop: entry.angle),
      _EntryPropEditor(label: "Scale (main)", prop: entry.scaleY),
      _EntryPropEditor(label: "Scale (secondary)", prop: entry.scaleX),
      _EntryPropEditor(label: "Scale (?)", prop: entry.scaleZ),
      _EntryPropEditor(label: "Color", child: _RgbPropEditor(prop: entry.rgb)),
      _EntryPropEditor(label: "Alpha", prop: entry.alpha),
      _EntryPropEditor(label: "Fade in speed", prop: entry.smoothAppearance),
      _EntryPropEditor(label: "Fade out speed", prop: entry.smoothDisappearance),
      _EntryPropEditor(label: "Effect size limit 1", prop: entry.effectSizeLimit1),
      _EntryPropEditor(label: "Effect size limit 2", prop: entry.effectSizeLimit2),
      _EntryPropEditor(label: "Effect size limit 3", prop: entry.effectSizeLimit3),
      _EntryPropEditor(label: "Effect size limit 4", prop: entry.effectSizeLimit4),
    ];
  }

  List<Widget> _getEmifWidgets(EstEmifEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Count", prop: entry.count),
      _EntryPropEditor(label: "Play delay", prop: entry.playDelay),
      _EntryPropEditor(label: "Show at once", prop: entry.showAtOnce),
      _EntryPropEditor(label: "Size", prop: entry.size),
    ];
  }

  List<Widget> _getTexWidgets(EstTexEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Speed", prop: entry.speed),
      _EntryPropEditor(label: "Size", prop: entry.size),
      _EntryPropEditor(label: "coreeff texture file", prop: entry.coreeffTextureFile),
      _EntryPropEditor(label: "coreff tex file index 1", prop: entry.coreeffTextureFileIndex1),
      _EntryPropEditor(label: "coreff tex file index 2 (?)", prop: entry.coreeffTextureFileIndex2),
    ];
  }

  List<Widget> _getFwkWidgets(EstFwkEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Effect ID on objects", prop: entry.effectIdOnObjects),
      _EntryPropEditor(label: "Tex num 1", prop: entry.texNum1),
      _EntryPropEditor(label: "Tex num 2", prop: entry.texNum2),
      _EntryPropEditor(label: "Tex num 3", prop: entry.texNum3),
      _EntryPropEditor(label: "Left pos 1", prop: entry.leftPos1),
      _EntryPropEditor(label: "Left pos 2", prop: entry.leftPos2),
    ];
  }
}

class _EntryPropEditor extends StatelessWidget {
  final Prop? prop;
  final String label;
  final Widget? child;

  const _EntryPropEditor({required this.label, this.prop, this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const SizedBox(width: 10),
        Flexible(
          child: child ?? makePropEditor(prop!),
        ),
      ],
    );
  }
}

class _RgbPropEditor extends StatelessWidget {
  final VectorProp prop;

  const _RgbPropEditor({super.key, required this.prop});

  @override
  Widget build(BuildContext context) {
    return Row(
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
        const SizedBox(width: 10),
        Flexible(
          child: makePropEditor(
            prop,
            const VectorPropTFOptions(
              chars: ["R", "G", "B"],
            )
          ),
        )
      ],
    );
  }
}
