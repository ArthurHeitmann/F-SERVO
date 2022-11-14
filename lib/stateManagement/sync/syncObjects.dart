
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:xml/xml.dart';

import '../../utils/utils.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../nestedNotifier.dart';
import '../statusInfo.dart';
import '../xmlProps/xmlProp.dart';
import 'syncServer.dart';

enum SyncedObjectsType {
  list,
  area,
  entity,
  bezier,
}

enum SyncUpdateType {
  prop,
  add,
  remove,
  duplicate,
}

Map<String, SyncedObject> _syncedObjects = {};
bool _hasAddedListener = false;

void startSyncingObject(SyncedObject obj) {
  if (_syncedObjects.containsKey(obj.uuid)) {
    showToast("Already syncing this object");
    return;
  }
  if (!_hasAddedListener) {
    _hasAddedListener = true;
    wsMessageStream.listen(_handleSyncMessage);
    canSync.addListener(() {
      if (canSync.value)
        return;
      for (var obj in _syncedObjects.values)
        obj.dispose();
      _syncedObjects.clear();
    });
  }

  if (canSync.value) {
    _syncedObjects[obj.uuid] = obj;
    obj.startSync();
  }
  else {
    showToast("Can't sync! Connect from Blender first");
  }
}

void _handleSyncMessage(SyncMessage message) {
  switch (message.method) {
    case "update":
      var obj = _syncedObjects[message.uuid];
      if (obj != null)
        obj.update(message);
      else
        wsSend(SyncMessage("endSync", message.uuid, {}));
      break;

    case "endSync":
      print("endSync ${message.uuid}");
      _syncedObjects[message.uuid]?.dispose();
      _syncedObjects.remove(message.uuid);
      break;

    case "reparent":
      var childUuid = message.uuid;
      var srcListUuid = message.args["srcListUuid"];
      var destListUuid = message.args["destListUuid"];
      if (!_syncedObjects.containsKey(childUuid) ||
          !_syncedObjects.containsKey(srcListUuid) || !_syncedObjects.containsKey(destListUuid) ||
          _syncedObjects[srcListUuid] is! SyncedList || _syncedObjects[destListUuid] is! SyncedList) {
        print("Invalid reparent from $srcListUuid to $destListUuid");
        messageLog.add("Invalid reparent from $srcListUuid to $destListUuid");
        wsSend(SyncMessage("endSync", message.uuid, {}));
        return;
      }
      if (!_syncedObjects[childUuid]!.allowReparent) {
        print("Can't reparent ${_syncedObjects[childUuid]}");
        messageLog.add("Can't reparent ${_syncedObjects[childUuid]}");
        wsSend(SyncMessage("endSync", message.uuid, {}));
        return;
      }

      var srcList = _syncedObjects[srcListUuid] as SyncedList;
      var destList = _syncedObjects[destListUuid] as SyncedList;
      if (srcList.listType != destList.listType) {
        print("Can't reparent ${_syncedObjects[childUuid]} from $srcList to $destList");
        messageLog.add("Can't reparent ${_syncedObjects[childUuid]} from $srcList to $destList");
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

  SyncedObject({ required this.type, required String uuid, required this.parentUuid, required this.allowReparent }) {
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
    _syncedObjects.remove(uuid);
    dispose();
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

  SyncedXmlObject({ required super.type, required this.prop, required super.parentUuid })
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
    prop.removeListener(syncToClient);
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
  final String listType;
  final bool allowListChange;
  List<String> _syncedUuids = [];
  
  SyncedList({
    required this.list, required super.parentUuid, required this.filter,
    required this.makeSyncedObj, required this.makeCopy, required this.listType,
    required super.allowReparent, required this.allowListChange
  })
  : super(type: SyncedObjectsType.list, uuid: list.uuid) {
    list.addListener(_onListChange);
    list.onDisposed.addListener(_onPropDispose);
    _syncedUuids = list
      .where(filter)
      .map((e) => e.uuid).toList();
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
        "allowReparent": allowReparent,
        "allowListChange": allowListChange,
        "children": list.where(filter).map((e) {
          var syncedObj = makeSyncedObj(e, uuid);
          _syncedObjects[e.uuid] = syncedObj;
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
        var removedSyncObj = _syncedObjects.remove(removedUuid);
        removedSyncObj?.dispose();
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
        _syncedObjects[newObj.uuid] = makeSyncedObj(newObj, uuid);
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
      _syncedObjects[uuid] = syncObj;
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
      var syncObj = _syncedObjects.remove(uuid);
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
    super.dispose();
  }

  void removeExistingSyncedObjects(SyncedObject parent) {
    // remove existing synced objects
    // they will be re-added on startSync
    for (var child in list) {
      if (_syncedObjects.containsKey(child.uuid))
        _syncedObjects[child.uuid]!.endSync();
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
  }

  T? reparentRemove(String uuid) {
    var index = _syncedUuids.indexOf(uuid);
    if (index == -1)
      return null;
    _isUpdating = true;
    var removed = list.removeAt(index);
    _syncedUuids.removeAt(index);
    _isUpdating = false;
    return removed;
  }
}

class SyncedXmlList extends SyncedList<XmlProp> {
  SyncedXmlList({
    required super.list, required super.parentUuid, required super.listType,
    required super.allowReparent, required super.allowListChange
  }) : super(
    filter: (prop) => prop.tagName == "value",
    makeSyncedObj: (prop, parentUuid) => EntitySyncedObject(prop, parentUuid: parentUuid),
    makeCopy: (prop, uuid) {
      var newProp = XmlProp.fromXml(prop.toXml(), parentTags: prop.parentTags, file: prop.file);
      var idProp = newProp.get("id");
      if (idProp != null)
        (idProp.value as HexProp).value = randomId();
      return newProp;
    }
  );
}

class SyncedEntityList extends SyncedXmlList {
  SyncedEntityList({ required super.list, required super.parentUuid })
    : super(listType: "entity", allowReparent: false, allowListChange: true);
}

class SyncedAreaList extends SyncedXmlList {
  SyncedAreaList({ required super.list, required super.parentUuid })
    : super(listType: "area", allowReparent: false, allowListChange: true);
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

  AreaSyncedObject(XmlProp prop, {required super.parentUuid}) : super(type: SyncedObjectsType.area, prop: prop);

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

  EntitySyncedObject(XmlProp prop, {required super.parentUuid}) : super(type: SyncedObjectsType.entity, prop: prop);

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

  BezierSyncedObject(XmlProp prop, {required super.parentUuid}) : super(type: SyncedObjectsType.bezier, prop: prop);

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
      .map((e) => e.get(childTag)!)
      .toList();
    var newChildren = newRoot
      .findElements("value")
      .map((e) => e.getElement(childTag)!)
      .toList();
    var newChildrenCount = newChildren.length;
    var childrenCount = children.length;
    var minCount = min(childrenCount, newChildrenCount);
    for (var i = 0; i < minCount; i++) {
      var childProp = children[i];
      var childXml = newChildren[i];
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
  }
}
