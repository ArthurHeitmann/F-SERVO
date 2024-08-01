
import 'package:flutter/material.dart';

import '../../../../stateManagement/Property.dart';
import '../../../../stateManagement/openFiles/types/EstFileData.dart';
import '../../../propEditors/propEditorFactory.dart';
import 'EstModelPreview.dart';
import 'EstTexturePreview.dart';
import 'RgbPropEditor.dart';

class EstEntryDetailsEditor extends StatefulWidget {
  final EstEntryWrapper entry;
  final bool showUnknown;

  EstEntryDetailsEditor({required this.entry, required this.showUnknown})
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
    else if (entry is EstEmmvEntryWrapper)
      return _getEmmvWidgets(entry);
    else
      return [];
  }

  List<Widget> _getPartWidgets(EstPartEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Anchor bone ID", prop: entry.anchorBone),
      if (widget.showUnknown) ...[
        _EntryPropEditor(label: "u_a (i16)", prop: entry.u_a),
        _EntryPropEditor(label: "u_b (i16)", prop: entry.u_b),
        _EntryPropEditor(label: "u_c (u32)", prop: entry.u_c),
        _EntryPropEditor(label: "u_d (u32)", prop: entry.u_d),
        _EntryPropEditor(label: "u_e (i16)", prop: entry.u_e),
        _EntryPropEditor(label: "u_1 (i16)", prop: entry.u_1),
        _EntryPropEditor(label: "u_2 (i16)", prop: entry.u_2),
        _EntryPropEditor(label: "u_3 (i16)", prop: entry.u_3),
        _EntryPropEditor(label: "u_4 (i16)", prop: entry.u_4),
        _EntryPropEditor(label: "u_5 (i16)", prop: entry.u_5),
        _EntryPropEditor(label: "u_6 (i16)", prop: entry.u_6),
        _EntryPropEditor(label: "u_7 (f32)", prop: entry.u_7),
        _EntryPropEditor(label: "u_8 (u8)", prop: entry.u_8),
      ]
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
      if (widget.showUnknown) ...[
        _EntryPropEditor(label: "u_a (u32)", prop: entry.u_a),
        for (var i = 0; i < entry.u_b_1.length; i++)
          _EntryPropEditor(label: "u_b_1[$i] (f32)", prop: entry.u_b_1[i]),
        for (var i = 0; i < entry.u_b_2.length; i++)
          _EntryPropEditor(label: "u_b_2[$i] (f32)", prop: entry.u_b_2[i]),
        for (var i = 0; i < entry.u_c.length; i++)
          _EntryPropEditor(label: "u_c[$i] (f32)", prop: entry.u_c[i]),
        for (var i = 0; i < entry.u_d_1.length; i++)
          _EntryPropEditor(label: "u_d_1[$i] (f32)", prop: entry.u_d_1[i]),
        for (var i = 0; i < entry.u_d_2.length; i++)
          _EntryPropEditor(label: "u_d_2[$i] (f32)", prop: entry.u_d_2[i]),
      ]
    ];
  }

  List<Widget> _getEmifWidgets(EstEmifEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Count", prop: entry.count),
      _EntryPropEditor(label: "Play delay", prop: entry.playDelay),
      _EntryPropEditor(label: "Show at once", prop: entry.showAtOnce),
      _EntryPropEditor(label: "Size", prop: entry.size),
      if (widget.showUnknown) ...[
        _EntryPropEditor(label: "u_a (i16)", prop: entry.u_a),
        _EntryPropEditor(label: "u_b (i16)", prop: entry.u_b),
        _EntryPropEditor(label: "u_c (i16)", prop: entry.u_c),
        _EntryPropEditor(label: "unk (i16)", prop: entry.unk),
        for (var i = 0; i < entry.u_d.length; i++)
          _EntryPropEditor(label: "u_d[$i] (f32)", prop: entry.u_d[i]),
      ]
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
                _EntryPropEditor(label: "Texture index", prop: entry.textureFileIndex),
              ],
            ),
          ),
          EstTexturePreview(
            textureFileId: (widget.entry as EstTexEntryWrapper).textureFileId,
            textureFileTextureIndex: (widget.entry as EstTexEntryWrapper).textureFileIndex,
            size: 50,
          ),
        ],
      ),
      Row(
        children: [
          Expanded(child: _EntryPropEditor(label: "Mesh ID", prop: entry.meshId)),
          EstModelPreview(
            modelId: (widget.entry as EstTexEntryWrapper).meshId,
            size: 35,
          ),
        ],
      ),
      _EntryPropEditor(label: "Is single frame", prop: entry.isSingleFrame),
      _EntryPropEditor(label: "Video FPS (?)", prop: entry.videoFps),
      if (widget.showUnknown) ...[
        _EntryPropEditor(label: "u_c (i16)", prop: entry.u_c),
        _EntryPropEditor(label: "u_d2 (f32)", prop: entry.u_d2),
        _EntryPropEditor(label: "u_d3 (f32)", prop: entry.u_d3),
        _EntryPropEditor(label: "u_d4 (f32)", prop: entry.u_d4),
        _EntryPropEditor(label: "u_d5 (f32)", prop: entry.u_d5),
        _EntryPropEditor(label: "u_g (f32)", prop: entry.u_g),
        _EntryPropEditor(label: "u_h (i16)", prop: entry.u_h),
        _EntryPropEditor(label: "u_i (f32)", prop: entry.distortion_effect_strength),
        for (var i = 0; i < entry.u_i2.length; i++)
          _EntryPropEditor(label: "u_i2[$i] (f32)", prop: entry.u_i2[i]),
        _EntryPropEditor(label: "u_i3 (u32)", prop: entry.u_i3),
        for (var i = 0; i < entry.u_i4.length; i++)
          _EntryPropEditor(label: "u_i4[$i] (f32)", prop: entry.u_i4[i]),
        _EntryPropEditor(label: "u_j (f32)", prop: entry.u_j),
      ]
    ];
  }
  
  List<Widget> _getEmmvWidgets(EstEmmvEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "u_a", prop: entry.u_a),
      _EntryPropEditor(label: "Left pos 1", prop: entry.leftPos1),
      _EntryPropEditor(label: "Top pos", prop: entry.topPos),
      _EntryPropEditor(label: "Unk pos 1", prop: entry.unkPos1),
      _EntryPropEditor(label: "Random pos 1", prop: entry.randomPos1),
      _EntryPropEditor(label: "Top bottom random pos 1", prop: entry.topBottomRandomPos1),
      _EntryPropEditor(label: "Front back random pos 1", prop: entry.frontBackRandomPos1),
      _EntryPropEditor(label: "Left pos 2", prop: entry.leftPos2),
      _EntryPropEditor(label: "Front pos 1", prop: entry.frontPos1),
      _EntryPropEditor(label: "Front pos 2", prop: entry.frontPos2),
      _EntryPropEditor(label: "Left right random pos 1", prop: entry.leftRightRandomPos1),
      _EntryPropEditor(label: "Random pos 2", prop: entry.randomPos2),
      _EntryPropEditor(label: "Front back random pos 2", prop: entry.frontBackRandomPos2),
      _EntryPropEditor(label: "Unk pos 2", prop: entry.unkPos2),
      _EntryPropEditor(label: "Left pos random 1", prop: entry.leftPosRandom1),
      _EntryPropEditor(label: "Top pos 2", prop: entry.topPos2),
      _EntryPropEditor(label: "Front pos 3", prop: entry.frontPos3),
      _EntryPropEditor(label: "Effect size", prop: entry.effectSize),
      if (widget.showUnknown) ...[
        _EntryPropEditor(label: "Unk pos 3", prop: entry.unkPos3),
        _EntryPropEditor(label: "Unk pos 4", prop: entry.unkPos4),
        _EntryPropEditor(label: "Unk pos 5", prop: entry.unkPos5),
        _EntryPropEditor(label: "Unk pos 6", prop: entry.unkPos6),
        _EntryPropEditor(label: "Unk pos 7", prop: entry.unkPos7),
        _EntryPropEditor(label: "Unk pos 8", prop: entry.unkPos8),
        _EntryPropEditor(label: "Unk pos 9", prop: entry.unkPos9),
        _EntryPropEditor(label: "Unk pos 10", prop: entry.unkPos10),
        _EntryPropEditor(label: "Unk pos 11", prop: entry.unkPos11),
        _EntryPropEditor(label: "Unk pos 25", prop: entry.unkPos25),
        _EntryPropEditor(label: "Unk pos 26", prop: entry.unkPos26),
        _EntryPropEditor(label: "Unk pos 27", prop: entry.unkPos27),
        _EntryPropEditor(label: "Unk pos 28", prop: entry.unkPos28),
        _EntryPropEditor(label: "Unk pos 29", prop: entry.unkPos29),
        _EntryPropEditor(label: "Unk pos 30", prop: entry.unkPos30),
        _EntryPropEditor(label: "Unk pos 31", prop: entry.unkPos31),
        for (var i = 0; i < entry.u_b_1.length; i++)
          _EntryPropEditor(label: "u_b_1[$i]", prop: entry.u_b_1[i]),
        _EntryPropEditor(label: "Sword pos", prop: entry.swordPos),
        for (var i = 0; i < entry.u_b_2.length; i++)
          _EntryPropEditor(label: "u_b_2[$i]", prop: entry.u_b_2[i]),
      ],
    ];
  }

  List<Widget> _getFwkWidgets(EstFwkEntryWrapper entry) {
    return [
      _EntryPropEditor(label: "Imported effect EST index", prop: entry.importedEffectId),
      if (widget.showUnknown) ...[
        _EntryPropEditor(label: "u_a0 (i16)", prop: entry.u_a0),
        _EntryPropEditor(label: "u_a1 (i16)", prop: entry.u_a1),
        for (var i = 0; i < entry.u_b.length; i++)
          _EntryPropEditor(label: "u_b[$i] (i16)", prop: entry.u_b[i]),
        for (var i = 0; i < entry.u_c.length; i++)
          _EntryPropEditor(label: "u_c[$i] (f32)", prop: entry.u_c[i]),
      ]
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
