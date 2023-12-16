
import 'package:flutter/material.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../../utils/utils.dart';
import '../../Property.dart';
import '../../undoable.dart';
import '../HierarchyEntryTypes.dart';

class BnkHierarchyEntry extends GenericFileHierarchyEntry {
  final String extractedPath;

  BnkHierarchyEntry(StringProp name, String path, this.extractedPath)
      : super(name, path, true, false);

  @override
  HierarchyEntry clone() {
    return BnkHierarchyEntry(name.takeSnapshot() as StringProp, path, extractedPath);
  }
}

class BnkSubCategoryParentHierarchyEntry extends HierarchyEntry {
  BnkSubCategoryParentHierarchyEntry(String name, { bool isCollapsed = false })
      : super(StringProp(name, fileId: null), false, true, false) {
    this.isCollapsed.value = isCollapsed;
  }

  @override
  Undoable takeSnapshot() {
    var entry = BnkSubCategoryParentHierarchyEntry(name.value);
    entry.overrideUuid(uuid);
    entry.isSelected.value = isSelected.value;
    entry.isCollapsed.value = isCollapsed.value;
    entry.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return entry;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as HierarchyEntry;
    isSelected.value = entry.isSelected.value;
    isCollapsed.value = entry.isCollapsed.value;
    updateOrReplaceWith(entry.children.toList(), (entry) => entry.takeSnapshot() as HierarchyEntry);
  }
}

class BnkHircHierarchyEntry extends GenericFileHierarchyEntry {
  static const nonCollapsibleTypes = { "WEM", "Group Entry", "Game Parameter", "State" };
  static const openableTypes = { "MusicPlaylist", "WEM" };
  final int id;
  final String type;
  List<int> parentIds;
  List<int> childIds;
  List<(bool, List<String>)>? properties;
  int usages = 0;

  BnkHircHierarchyEntry(StringProp name, String path, this.id, this.type, [this.parentIds = const [], this.childIds = const [], this.properties])
      : super(name, path, !nonCollapsibleTypes.contains(type), openableTypes.contains(type)){
    isCollapsed.value = true;
  }

  @override
  HierarchyEntry clone() {
    return BnkHircHierarchyEntry(name.takeSnapshot() as StringProp, path, id, type, parentIds, childIds, properties);
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    if (wemIdsToNames.containsKey(id))
      return [
        HierarchyEntryAction(
          name: "Copy Name",
          icon: Icons.copy,
          action: () => copyToClipboard(wemIdsToNames[id]!),
        ),
        ...super.getContextMenuActions(),
      ];
    return super.getContextMenuActions();
  }

  static List<(bool, List<String>)> makePropsFromParams(BnkPropValue propValues, [BnkPropRangedValue? rangedPropValues]) {
    const msPropNames = { "delaytime", "transitiontime" };
    List<(bool, List<String>)> props = [];
    if (propValues.cProps > 0) {
      props.addAll([
        (false, ["Prop ID", "Prop Value"]),
        for (var i = 0; i < propValues.cProps; i++)
          (true, [
            BnkPropIds[propValues.pID[i]] ?? wemIdsToNames[propValues.pID[i]] ?? propValues.pID[i].toString(),
            msPropNames.contains(BnkPropIds[propValues.pID[i]]?.toLowerCase())
                ? (propValues.values[i].number / 1000).toString()
                : wemIdsToNames[propValues.values[i].i] ?? propValues.values[i].toString()
          ])
      ]);
    }
    if (rangedPropValues != null && rangedPropValues.cProps > 0) {
      var ids = rangedPropValues.pID
          .map((id) => BnkPropIds[id] ?? wemIdsToNames[id] ?? id.toString())
          .toList();
      var values = rangedPropValues.minMax
          .map((value) => "${value.$1} - ${value.$2}")
          .toList();
      props.addAll([
        (false, ["Ranged Prop ID", "Ranged Prop Min - Max"]),
        for (var i = 0; i < ids.length; i++)
          (true, [ids.elementAt(i), values.elementAt(i)]),
      ]);
    }

    return props;
  }
}
