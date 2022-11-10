
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:xml/xml.dart';

import '../../utils/utils.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../nestedNotifier.dart';
import '../xmlProps/xmlProp.dart';
import 'syncServer.dart';

enum SyncedObjectsType {
  list,
  area,
  entity,
  bezier,
}

Map<String, SyncedObject> _syncedObjects = {};
bool _hasAddedListener = false;

void startSyncingObject(SyncedObject obj) {
  if (_syncedObjects.containsKey(obj.uuid))
    return;
  if (!_hasAddedListener) {
    _hasAddedListener = true;
    wsMessageStream.listen(_handleSyncMessage);
    canSync.addListener(() {
      if (!canSync.value)
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
      if (obj != null) {
        obj.update(message);
      } else {
        wsSend(SyncMessage(
          "endSync",
          message.uuid,
          {}
        ));
      }
      break;

    case "endSync":
      print("endSync ${message.uuid}");
      _syncedObjects[message.uuid]?.dispose();
      _syncedObjects.remove(message.uuid);
      break;

    case "duplicate":
    default:
      print("Unhandled sync message: ${jsonEncode(message.toJson())}");
  }
}

abstract class SyncedObject with HasUuid {
  final SyncedObjectsType type;
  final String parentUuid;
  bool _isUpdating = false;

  SyncedObject({ required this.type, required String uuid, required this.parentUuid }) {
    overrideUuid(uuid);
  }

  void _onPropDispose(_) {
    endSync();
  }

  void startSync([String? nameHint]);

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
    // prevent received changes to self to be synced back to client
    await Future.delayed(const Duration(milliseconds: 10));
    _isUpdating = false;
  }
}

abstract class SyncedXmlObject extends SyncedObject {
  final XmlProp prop;
  final List<String> _syncedProps = [];
  late final StreamSubscription _propDisposeSub;
  late final void Function() syncToClient;

  SyncedXmlObject({ required super.type, required this.prop, required super.parentUuid }) : super(uuid: prop.uuid) {
    _addChangeListeners(prop);
    _propDisposeSub = prop.onDisposed.listen(_onPropDispose);
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
    _propDisposeSub.cancel();
    super.dispose();
  }

  @override
  void startSync([String? nameHint]) {
    print("Starting sync for $uuid");
    wsSend(SyncMessage(
      "startSync",
      uuid,
      {
        "type": SyncedObjectsType.values.indexOf(type),
        "propXml": getPropXml().toXmlString(),
        "nameHint": nameHint
      }
    ));
  }

  void _syncToClient() {
    print("Syncing to client: $uuid");
    wsSend(SyncMessage(
      "update",
      uuid,
      {
        "propXml": getPropXml().toXmlString()
      }
    ));
  }

  void _onPropChange() {
    if (_isUpdating)
      return;
    syncToClient();
  }

  XmlElement getPropXml() {
    var xml = prop.toXml();
    xml.childElements
      .toList()
      .where((element) => !_syncedProps.contains(element.name.local))
      .forEach((element) => xml.children.remove(element));
    return xml;
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
  List<String> _syncedUuids = [];
  
  SyncedList({
    required this.list, required super.parentUuid, required this.filter,
    required this.makeSyncedObj, required this.makeCopy
  })
  : super(type: SyncedObjectsType.list, uuid: list.uuid) {
    list.addListener(_onListChange);
    list.onDisposed.listen(_onPropDispose);
    _syncedUuids = list.map((e) => e.uuid).toList();
  }

  void _onListChange() {
    var newUuids = list.map((e) => e.uuid).toList();
    var added = newUuids.where((uuid) => !_syncedUuids.contains(uuid)).toList();
    var removed = _syncedUuids.where((uuid) => !newUuids.contains(uuid)).toList();
    _syncedUuids = newUuids;

    for (var uuid in added) {
      var obj = makeSyncedObj(list.firstWhere((e) => e.uuid == uuid), uuid);
      obj.startSync();
      _syncedObjects[uuid] = obj;
    }

    for (var uuid in removed) {
      _syncedObjects[uuid]?.endSync();
    }
  }

  @override
  void startSync([String? nameHint]) {
    print("Starting sync for $uuid");
    wsSend(SyncMessage(
      "startSync",
      uuid,
      {
        "type": SyncedObjectsType.values.indexOf(type),
        "nameHint": nameHint
      }
    ));

    for (var obj in list) {
      var syncedObj = makeSyncedObj(obj, uuid);
      syncedObj.startSync();
      _syncedObjects[obj.uuid] = syncedObj;
    }
  }

  @override
  void updateInternal(SyncMessage message) {
    var duplicatedObjects = message.args["duplicatedObjects"] as List;
    var removedUuids = message.args["removedUuids"] as List;

    for (var dupedObj in duplicatedObjects) {
      var prevUuid = dupedObj["prevUuid"] as String;
      var newUuid = dupedObj["newUuid"] as String;
      var prevObj = list.firstWhere((e) => e.uuid == prevUuid);
      var newObj = makeCopy(prevObj, newUuid);
      list.add(newObj);
      _syncedObjects[newUuid] = makeSyncedObj(newObj, uuid);
    }

    for (var uuid in removedUuids) {
      _syncedObjects[uuid]?.endSync();
    }
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

  AreaSyncedObject(XmlProp prop, {required super.parentUuid}) : super(type: SyncedObjectsType.area, prop: prop) {
    _updateSyncedProps();
  }

  void _updateSyncedProps() {
    _syncedProps.clear();
    var areaType = (prop.get("code")!.value as HexProp).strVal;
    switch (areaType) {
      case _typeBoxArea:
        _syncedProps.addAll(["code", "position", "rotation", "scale", "points", "height"]);
        break;
      case _typeCylinderArea:
        _syncedProps.addAll(["code", "position", "rotation", "scale", "radius", "height"]);
        break;
      case _typeSphereArea:
        _syncedProps.addAll(["code", "position", "radius"]);
        break;
    }
  }

  @override
  void updateInternal(SyncMessage message) {
    print("updating area $uuid");
    var propXmlString = message.args["propXml"] as String;
    var propXml = XmlDocument.parse(propXmlString).rootElement;

    int areaType = int.parse(propXml.getElement("code")!.text);
    _updateSyncedProps();

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

  EntitySyncedObject(XmlProp prop, {required super.parentUuid}) : super(type: SyncedObjectsType.entity, prop: prop) {
    _syncedProps.addAll(["location", "scale", "objId"]);
  }

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

  BezierSyncedObject(XmlProp prop, {required super.parentUuid}) : super(type: SyncedObjectsType.bezier, prop: prop) {
    _syncedProps.addAll(["attribute", "parent", "controls", "nodes"]);
  }

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
