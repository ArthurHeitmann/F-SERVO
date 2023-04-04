
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/sync/syncListImplementations.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../../misc/syncButton.dart';
import '../customXmlProps/transformsEditor.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import 'XmlActionEditor.dart';
import 'XmlActionInnerEditor.dart';

class XmlCameraActionEditor extends XmlActionEditor {
  XmlCameraActionEditor({super.key, required super.action, required super.showDetails});

  @override
  State<XmlCameraActionEditor> createState() => _XmlCameraActionEditorState();
}

class _XmlCameraActionEditorState extends XmlActionEditorState<XmlCameraActionEditor> {
  @override
  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      SyncButton(
        uuid: widget.action.uuid,
        makeSyncedObject: () => SyncedCameraAction(
          action: widget.action,
          parentUuid: "",
        )
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}

class CameraActionInnerEditor extends XmlActionInnerEditor {
  CameraActionInnerEditor({super.key, required super.action, required super.showDetails});

  @override
  State<CameraActionInnerEditor> createState() => _CameraActionInnerEditorState();
}

class _CameraActionInnerEditorState extends XmlActionInnerEditorState<CameraActionInnerEditor> {
  @override
  Widget build(BuildContext context) {
    var action = widget.action;
    var activationArea = action.get(_activationAreaTag)!;
    var initBaseProps = action.where((e) => _initBaseTags.contains(e.tagName));
    var rotationProps = action.where((e) => _rotationTags.contains(e.tagName));
    var pos = action.get("pos")!;
    var tar = action.get("tar")!;
    var usePos = action.get("usePos")!;
    var useTar = action.get("useTarget")!;
    var miscMidProps = action.where((e) => _miscMidTags.contains(e.tagName));
    var interpTimeProps = action.where((e) => _interpTimeTags.contains(e.tagName));
    var interpTimeAccTypeProps = action.where((e) => _interpTimeAccTypeTags.contains(e.tagName));
    var endInterpTimeProps = action.where((e) => _endInterpTimeTags.contains(e.tagName));
    var endInterpTimeAccTypeProps = action.where((e) => _endInterpTimeAccTypeTags.contains(e.tagName));
    var forceProps = action.where((e) => _forceTags.contains(e.tagName));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        makeGroupWrapperMulti("Activation Area", [activationArea]),
        makeSeparator(),
        makeGroupWrapperSingle("Basics", initBaseProps),
        makeSeparator(),
        makeGroupWrapperSingle("Fixed Rotation", rotationProps),
        makeSeparator(),
        ChangeNotifierBuilder(
          notifiers: [pos, tar],
          builder: (context) {
            return _makePosAndTarWrapper(
              child: makeGroupWrapperCustom("Camera Position and Target", Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  makeGroupWrapperCustom("Position", Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      makeXmlPropEditor(usePos, widget.showDetails),
                      if (pos.isNotEmpty)
                        TransformsEditor(parent: pos),
                    ],
                  )),
                  makeGroupWrapperCustom("Target", Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      makeXmlPropEditor(useTar, widget.showDetails),
                      if (tar.isNotEmpty)
                        TransformsEditor(parent: tar),
                    ],
                  )),
                ],
              ))
            );
          }
        ),
        makeSeparator(),
        makeGroupWrapperSingle("Miscellaneous", miscMidProps),
        makeSeparator(),
        makeGroupWrapperSingle("Interpolation Time", interpTimeProps),
        makeSeparator(),
        makeGroupWrapperSingle("Interpolation Acceleration Type", interpTimeAccTypeProps),
        makeSeparator(),
        makeGroupWrapperSingle("End Interpolation Time", endInterpTimeProps),
        makeSeparator(),
        makeGroupWrapperSingle("End Interpolation Acceleration Type", endInterpTimeAccTypeProps),
        makeSeparator(),
        makeGroupWrapperSingle("Force", forceProps),
      ],
    );
  }

  Widget _makePosAndTarWrapper({ required Widget child }) {
    var pos = widget.action.get("pos")!;
    var tar = widget.action.get("tar")!;
    var usePos = widget.action.get("usePos")!;
    var useTar = widget.action.get("useTarget")!;
    return NestedContextMenu(
      buttons: [
        _makeButtonConfig("Position", "pos", pos, usePos),
        _makeButtonConfig("Target", "tar", tar, useTar),
      ],
      child: child
    );
  }
  ContextMenuButtonConfig _makeButtonConfig(String label, String tagName, XmlProp parent, XmlProp usageProp) {
    var hasProp = parent.isNotEmpty;
    return ContextMenuButtonConfig(
      "${hasProp ? "Disable" : "Enable"} $label",
      icon: Icon(hasProp ? Icons.remove : Icons.add, size: 14,),
      onPressed: () {
        if (hasProp) {
          for (var prop in parent)
            prop.dispose();
          parent.clear();
          (usageProp.value as NumberProp).value = 0;
        } else {
          parent.add(XmlProp(
            file: parent.file,
            tagId: crc32("position"),
            tagName: "position",
            strValue: "0.0 0.0 0.0",
            parentTags: parent.nextParents(),
          ));
          (usageProp.value as NumberProp).value = 1;
        }
      },
    );
  }
}

const _activationAreaTag = "area";
const _initBaseTags = { "upVec", "upVecForce", "Fovy", "Distance" };
const _rotationTags = { "Rotation_X", "Rotation_Y", "Rotation_Z", "rotateOnly" };
const _posAndTarTags = { "pos", "tar", "usePos", "useTarget" };
const _miscMidTags = {
  "interRate", "overwrite", "offset", "disableBattle", "useLimit", "limitTime",
  "accType", "playerStop", "actionCamStop", "distanceOnly", "disableCameraHit",
  "newInter", "endInter", "endAccType", "noControlTarget", "overwriteNormalInterRate",
  "normalInterRate", "useMoveOffset_", "moveOffsetScale_", "moveOffsetInterp_",
  "moveOffsetInterpStop_", "useHold", "holdDistanceX_", "holdDistanceZ_", "useHandOffInterp_",
  "handOffInterpRate_", "fixHeightUse_", "fixHeight_", "playerForceIn_", "leavePlayer_",
  "playerTargetForceInUp_", "playerTargetForceInUpDist_"
};
const _interpTimeTags = { "interpTimeDistance_", "interpTimeAngle_", "interpTimeFov_", "interpTimePosition_", "interpTimeTarget_" };
const _interpTimeAccTypeTags = { "interpTimeAccTypeDistance_", "interpTimeAccTypeAngle_", "interpTimeAccTypeFov_", "interpTimeAccTypePosition_", "interpTimeAccTypeTarget_" };
const _endInterpTimeTags = { "endInterpTimeDistance_", "endInterpTimeAngle_", "endInterpTimeFov_", "endInterpTimePosition_", "endInterpTimeTarget_" };
const _endInterpTimeAccTypeTags = { "endInterpTimeAccTypeDistance_", "endInterpTimeAccTypeAngle_", "endInterpTimeAccTypeFov_", "endInterpTimeAccTypePosition_", "endInterpTimeAccTypeTarget_" };
const _forceTags = { "forceInterTimer", "forceInterRate", "forcePosInter", "forcePosInterRate", "forceDisInter", "forceDis", "forceDisInterRate" };
