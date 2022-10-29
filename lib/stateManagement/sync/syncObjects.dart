
import 'dart:async';
import 'dart:convert';

import 'package:xml/xml.dart';

import '../../utils/utils.dart';
import '../Property.dart';
import '../xmlProps/xmlProp.dart';
import 'syncServer.dart';

enum SyncedObjectsType {
  area,
  entity,
  bezier
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

abstract class SyncedObject {
  final String uuid;
  final SyncedObjectsType type;
  final XmlProp prop;
  final List<String> _syncedProps = [];
  bool _isUpdating = false;
  late final StreamSubscription _propDisposeSub;
  late final void Function() syncToClient;

  SyncedObject(this.type, this.prop)
    : uuid = prop.uuid {
    syncToClient = throttle(_syncToClient, 40, trailing: true);
    _addChangeListeners(prop);
    _propDisposeSub = prop.onDisposed.listen(_onPropDispose);
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

  void dispose() {
    _removeChangeListeners(prop);
    _propDisposeSub.cancel();
  }

  void _onPropChange() {
    if (_isUpdating)
      return;
    syncToClient();
  }

  void _onPropDispose(_) {
    endSync();
  }

  XmlElement getPropXml() {
    var xml = prop.toXml();
    xml.childElements
      .toList()
      .where((element) => !_syncedProps.contains(element.name.local))
      .forEach((element) => xml.children.remove(element));
    return xml;
  }

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

  void updateInternal(SyncMessage message);

  void update(SyncMessage message) async {
    _isUpdating = true;
    updateInternal(message);
    // prevent received changes to self to be synced back to client
    await Future.delayed(const Duration(milliseconds: 10));
    _isUpdating = false;
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

class AreaSyncedObject extends SyncedObject {
  static const _typeBoxArea = "app::area::BoxArea";
  static const _typeCylinderArea = "app::area::CylinderArea";
  static const _typeSphereArea = "app::area::SphereArea";
  // syncable props: position, rotation, scale, points, height
  static final _typeBoxAreaHash = crc32(_typeBoxArea);
  // syncable props: position, rotation, scale, radius, height
  static final _typeCylinderAreaHash = crc32(_typeCylinderArea);
  // syncable props: position, radius
  static final _typeSphereAreaHash = crc32(_typeSphereArea);

  AreaSyncedObject(XmlProp prop) : super(SyncedObjectsType.area, prop) {
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

class EntitySyncedObject extends SyncedObject {
  // syncable props: location{ position, rotation?, }, scale?, objId

  EntitySyncedObject(XmlProp prop) : super(SyncedObjectsType.entity, prop) {
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
