
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseElementBase.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import 'wwiseSwitchOrState.dart';

const _actionTypes = {
  0x0400: (type: "Play", defaultName: "Play"),
  0x1C00: (type: "Break", defaultName: "Break"),
  0x0100: (type: "Stop", defaultName: "Stop"),
  0x0200: (type: "Pause", defaultName: "Pause"),
  0x0300: (type: "Resume", defaultName: "Resume"),
  0x0600: (type: "Mute", defaultName: "Mute"),
  0x0700: (type: "UnMute", defaultName: "UnMute"),
  0x0C00: (type: "ChangeBusVolume", defaultName: "Set Bus Volume"),
  0x0D00: (type: "ResetBusVolume", defaultName: "Reset Bus Volume"),
  0x0A00: (type: "ChangeVolume", defaultName: "Set Voice Volume"),
  0x0B00: (type: "ResetVolume", defaultName: "Reset Voice Volume"),
  0x0800: (type: "ChangePitch", defaultName: "Set Voice Pitch"),
  0x0900: (type: "ResetPitch", defaultName: "Reset Voice Pitch"),
  0x0E00: (type: "ChangeLPF", defaultName: "Set Voice Low-pass Filter"),
  0x0F00: (type: "ResetLPF", defaultName: "Reset Voice Low-pass Filter"),
  0x1200: (type: "SetState", defaultName: "Set State"),
  0x1000: (type: "UseState", defaultName: "Enable State"),
  0x1100: (type: "UnUseState", defaultName: "Disable State"),
  0x1900: (type: "SetSwitch", defaultName: "Set Switch"),
  0x1A00: (type: "BypassFX", defaultName: "Enable Bypass"),
  0x0000: (type: "UnBypassFX", defaultName: "Disable Bypass"),
  0x1B00: (type: "ResetBypassFX", defaultName: "Reset Bypass Effect"),
  0x1E00: (type: "Seek", defaultName: "Seek"),
  0x1D00: (type: "Trigger", defaultName: "Trigger"),
  0x1300: (type: "SetGameParameter", defaultName: "Set Game Parameter"),
  0x1400: (type: "ResetGameParameter", defaultName: "Reset Game Parameter"),
};

const _propertyByType = {
  0x0800: (prop: "Pitch", type: "int32"),
  0x0A00: (prop: "Volume", type: "Real64"),
  0x0C00: (prop: "Volume", type: "Real64"),
  0x0E00: (prop: "Lowpass", type: "int16"),
  0x1300: (prop: "GameParameterValue", type: "Real64"),
};

const _bnkPropToName = {
  0x0E: (name: "Delay", type: "Real64", div: 1000.0),
  0x0F: (name: "FadeTime", type: "Real64", div: 1000.0),
  0x10: (name: "Probability", type: "Real64", div: 1.0),
};

const _gameObjectFlag = 0x01;
const _singleFlag = 0x02;
const _allFlag = 0x04;
const _allExceptFlag = 0x08;

String _actionTypeToName(int id) {
  var type = _actionTypes[id & 0xFF00];
  var baseName = type == null
    ? "Unknown Action Type"
    : type.defaultName;
  if (id & _allFlag != 0)
    return "$baseName All";
  if (id & _allExceptFlag != 0)
    return "$baseName All Except";
  return baseName;
}

String _actionTypeToScope(int id) {
  var flag = id & 0xFF;
  if (flag & _singleFlag != 0)
    return "One";
  if (flag & _allFlag != 0)
    return "All";
  if (flag & _allExceptFlag != 0)
    return "AllExcept";
  if (id & 0xFF00 == 0x1900)  // set switch
    return "All";
  if (id & 0x1D00 == 0x1900)  // trigger
    return "One";
  throw ArgumentError("Unknown action scope flag $flag");
}

String _actionTypeToGlobal(int id) {
  return (id & _gameObjectFlag) != 0 ? "false" : "true";
}

class WwiseAction extends WwiseElement {
  final BnkAction action;
  
  WwiseAction({required super.wuId, required super.project, required this.action}) :
    super(
      tagName: "Action",
      name: _actionTypeToName(action.ulActionType),
      shortId: action.uid,
      additionalAttributes: {
        "Type": _actionTypes[action.ulActionType & 0xFF00]!.type,
        "Scope": _actionTypeToScope(action.ulActionType),
        "Global": _actionTypeToGlobal(action.ulActionType),
      }
    );
  
  @override
  void oneTimeInit() {
    super.oneTimeInit();

    List<WwiseElementBase?> elements = [];
    // target id
    if (action.initialParams.idExt != 0) {
      var lookup = action.initialParams.isBus
        ? project.buses[action.initialParams.idExt]
        : project.lookupElement(idFnv: action.initialParams.idExt);
      if (action.initialParams.idExt != 0 && lookup == null)
        project.log(WwiseLogSeverity.warning, "Unknown action target ${action.initialParams.idExt}");
      elements.add(lookup);
    }
    // exceptions
    if (action.specificParams is BnkActionParamsHasExceptions) {
      var exceptions = (action.specificParams as BnkActionParamsHasExceptions).exceptions;
      var ids = Iterable.generate(
        exceptions.ulExceptionListSize,
        (i) => (id: exceptions.ids[i], isBus: exceptions.isBus[i])
      );
      for (var (id: id, isBus: isBus) in ids) {
        var lookup = isBus != 0
          ? project.buses[id]
          : project.lookupElement(idFnv: id);
        if (lookup == null && id != 0)
          project.log(WwiseLogSeverity.warning, "Unknown action exception $id");
        elements.add(lookup);
      }
    }
    var elementList = makeElementList(elements);
    if (elementList != null)
      additionalChildren.add(elementList);
    // set value property
    if (action.specificParams is BnkValueActionParams) {
      var valueParams = action.specificParams as BnkValueActionParams;
      var valueSubParams = valueParams.specificParams;
      double? value;
      int? eValueMeaning;
      if (valueSubParams is BnkPropActionParams) {
        value = valueSubParams.base;
        eValueMeaning = valueSubParams.eValueMeaning;
      }
      else if (valueSubParams is BnkGameParameterParams) {
        value = valueSubParams.base;
        eValueMeaning = valueSubParams.eValueMeaning;
      }
      if (value != null) {
        var prop = _propertyByType[action.ulActionType & 0xFF00];
        if (prop != null) {
          properties.add(WwiseProperty(prop.prop, prop.type, value: value.toString()));
        }
      }
      if (eValueMeaning == 1) {
          properties.add(WwiseProperty("Absolute", "bool", value: "True"));
      }
    }
    // generic properties
    var valueProps = Iterable.generate(
      action.initialParams.propValues.cProps,
      (i) => (prop: action.initialParams.propValues.pID[i], value: action.initialParams.propValues.values[i])
    );
    var rangedProps = Iterable.generate(
      action.initialParams.rangedPropValues.cProps,
      (i) => (prop: action.initialParams.rangedPropValues.pID[i], value: action.initialParams.rangedPropValues.minMax[i])
    );
    for (var (prop: prop, value: value) in valueProps) {
      var propInfo = _bnkPropToName[prop];
      if (propInfo == null) {
        project.log(WwiseLogSeverity.warning, "Unknown value property 0x${prop.toRadixString(16)}");
        continue;
      }
      properties.add(WwiseProperty(propInfo.name, propInfo.type, value: (value.number / propInfo.div).toString()));
    }
    for (var (prop: prop, value: (min, max)) in rangedProps) {
      var propInfo = _bnkPropToName[prop];
      if (propInfo == null) {
        project.log(WwiseLogSeverity.warning, "Unknown ranged property 0x${prop.toRadixString(16)}");
        continue;
      }
      properties.add(WwiseProperty(
        propInfo.name,
        propInfo.type,
        project: project,
        modifierRange: (min: (min.number / propInfo.div).toString(), max: (max.number / propInfo.div).toString()),
      ));
    }
    // fade curve
    if (action.specificParams is BnkActionParamsHasBitVector) {
      var eFadeCurve = (action.specificParams as BnkActionParamsHasBitVector).byBitVector & 0x1F;
      if (eFadeCurve != 4)
        properties.add(WwiseProperty("FadeCurve", "int16", value: eFadeCurve.toString()));
    }
    // states, switches
    if (action.specificParams is BnkStateActionParams || action.specificParams is BnkSwitchActionParams) {
      WwiseSwitchOrStateGroup group;
      WwiseSwitchOrState? groupItem;
      if (action.specificParams is BnkStateActionParams) {
        var stateParams = action.specificParams as BnkStateActionParams;
        group = project.stateGroups[stateParams.ulStateGroupID]!;
        groupItem = group.children.where((s) => s.id == stateParams.ulTargetStateID).firstOrNull;
      } else {
        var switchParams = action.specificParams as BnkSwitchActionParams;
        group = project.switchGroups[switchParams.ulSwitchGroupID]!;
        groupItem = group.children.where((s) => s.id == switchParams.ulSwitchStateID).firstOrNull;
      }
      groupItem ??= group.children.first;
      additionalChildren.add(makeXmlElement(name: "SetItemParam", children: [
        makeXmlElement(name: "Group", attributes: {"Name": group.name, "ID": group.uuid}),
        makeXmlElement(name: "GroupItem", attributes: {"Name": groupItem.name, "ID": groupItem.uuid}),
      ]));
    }
    // pause, resume
    if (action.ulActionType & 0xFF00 == 0x0200) {
      var specificParams = action.specificParams;
      if (specificParams is BnkActiveActionParams && specificParams.byBitVector2 != null) {
        var bIncludePendingResume = specificParams.byBitVector2! & 0x1;
        if (bIncludePendingResume == 0)
          properties.add(WwiseProperty("PauseDelayedResumeAction", "bool", value: "False"));
      }
    }
    if (action.ulActionType & 0xFF00 == 0x0300) {
      var specificParams = action.specificParams;
      if (specificParams is BnkActiveActionParams && specificParams.byBitVector2 != null) {
        var bIsMasterResume = specificParams.byBitVector2! & 0x1;
        if (bIsMasterResume != 0)
          properties.add(WwiseProperty("MasterResume", "bool", value: "True"));
      }
    }
    // seek
    if (action.specificParams is BnkSeekActionParams) {
      var seekParams = action.specificParams as BnkSeekActionParams;
      if (seekParams.bIsSeekRelativeToDuration == 0) {
        properties.add(WwiseProperty("SeekPercent", "Real64", value: seekParams.fSeekValue.toString()));
      } else {
        properties.add(WwiseProperty("SeekTime", "Real64", value: seekParams.fSeekValue.toString()));
        properties.add(WwiseProperty("SeekType", "int16", value: "1"));
      }
      if (seekParams.bSnapToNearestMarker != 0)
        properties.add(WwiseProperty("SeekToMarker", "bool", value: "True"));
    }
    // bypass fx
    if (action.specificParams is BnkBypassFXActionParams) {
      var bypassParams = action.specificParams as BnkBypassFXActionParams;
      var mask = bypassParams.uTargetMask;
      if (mask != -1) {
        if (mask != 0x10) {
          properties.add(WwiseProperty("BypassEffect", "bool", value: "False"));
          for (int i = 0; i < 4; i++) {
            var maskI = 1 << i;
            if (mask & maskI != 0) {
              properties.add(WwiseProperty("BypassEffect$i", "bool", value: "True"));
            }
          }
        }
      }
    }
  }

  XmlElement? makeElementList(List<WwiseElementBase?> elements) {
    var isSingle = (action.ulActionType & _singleFlag) == 0;
    var xmlElements = elements
      .whereType<WwiseElement>()
      .map((e) => makeXmlElement(name: "Element", attributes: {"ID": project.idGen.uuid(), "Global": isSingle ? "false" : "true"}, children: [
            makeXmlElement(name: "ObjectRef", attributes: {"Name": e.name, "ID": e.id, "WorkUnitID": e.wuId}),
      ]))
      .toList();
    if (xmlElements.isEmpty)
      return null;
    return makeXmlElement(name: "ElementList", children: xmlElements);
  }
}
