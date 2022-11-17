


import '../../utils/utils.dart';
import '../Property.dart';
import '../xmlProps/xmlActionProp.dart';
import '../xmlProps/xmlProp.dart';
import 'syncObjects.dart';

class SyncedXmlList extends SyncedList<XmlProp> {
  SyncedXmlList({
    required super.list, required super.parentUuid, required super.listType,
    required super.makeSyncedObj,
    required super.allowReparent, required super.allowListChange, super.nameHint
  }) : super(
    filter: (prop) => prop.tagName == "value",
    makeCopy: (prop, uuid) {
      var newProp = XmlProp.fromXml(prop.toXml(), parentTags: prop.parentTags, file: prop.file);
      newProp.overrideUuid(uuid);
      var idProp = newProp.get("id");
      if (idProp != null)
        (idProp.value as HexProp).value = randomId();
      return newProp;
    },
    onLengthChange: () {
      var valuesLength = list.where((e) => e.tagName == "value").length;
      var sizeProp = list.firstWhere((e) => e.tagName == "size");
      (sizeProp.value as NumberProp).value = valuesLength;
    }
  );
}

class SyncedEntityList extends SyncedXmlList {
  SyncedEntityList({ required super.list, required super.parentUuid }) : super(
    listType: "entity", nameHint: "layout",
    allowReparent: false, allowListChange: true,
    makeSyncedObj: (prop, parentUuid) => EntitySyncedObject(prop, parentUuid: parentUuid),
);
}

class SyncedAreaList extends SyncedXmlList {
  SyncedAreaList({ required super.list, required super.parentUuid, String? nameHint }) : super(
    listType: "area", nameHint: nameHint ?? "area",
    allowReparent: false, allowListChange: true,
    makeSyncedObj: (prop, parentUuid) => AreaSyncedObject(prop, parentUuid: parentUuid),
  );
}

class SyncedEMGeneratorNodeList extends SyncedXmlList {
  SyncedEMGeneratorNodeList({ required super.list, required super.parentUuid }) : super(
    listType: "node", nameHint: "nodes",
    allowReparent: false, allowListChange: true,
    makeSyncedObj: (prop, parentUuid) => EMGeneratorNodeSyncedObject(prop, parentUuid: parentUuid),
  );
}

class SyncedAction extends SyncedList<XmlProp> {
  SyncedAction({
    required XmlActionProp action, required super.parentUuid,
    required super.makeSyncedObj, required super.filter,
  }) : super(
    list: action,
    nameHint: action.name.toString(),
    makeCopy: (prop, uuid) => throw UnimplementedError(),
    listType: "action",
    allowReparent: true,
    allowListChange: false
  );

  static XmlProp makePropCopy(XmlProp prop, String newUuid) {
    var newProp = XmlProp.fromXml(prop.toXml(), parentTags: prop.parentTags, file: prop.file);
    newProp.overrideUuid(newUuid);
    var idProp = newProp.get("id")!;
    (idProp.value as HexProp).value = randomId();
    return newProp;
  }
}

class SyncedEntityAction extends SyncedAction {
  SyncedEntityAction({ required super.action, required super.parentUuid }) : super(
    filter: (prop) => prop.tagName == "layouts" || isAreaProp(prop),
    makeSyncedObj: (prop, parentUuid) {
      if (prop.tagName == "layouts") {
        return SyncedEntityList(
          list: prop.get("normal")?.get("layouts")! ?? prop.get("layouts")!,
          parentUuid: parentUuid,
        );
      } else {
        return SyncedAreaList(
          list: prop,
          parentUuid: parentUuid,
          nameHint: prop.tagName,
        );
      }
    },
  );

  static bool isEntityAction(XmlProp prop) {
    return prop is XmlActionProp && { "EntityLayoutAction", "EntityLayoutArea", "EnemySetAction", "EnemySetArea" }.contains(prop.code.strVal);
  }

  static XmlProp makePropCopy(XmlProp prop, String newUuid) {
    var newProp = SyncedAction.makePropCopy(prop, newUuid);
    var rootLayouts = newProp.get("layouts")!;
    var layoutsList = rootLayouts.get("normal") != null ? rootLayouts : [rootLayouts];
    for (var layout in layoutsList) {
      var idProp = layout.get("id");
      if (idProp != null)
        (idProp.value as HexProp).value = randomId();
      for (var value in layout.get("layouts")!.getAll("value")) {
        var idProp = value.get("id")!;
        (idProp.value as HexProp).value = randomId();
      }
    }
    return newProp;
  }
}

class SyncedBezierAction extends SyncedAction {
  SyncedBezierAction({ required super.action, required super.parentUuid }) : super(
    filter: (prop) => const { "curve", "bezier_", "route", "upRoute_" }.contains(prop.tagName) || isAreaProp(prop),
    makeSyncedObj: (prop, parentUuid) {
      if (isAreaProp(prop)) {
        return SyncedAreaList(
          list: prop,
          parentUuid: parentUuid,
          nameHint: prop.tagName,
        );
      }
      return BezierSyncedObject(
        prop,
        parentUuid: parentUuid,
        nameHint: prop.tagName,
      );
    },
  );

  static bool isBezierAction(XmlProp prop) {
    return prop is XmlActionProp && { "BezierCurveAction", "ShootingEnemyCurveAction", "AirBezierAction" }.contains(prop.code.strVal);
  }
}

class SyncedEMGeneratorAction extends SyncedAction {
  SyncedEMGeneratorAction({ required super.action, required super.parentUuid }) : super(
    filter: (prop) => { "points", "dist" }.contains(prop.tagName) || isAreaProp(prop),
    makeSyncedObj: (prop, parentUuid) {
      if (isAreaProp(prop)) {
        return SyncedAreaList(
          list: prop,
          parentUuid: parentUuid,
          nameHint: prop.tagName,
        );
      }
      if (prop.tagName == "points") {
        return SyncedEMGeneratorNodeList(
          list: prop,
          parentUuid: parentUuid,
        );
      }
      if (prop.tagName == "dist") {
        return EMGeneratorDistSyncedObject(
          prop,
          parentUuid: parentUuid,
        );
      }
      throw UnimplementedError();
    },
  );

  static bool isEMGeneratorAction(XmlProp prop) {
    return prop is XmlActionProp && prop.any((prop) => prop.tagName == "EnemyGenerator");
  }
}

class SyncedAreasAction extends SyncedAction {
  SyncedAreasAction({ required super.action, required super.parentUuid }) : super(
    filter: isAreaProp,
    makeSyncedObj: (prop, parentUuid) => SyncedXmlList(
      list: prop,
      parentUuid: parentUuid,
      listType: "area",
      nameHint: prop.tagName,
      makeSyncedObj: (prop, parentUuid) => AreaSyncedObject(prop, parentUuid: parentUuid),
      allowReparent: false,
      allowListChange: true,
    ),
  );

  static bool isAreasAction(XmlProp prop) {
    return prop is XmlActionProp && prop.any(isAreaProp);
  }
}

class SyncedXmlFile extends SyncedList<XmlProp> {
  SyncedXmlFile({
    required super.list, required super.parentUuid, super.nameHint,
  }) : super(
    filter: (prop) => prop is XmlActionProp && (
      SyncedEntityAction.isEntityAction(prop) ||
      SyncedBezierAction.isBezierAction(prop) ||
      SyncedAreasAction.isAreasAction(prop)
    ),
    makeSyncedObj: (prop, parentUuid) {
      XmlActionProp action;
      if (prop is XmlActionProp)
        action = prop;
      else
        action = XmlActionProp(prop);
      if (SyncedEntityAction.isEntityAction(prop))
        return SyncedEntityAction(action: action, parentUuid: parentUuid);
      else if (SyncedBezierAction.isBezierAction(prop))
        return SyncedBezierAction(action: action, parentUuid: parentUuid);
      else if (SyncedAreasAction.isAreasAction(prop))
        return SyncedAreasAction(action: action, parentUuid: parentUuid);
      else
        throw UnimplementedError();
    },
    makeCopy: (prop, newUuid) {
      if (SyncedEntityAction.isEntityAction(prop))
        return SyncedEntityAction.makePropCopy(prop, newUuid);
      return SyncedAction.makePropCopy(prop, newUuid);
    },
    onLengthChange: () {
      var valuesLength = list.where((e) => e.tagName == "value").length;
      var sizeProp = list.firstWhere((e) => e.tagName == "size");
      (sizeProp.value as NumberProp).value = valuesLength;
    },
    listType: "file",
    allowReparent: false,
    allowListChange: true,
  );
}
