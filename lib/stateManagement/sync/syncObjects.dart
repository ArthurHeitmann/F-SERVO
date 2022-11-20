
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../utils/utils.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../nestedNotifier.dart';
import '../events/statusInfo.dart';
import '../xmlProps/xmlProp.dart';
import 'syncServer.dart';

enum SyncedObjectsType {
  list,
  area,
  entity,
  bezier,
  enemyGeneratorNode,
  enemyGeneratorDist,
  camTargetLocation
}

enum SyncUpdateType {
  prop,
  add,
  remove,
  duplicate,
}

Map<String, SyncedObject> syncedObjects = {};
ChangeNotifier syncedObjectsNotifier = ChangeNotifier();
bool _hasAddedListener = false;

void startSyncingObject(SyncedObject obj) {
  if (syncedObjects.containsKey(obj.uuid)) {
    showToast("Already syncing this object");
    return;
  }
  if (!_hasAddedListener) {
    _hasAddedListener = true;
    wsMessageStream.listen(_handleSyncMessage);
    canSync.addListener(() {
      if (canSync.value)
        return;
      for (var obj in syncedObjects.values.toList())
        obj.dispose();
      syncedObjects.clear();
      syncedObjectsNotifier.notifyListeners();
    });
  }

  if (canSync.value) {
    syncedObjects[obj.uuid] = obj;
    syncedObjectsNotifier.notifyListeners();
    obj.startSync();
  }
  else {
    showToast("Can't sync! Connect from Blender first");
  }
}

void _handleSyncMessage(SyncMessage message) {
  switch (message.method) {
    case "update":
      var obj = syncedObjects[message.uuid];
      if (obj != null)
        obj.update(message);
      else
        wsSend(SyncMessage("endSync", message.uuid, {}));
      break;

    case "endSync":
      print("endSync ${message.uuid}");
      syncedObjects[message.uuid]?.dispose();
      syncedObjects.remove(message.uuid);
      syncedObjectsNotifier.notifyListeners();
      break;

    case "reparent":
      var childUuid = message.uuid;
      var srcListUuid = message.args["srcListUuid"];
      var destListUuid = message.args["destListUuid"];
      if (!syncedObjects.containsKey(childUuid) ||
          !syncedObjects.containsKey(srcListUuid) || !syncedObjects.containsKey(destListUuid) ||
          syncedObjects[srcListUuid] is! SyncedList || syncedObjects[destListUuid] is! SyncedList) {
        print("Invalid reparent from $srcListUuid to $destListUuid");
        messageLog.add("Invalid reparent from $srcListUuid to $destListUuid");
        wsSend(SyncMessage("endSync", message.uuid, {}));
        return;
      }
      if (!syncedObjects[childUuid]!.allowReparent) {
        print("Can't reparent ${syncedObjects[childUuid]}");
        messageLog.add("Can't reparent ${syncedObjects[childUuid]}");
        wsSend(SyncMessage("endSync", message.uuid, {}));
        return;
      }

      var srcList = syncedObjects[srcListUuid] as SyncedList;
      var destList = syncedObjects[destListUuid] as SyncedList;
      if (srcList.listType != destList.listType) {
        print("Can't reparent ${syncedObjects[childUuid]} from $srcList to $destList");
        messageLog.add("Can't reparent ${syncedObjects[childUuid]} from $srcList to $destList");
        wsSend(SyncMessage("endSync", message.uuid, {}));
        return;
      }

      var removed = srcList.reparentRemove(message.uuid);
      destList.reparentAdd(removed!);
      break;
    default:
      print("Unhandled sync message: ${jsonEncode(message.toJson())}");
  }
}

abstract class SyncedObject with HasUuid {
  final SyncedObjectsType type;
  final String parentUuid;
  String? nameHint;
  final bool allowReparent;
  bool _isUpdating = false;

  SyncedObject({
    required this.type, required String uuid, required this.parentUuid,
    required this.allowReparent, this.nameHint,
  }) {
    overrideUuid(uuid);
  }

  void _onPropDispose() {
    endSync();
  }

  SyncMessage getStartSyncMsg();

  void startSync() {
    wsSend(getStartSyncMsg());
  }

  void endSync() {
    print("Ending sync for $uuid");
    wsSend(SyncMessage(
      "endSync",
      uuid,
      {}
    ));
    syncedObjects.remove(uuid);
    dispose();
    syncedObjectsNotifier.notifyListeners();
  }

  void updateInternal(SyncMessage message);

  void dispose() {}

  void update(SyncMessage message) async {
    _isUpdating = true;
    updateInternal(message);
    // prevent feedback loop
    await Future.delayed(const Duration(milliseconds: 10));
    _isUpdating = false;
  }
}

abstract class SyncedXmlObject extends SyncedObject {
  final XmlProp prop;
  late final void Function() syncToClient;

  SyncedXmlObject({ required super.type, required this.prop, required super.parentUuid, super.nameHint })
    : super(uuid: prop.uuid, allowReparent: true) {
    _addChangeListeners(prop);
    prop.onDisposed.addListener(_onPropDispose);
    syncToClient = throttle(_syncToClient, 40, trailing: true);
  }

  void _addChangeListeners(XmlProp prop) {
    prop.addListener(_onPropChange);
    for (var child in prop) {
      _addChangeListeners(child);
    }
  }

  void _removeChangeListeners(XmlProp prop) {
    prop.removeListener(_onPropChange);
    for (var child in prop) {
      _removeChangeListeners(child);
    }
  }

  @override
  void dispose() {
    _removeChangeListeners(prop);
    prop.onDisposed.removeListener(_onPropDispose);
    super.dispose();
  }

  @override
  SyncMessage getStartSyncMsg() {
    print("Starting sync for $uuid");
    return SyncMessage(
      "startSync",
      uuid,
      {
        "type": type.index,
        "parentUuid": parentUuid,
        "propXml": prop.toXml().toXmlString(),
        "nameHint": nameHint,
        "allowReparent": allowReparent,
      }
    );
  }

  void _syncToClient() {
    print("Syncing to client: $uuid");
    wsSend(SyncMessage(
      "update",
      uuid,
      {
        "type": SyncUpdateType.prop.index,
        "propXml": prop.toXml().toXmlString()
      }
    ));
  }

  void _onPropChange() {
    if (_isUpdating)
      return;
    syncToClient();
  }

  void updateXmlPropWithStr(XmlProp root, String tagName, XmlElement newRoot) {
    var childProp = root.get(tagName);
    var childXml = newRoot.getElement(tagName);
    if (childProp != null && childXml != null)
      childProp.value.updateWith(childXml.text);
    else if (childProp == null && childXml == null)
      return;
    else if (childProp != null && childXml == null) {
      childProp.removeListener(syncToClient);
      root.remove(childProp);
    } else if (childProp == null && childXml != null) {
      var newProp = XmlProp.fromXml(childXml, parentTags: root.nextParents());
      _addChangeListeners(newProp);
      root.add(newProp);
    }
  }
}

class SyncedList<T extends HasUuid> extends SyncedObject {
  final NestedNotifier<T> list;
  final bool Function(T) filter;
  final SyncedObject Function(T, String parentUuid) makeSyncedObj;
  final T Function(T, String uuid) makeCopy;
  final void Function()? onLengthChange;
  final String listType;
  final bool allowListChange;
  List<String> _syncedUuids = [];
  
  SyncedList({
    required this.list, required super.parentUuid, required this.filter,
    required this.makeSyncedObj, required this.makeCopy, this.onLengthChange,
    required this.listType, required super.allowReparent, required this.allowListChange,
    super.nameHint,
  })
  : super(type: SyncedObjectsType.list, uuid: list.uuid) {
    list.addListener(_onListChange);
    list.onDisposed.addListener(_onPropDispose);
  }

  @override
  SyncMessage getStartSyncMsg() {
    print("Starting sync for $uuid");
    removeExistingSyncedObjects(this);
    return SyncMessage(
      "startSync",
      uuid,
      {
        "type": type.index,
        "parentUuid": parentUuid,
        "listType": listType,
        "nameHint": nameHint,
        "allowReparent": allowReparent,
        "allowListChange": allowListChange,
        "children": list.where(filter).map((e) {
          var syncedObj = makeSyncedObj(e, uuid);
          _syncedUuids.add(syncedObj.uuid);
          syncedObjects[syncedObj.uuid] = syncedObj;
          syncedObjectsNotifier.notifyListeners();
          return syncedObj.getStartSyncMsg().toJson();
        }).toList(),
      }
    );
  }

  @override
  void updateInternal(SyncMessage message) {
    var updateType = SyncUpdateType.values[message.args["type"]];
    switch (updateType) {
      case SyncUpdateType.remove:
        if (!allowListChange) {
          print("Not allowed to remove from list: $uuid");
          endSync();
          return;
        }
        var removedUuid = message.args["uuid"];
        var index = _syncedUuids.indexOf(removedUuid);
        if (index == -1) {
          print("Invalid remove for $uuid");
          wsSend(SyncMessage("endSync", uuid, {}));
          return;
        }
        _syncedUuids.removeAt(index);
        list.removeWhere((e) => e.uuid == removedUuid);
        var removedSyncObj = syncedObjects.remove(removedUuid);
        syncedObjectsNotifier.notifyListeners();
        removedSyncObj?.dispose();
        onLengthChange?.call();
        break;
      case SyncUpdateType.duplicate:
        if (!allowListChange) {
          print("Not allowed to duplicate in list: $uuid");
          endSync();
          return;
        }
        var srcObjUuid = message.args["srcObjUuid"];
        var newObjUuid = message.args["newObjUuid"];
        var srcObj = list.firstWhere((e) => e.uuid == srcObjUuid);
        var newObj = makeCopy(srcObj, newObjUuid);
        newObj.overrideUuid(newObjUuid);
        list.add(newObj);
        _syncedUuids.add(newObj.uuid);
        syncedObjects[newObj.uuid] = makeSyncedObj(newObj, uuid);
        syncedObjectsNotifier.notifyListeners();
        onLengthChange?.call();
        break;
      case SyncUpdateType.add:
        print("Adding from blender is not supported");
        break;
      case SyncUpdateType.prop:
        print("$uuid is a list, not a prop");
        break;
      default:
        print("Unhandled list update type: $updateType");
    }
  }

  void _onListChange() {
    if (_isUpdating)
      return;
    
    var newUuids = list.map((e) => e.uuid).toList();
    var added = newUuids.where((uuid) => !_syncedUuids.contains(uuid)).toList();
    var removed = _syncedUuids.where((uuid) => !newUuids.contains(uuid)).toList();
    _syncedUuids = newUuids;

    for (var uuid in added) {
      var newObj = list.firstWhere((e) => e.uuid == uuid);
      if (!filter(newObj))
        continue;
      var syncObj = makeSyncedObj(newObj, this.uuid);
      syncedObjects[uuid] = syncObj;
      syncedObjectsNotifier.notifyListeners();
      wsSend(SyncMessage(
        "update",
        this.uuid,
        {
          "type": SyncUpdateType.add.index,
          "uuid": uuid,
          "syncObj": syncObj.getStartSyncMsg().toJson(),
        }
      ));
    }

    for (var uuid in removed) {
      var syncObj = syncedObjects.remove(uuid);
      syncedObjectsNotifier.notifyListeners();
      syncObj?.dispose();
      wsSend(SyncMessage(
        "update",
        this.uuid,
        {
          "type": SyncUpdateType.remove.index,
          "uuid": uuid,
        }
      ));
    }
  }

  @override
  void dispose() {
    list.removeListener(_onListChange);
    list.onDisposed.removeListener(_onPropDispose);
    for (var uuid in _syncedUuids) {
      var syncObj = syncedObjects.remove(uuid);
      syncObj?.dispose();
    }
    super.dispose();
  }

  void removeExistingSyncedObjects(SyncedObject parent) {
    // remove existing synced objects
    // they will be re-added on startSync
    for (var child in list) {
      if (syncedObjects.containsKey(child.uuid))
        syncedObjects[child.uuid]!.endSync();
      else if (child is SyncedList)
        removeExistingSyncedObjects(child);
    }
  }

  void reparentAdd(T obj) {
    if (!filter(obj))
      return;
    _isUpdating = true;
    list.add(obj);
    _syncedUuids.add(obj.uuid);
    _isUpdating = false;
    onLengthChange?.call();
  }

  T? reparentRemove(String uuid) {
    if (!_syncedUuids.contains(uuid))
      return null;
    _isUpdating = true;
    var obj = list.firstWhere((e) => e.uuid == uuid);
    list.remove(obj);
    _syncedUuids.remove(uuid);
    _isUpdating = false;
    onLengthChange?.call();
    return obj;
  }
}

class AreaSyncedObject extends SyncedXmlObject {
  static const _typeBoxArea = "app::area::BoxArea";
  static const _typeCylinderArea = "app::area::CylinderArea";
  static const _typeSphereArea = "app::area::SphereArea";
  // syncable props: position, rotation, scale, points, height
  static final _typeBoxAreaHash = crc32(_typeBoxArea);
  // syncable props: position, rotation, scale, radius, height
  static final _typeCylinderAreaHash = crc32(_typeCylinderArea);
  // syncable props: position, radius
  static final _typeSphereAreaHash = crc32(_typeSphereArea);

  AreaSyncedObject(XmlProp prop, { required super.parentUuid, super.nameHint })
    : super(type: SyncedObjectsType.area, prop: prop);

  @override
  void updateInternal(SyncMessage message) {
    print("updating area $uuid");
    var propXmlString = message.args["propXml"] as String;
    var propXml = XmlDocument.parse(propXmlString).rootElement;

    int areaType = int.parse(propXml.getElement("code")!.text);

    updateXmlPropWithStr(prop, "position", propXml);
    if (areaType == _typeBoxAreaHash || areaType == _typeCylinderAreaHash) {
      updateXmlPropWithStr(prop, "rotation", propXml);
      updateXmlPropWithStr(prop, "scale", propXml);
      updateXmlPropWithStr(prop, "height", propXml);
    }
    if (areaType == _typeBoxAreaHash) {
      updateXmlPropWithStr(prop, "points", propXml);
    }
    if (areaType == _typeCylinderAreaHash || areaType == _typeSphereAreaHash) {
      updateXmlPropWithStr(prop, "radius", propXml);
    }

    // TODO handle area type change
  }
}

class EntitySyncedObject extends SyncedXmlObject {
  // syncable props: location{ position, rotation?, }, scale?, objId

  EntitySyncedObject(XmlProp prop, { required super.parentUuid, super.nameHint})
    : super(type: SyncedObjectsType.entity, prop: prop);

  @override
  void updateInternal(SyncMessage message) {
    print("updating entity $uuid");
    var propXmlString = message.args["propXml"] as String;
    var propXml = XmlDocument.parse(propXmlString).rootElement;

    var locationCur = prop.get("location")!;
    var locationNew = propXml.getElement("location")!;
    updateXmlPropWithStr(locationCur, "position", locationNew);
    updateXmlPropWithStr(locationCur, "rotation", locationNew);
    
    updateXmlPropWithStr(prop, "scale", propXml);
    updateXmlPropWithStr(prop, "objId", propXml);
  }
}

class BezierSyncedObject extends SyncedXmlObject {
  // syncable props: attribute, parent?, controls, nodes

  BezierSyncedObject(XmlProp prop, { required super.parentUuid, super.nameHint})
    : super(type: SyncedObjectsType.bezier, prop: prop);

  @override
  void updateInternal(SyncMessage message) {
    print("updating bezier $uuid");
    var propXmlString = message.args["propXml"] as String;
    var propXml = XmlDocument.parse(propXmlString).rootElement;

    var controlsCur = prop.get("controls")!;
    var controlsNew = propXml.getElement("controls")!;
    updateXmlPropChildren(controlsCur, controlsNew, "cp");

    var nodesCur = prop.get("nodes")!;
    var nodesNew = propXml.getElement("nodes")!;
    updateXmlPropChildren(nodesCur, nodesNew, "point");
  }

  void updateXmlPropChildren(XmlProp root, XmlElement newRoot, String childTag) {
    var children = root
      .getAll("value")
      .toList();
    var newChildren = newRoot
      .findElements("value")
      .toList();
    var newChildrenCount = newChildren.length;
    var childrenCount = children.length;
    var minCount = min(childrenCount, newChildrenCount);
    for (var i = 0; i < minCount; i++) {
      var childProp = children[i].get(childTag)!;
      var childXml = newChildren[i].getElement(childTag)!;
      childProp.value.updateWith(childXml.text);
    }
    if (childrenCount > newChildrenCount) {
      for (var i = newChildrenCount; i < childrenCount; i++)
        children[i].dispose();
      for (var i = newChildrenCount; i < childrenCount; i++)
        root.remove(children[i]);
    } else if (childrenCount < newChildrenCount) {
      for (var i = childrenCount; i < newChildrenCount; i++) {
        var newProp = XmlProp.fromXml(newChildren[i], parentTags: root.nextParents());
        _addChangeListeners(newProp);
        root.add(newProp);
      }
    }

    var sizeProp = root.get("size")!;
    (sizeProp.value as NumberProp).value = newChildrenCount;
  }
}

class EMGeneratorNodeSyncedObject extends SyncedXmlObject {
  // syncable props: point, radius

  EMGeneratorNodeSyncedObject(XmlProp prop, { required super.parentUuid, super.nameHint })
    : super(prop: prop, type: SyncedObjectsType.enemyGeneratorNode);
  
  @override
  void updateInternal(SyncMessage message) {
    print("updating enemy generator node $uuid");
    var propXmlString = message.args["propXml"] as String;
    var propXml = XmlDocument.parse(propXmlString).rootElement;

    updateXmlPropWithStr(prop, "point", propXml);
    updateXmlPropWithStr(prop, "radius", propXml);
  }
}

class EMGeneratorDistSyncedObject extends SyncedXmlObject {
  // syncable props: dist { position, rotation?, areaDist?, resetDist?, searchDist?, guardSDist?, guardLDist?, escapeDist? }

  EMGeneratorDistSyncedObject(XmlProp prop, { required super.parentUuid })
    : super(prop: prop, type: SyncedObjectsType.enemyGeneratorDist, nameHint: "dist");
  
  @override
  void updateInternal(SyncMessage message) {
    print("updating enemy generator dist $uuid");
    var propXmlString = message.args["propXml"] as String;
    var propXml = XmlDocument.parse(propXmlString).rootElement;

    var distCur = prop;
    var distNew = propXml;
    updateXmlPropWithStr(distCur, "position", distNew);
    updateXmlPropWithStr(distCur, "rotation", distNew);
    updateXmlPropWithStr(distCur, "areaDist", distNew);
    updateXmlPropWithStr(distCur, "resetDist", distNew);
    updateXmlPropWithStr(distCur, "searchDist", distNew);
    updateXmlPropWithStr(distCur, "guardSDist", distNew);
    updateXmlPropWithStr(distCur, "guardLDist", distNew);
    updateXmlPropWithStr(distCur, "escapeDist", distNew);
  }
}

class CameraTargetLocationSyncedObject extends SyncedXmlObject {
  // syncable props: position?, rotation?

  CameraTargetLocationSyncedObject(XmlProp prop, { required super.parentUuid })
    : super(prop: prop, type: SyncedObjectsType.camTargetLocation, nameHint: "dist");
  
  @override
  void updateInternal(SyncMessage message) {
    print("updating camera target location $uuid");
    var propXmlString = message.args["propXml"] as String;
    var propXml = XmlDocument.parse(propXmlString).rootElement;

    updateXmlPropWithStr(prop, "position", propXml);
    updateXmlPropWithStr(prop, "rotation", propXml);
  }
}
