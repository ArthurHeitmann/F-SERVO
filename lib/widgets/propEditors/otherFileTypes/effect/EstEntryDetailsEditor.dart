
import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/otherFileTypes/EstFileData.dart';
import '../../simpleProps/propEditorFactory.dart';
import 'EstTexturePreview.dart';
import 'RgbPropEditor.dart';

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _getWidgets(),
    );
  }

  List<Widget> _getWidgets() {
    var entry = widget.entry;
    if (entry is EstPartEntryWrapper)
      return _getPartWidgets(entry);
    else if (entry is EstMoveEntryWrapper)
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

  List<Widget> _getPartWidgets(EstPartEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Unknown", prop: entry.unknown),
      _EntryPropEditor(label: "Anchor bone ID", prop: entry.anchorBone),
    ];
  }
  
  List<Widget> _getMoveWidgets(EstMoveEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Offset", prop: entry.offset),
      _EntryPropEditor(label: "Spawn box size", prop: entry.spawnBoxSize),
      _EntryPropEditor(label: "Move speed", prop: entry.moveSpeed),
      _EntryPropEditor(label: "Move small speed", prop: entry.moveSmallSpeed),
      _EntryPropEditor(label: "Rotation (°)", prop: entry.angle),
      _EntryPropEditor(label: "Scale (main)", prop: entry.scaleY),
      _EntryPropEditor(label: "Scale (secondary)", prop: entry.scaleX),
      _EntryPropEditor(label: "Scale (?)", prop: entry.scaleZ),
      _EntryPropEditor(label: "Color", child: RgbPropEditor(prop: entry.rgb)),
      _EntryPropEditor(label: "Alpha", prop: entry.alpha),
      _EntryPropEditor(label: "Fade in speed", prop: entry.fadeInSpeed),
      _EntryPropEditor(label: "Fade out speed", prop: entry.fadeOutSpeed),
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
      Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _EntryPropEditor(label: "Texture file ID", prop: entry.textureFileId),
                _EntryPropEditor(label: "Texture index", prop: entry.textureFileTextureIndex),
              ],
            ),
          ),
          EstTexturePreview(
            textureFileId: (widget.entry as EstTexEntryWrapper).textureFileId,
            textureFileTextureIndex: (widget.entry as EstTexEntryWrapper).textureFileTextureIndex,
            size: 50,
          ),
        ],
      ),
      _EntryPropEditor(label: "Mesh ID", prop: entry.meshId),
      _EntryPropEditor(label: "Is single frame", prop: entry.isSingleFrame),
      _EntryPropEditor(label: "Video FPS (?)", prop: entry.videoFps),
    ];
  }

  List<Widget> _getFwkWidgets(EstFwkEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Imported effect EST index", prop: entry.importedEffectId),
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
