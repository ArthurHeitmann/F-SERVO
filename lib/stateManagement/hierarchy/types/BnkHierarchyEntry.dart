
import 'package:flutter/material.dart';

import '../../../background/wemFilesIndexer.dart';
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../../utils/utils.dart';
import '../../Property.dart';
import '../../openFiles/types/WemFileData.dart';
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

  Future<void> generateHierarchy(BnkHircChunk hircChunk) async {
    Map<int, BnkHircHierarchyEntry> hircEntries = {};
    Map<int, BnkHircHierarchyEntry> actionEntries = {};
    List<BnkHircHierarchyEntry> eventEntries = [];
    Map<String, Set<String>> usedSwitchGroups = {};
    Map<String, Set<String>> usedStateGroups = {};
    Map<String, Set<String>> usedGameParameters = {};
    void addGroupUsage(Map<String, Set<String>> map, String groupName, String entryName) {
      if (!map.containsKey(groupName))
        map[groupName] = {};
      map[groupName]!.add(entryName);
    }
    for (var hirc in hircChunk.chunks) {
      var uidNameLookup = wemIdsToNames[hirc.uid];
      var uidNameStr = uidNameLookup ?? "";
      String entryPath;
      if (hirc is BnkMusicPlaylist)
        entryPath = "$path#p=${hirc.uid}";
      else
        entryPath = path;
      List<int> parentId = [];
      List<int> childIds = [];
      List<(bool, List<String>)> props = [];
      if (hirc is BnkHircChunkWithBaseParamsGetter) {
        var hircChunk = hirc as BnkHircChunkWithBaseParamsGetter;
        var baseParams = hircChunk.getBaseParams();
        parentId.add(baseParams.directParentID);
        if (parentId.last == 0)
          parentId.removeLast();
        for (var stateGroup in baseParams.states.stateGroup) {
          var stateGroupId = randomId();
          var groupName = wemIdsToNames[stateGroup.ulStateGroupID] ?? stateGroup.ulStateGroupID.toString();
          var stateGroupEntry = BnkHircHierarchyEntry("StateGroup $groupName", "", "StateGroup", id: stateGroupId, parentIds: [hirc.uid], entryName: wemIdsToNames[stateGroup.ulStateGroupID]);
          hircEntries[stateGroupId] = stateGroupEntry;
          for (var state in stateGroup.state) {
            var stateName = wemIdsToNames[state.ulStateID] ?? state.ulStateID.toString();
            addGroupUsage(usedStateGroups, groupName, stateName);
            var stateId = randomId();
            var childId = state.ulStateInstanceID;
            if (hircEntries.containsKey(childId)) {
              var childState = hircEntries[childId]!;
              childState.name.value += " = $stateName";
              childState.parentIds.add(stateGroupId);
            }
            else {
              var stateEntry = BnkHircHierarchyEntry("State $stateName", "", "State", id: stateId, parentIds: [stateGroupId], childIds: [childId], entryName: wemIdsToNames[state.ulStateID]);
              hircEntries[stateId] = stateEntry;
            }
          }
        }
        Future<void> addWemChild(int srcId) async {
          var srcName = wemIdsToNames.containsKey(srcId) ? "${wemIdsToNames[srcId]!} ($srcId)" : srcId.toString();
          var wemPath = await wemFilesLookup.lookupWithAdditionalDir(srcId, extractedPath);
          if (hircEntries.containsKey(srcId)) {
            var child = hircEntries[srcId]!;
            child.parentIds.add(hirc.uid);
          }
          else {
            var srcEntry = BnkHircHierarchyEntry(srcName, wemPath ?? "", "WEM", id: srcId, parentIds: [hirc.uid]);
            srcEntry.optionalFileInfo = OptionalWemData(path, WemSource.bnk);
            hircEntries[srcId] = srcEntry;
          }
        }
        if (hircChunk is BnkMusicTrack) {
          for (var src in hircChunk.sources) {
            var srcId = src.fileID;
            await addWemChild(srcId);
          }
        }
        if (hircChunk is BnkSound) {
          var srcId = hircChunk.bankData.mediaInformation.uFileID;
          await addWemChild(srcId);
        }
        if (hircChunk is BnkMusicSwitch) {
          var groupName = wemIdsToNames[hircChunk.ulGroupID] ?? hircChunk.ulGroupID.toString();
            var defaultValue = wemIdsToNames[hircChunk.ulDefaultSwitch] ?? hircChunk.ulDefaultSwitch.toString();
            addGroupUsage(usedSwitchGroups, groupName, defaultValue);
            props.addAll([
              (false, ["Switch Group", "Default Switch"]),
              (true, [groupName, defaultValue]),
            ]);
            for (var switchAssoc in hircChunk.pAssocs) {
              var switchAssocName = wemIdsToNames[switchAssoc.switchID] ?? switchAssoc.switchID.toString();
              addGroupUsage(usedSwitchGroups, groupName, switchAssocName);
              var switchId = randomId();
              var childNodeId = switchAssoc.nodeID;
              var switchAssocEntry = BnkHircHierarchyEntry(switchAssocName, "", "SwitchAssoc", id: switchId, parentIds: [hirc.uid], childIds: [childNodeId], entryName: wemIdsToNames[switchAssoc.switchID]);
              hircEntries[switchId] = switchAssocEntry;
              var nodeChild = hircEntries[childNodeId];
              if (nodeChild != null) {
                nodeChild.parentIds.add(switchId);
              }
              else {
                var nodeEntry = BnkHircHierarchyEntry("Node $switchAssocName", "", "Node", id: childNodeId, parentIds: [switchId], entryName: wemIdsToNames[switchAssoc.switchID]);
                hircEntries[childNodeId] = nodeEntry;
              }
            }
        }
        BnkAkMeterInfo? meterInfo;
        if (hircChunk is BnkMusicSegment)
          meterInfo = hircChunk.musicParams.meterInfo;
        else if (hircChunk is BnkMusicPlaylist)
          meterInfo = hircChunk.musicTransParams.musicParams.meterInfo;
        else if (hircChunk is BnkMusicSwitch)
          meterInfo = hircChunk.musicTransParams.musicParams.meterInfo;
        if (meterInfo != null) {
          const defaultTempo = 120.0;
          const defaultBeatValue = 4;
          const defaultNumBeatsPerBar = 4;
          const defaultGridPeriod = 1000.0;
          const defaultGridOffset = 0.0;
          if (meterInfo.fTempo != defaultTempo || meterInfo.uBeatValue != defaultBeatValue || meterInfo.uNumBeatsPerBar != defaultNumBeatsPerBar || meterInfo.fGridPeriod != defaultGridPeriod || meterInfo.fGridOffset != defaultGridOffset) {
            props.addAll([
              (false, ["Tempo", "Time Signature", "Grid Period", "Grid Offset"]),
              (true, [
                "${meterInfo.fTempo}",
                "${meterInfo.uNumBeatsPerBar} / ${meterInfo.uBeatValue}",
                "${meterInfo.fGridPeriod}",
                "${meterInfo.fGridOffset}"
              ]),
            ]);
          }
        }
        props.addAll(BnkHircHierarchyEntry.makePropsFromParams(baseParams.iniParams.propValues, baseParams.iniParams.rangedPropValues));
      }
      else if (hirc is BnkAction) {
        childIds = [hirc.initialParams.idExt];
        if (hirc.initialParams.idExt != 0 && !hircEntries.containsKey(hirc.initialParams.idExt)) {
          var targetName = wemIdsToNames[hirc.initialParams.idExt] ?? "Target ${hirc.initialParams.idExt.toString()}";
          var targetId = randomId();
          var child = BnkHircHierarchyEntry(targetName, "", "ActionTarget", id: targetId, parentIds: [hirc.uid], entryName: wemIdsToNames[hirc.initialParams.idExt]);
          hircEntries[targetId] = child;
        }
        if (uidNameStr.isEmpty && actionTypes.containsKey(hirc.ulActionType))
          uidNameStr = actionTypes[hirc.ulActionType]!;
        props.addAll(BnkHircHierarchyEntry.makePropsFromParams(hirc.initialParams.propValues, hirc.initialParams.rangedPropValues));
        var specificParams = hirc.specificParams;
        if (specificParams is BnkSwitchActionParams) {
          var groupName = wemIdsToNames[specificParams.ulSwitchGroupID] ?? specificParams.ulSwitchGroupID.toString();
          var switchValue = wemIdsToNames[specificParams.ulSwitchStateID] ?? specificParams.ulSwitchStateID.toString();
          addGroupUsage(usedSwitchGroups, groupName, switchValue);
          props.addAll([
            (false, ["Switch Group", "Switch State"]),
            (true, [groupName, switchValue]),
          ]);
        }
        if (specificParams is BnkStateActionParams) {
          var groupName = wemIdsToNames[specificParams.ulStateGroupID] ?? specificParams.ulStateGroupID.toString();
          var stateValue = wemIdsToNames[specificParams.ulTargetStateID] ?? specificParams.ulTargetStateID.toString();
          addGroupUsage(usedStateGroups, groupName, stateValue);
          props.addAll([
            (false, ["State Group", "Target State"]),
            (true, [groupName, stateValue]),
          ]);
        }
        if (specificParams is BnkValueActionParams) {
          if (gameParamActionTypes.contains(hirc.ulActionType & 0xFF00)) {
            var gameParamName = wemIdsToNames[hirc.initialParams.idExt] ?? hirc.initialParams.idExt.toString();
            addGroupUsage(usedGameParameters, gameParamName, "");
            props.addAll([
              (false, ["Game Parameter"]),
              (true, [gameParamName]),
            ]);
          }
          double? base, min, max;
          var valueParams = specificParams.specificParams;
          if (valueParams is BnkGameParameterParams) {
            base = valueParams.base;
            min = valueParams.min;
            max = valueParams.max;
          }
          else if (valueParams is BnkPropActionParams) {
            base = valueParams.base;
            min = valueParams.min;
            max = valueParams.max;
          }
          if (base != null && min != null && max != null) {
            props.addAll([
              (false, ["Value", "(Min)", "(Max)"]),
              (true, ["$base", "$min", "$max"]),
            ]);
          }
        }
      }
      else if (hirc is BnkEvent)
        childIds = hirc.ids;
      else if (hirc is BnkActorMixer)
        childIds = hirc.childIDs;
      else if (hirc is BnkState)
        props.addAll(BnkHircHierarchyEntry.makePropsFromParams(hirc.props));
      else
        continue;

      var chunkType = hirc.runtimeType.toString().replaceFirst("Bnk", "");
      String? entryName;
      if (uidNameStr.isEmpty) {
        uidNameStr = "(${hirc.uid.toString()})";
      } else {
        entryName = uidNameStr;
        uidNameStr += " (${hirc.uid})";
      }
      var entryFullName = "$chunkType $uidNameStr";
      var entry = BnkHircHierarchyEntry(entryFullName, entryPath, chunkType, id: hirc.uid, entryName: entryName, parentIds: parentId, childIds: childIds, properties: props, hirc: hirc);

      if (hirc is BnkEvent) {
        List<BnkHircHierarchyEntry> childActions = [];
        for (var childId in childIds) {
          var child = actionEntries[childId];
          if (child == null) {
            var childName = wemIdsToNames[childId] ?? childId.toString();
            child = BnkHircHierarchyEntry(childName, "", "Action", id: childId, parentIds: [hirc.uid]);
            actionEntries[childId] = child;
          }
          child.parentIds.add(hirc.uid);
          childActions.add(child);
        }
        // childActions.sort((a, b) => a.name.value.toLowerCase().compareTo(b.name.value.toLowerCase()));
        for (var actionEntry in childActions)
          entry.add(actionEntry);
        eventEntries.add(entry);
      }
      else if (hirc is BnkAction) {
        actionEntries[hirc.uid] = entry;
      }
      else {
        hircEntries[hirc.uid] = entry;
      }
    }

    // Add child ids to parents
    for (var entry in hircEntries.entries) {
      var hasChildren = entry.value.childIds.isNotEmpty;
      if (hasChildren) {
        for (var childId in entry.value.childIds) {
          var child = hircEntries[childId];
          if (child == null)
            continue;
          if (child.parentIds.contains(entry.value.id))
            continue;
          child.parentIds.add(entry.value.id);
        }
      }
    }
    var groupUsages = [
      ("Switch Groups", usedSwitchGroups),
      ("State Groups", usedStateGroups),
    ];
    for (var groupUsage in groupUsages) {
      var groupName = groupUsage.$1;
      var groupMap = groupUsage.$2;
      if (groupMap.isEmpty)
        continue;
      var groupParentEntry = BnkSubCategoryParentHierarchyEntry(groupName, isCollapsed: true);
      add(groupParentEntry);
      var groupEntries = groupMap.entries.toList();
      groupEntries.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
      for (var group in groupEntries) {
        var groupEntry = BnkHircHierarchyEntry(group.key, "", groupName, id: randomId());
        groupParentEntry.add(groupEntry);
        var groupValues = group.value.toList();
        groupValues.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        for (var entryName in groupValues) {
          var entry = BnkHircHierarchyEntry(entryName, "", "Group Entry", id: randomId());
          groupEntry.add(entry);
        }
      }
    }
    if (usedGameParameters.isNotEmpty) {
      var gameParamParentEntry = BnkSubCategoryParentHierarchyEntry("Game Parameters", isCollapsed: true);
      add(gameParamParentEntry);
      var gameParameters = usedGameParameters.keys.toList();
      gameParameters.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      for (var gameParam in gameParameters) {
        var gameParamEntry = BnkHircHierarchyEntry(gameParam, "", "Game Parameter", id: randomId());
        gameParamParentEntry.add(gameParamEntry);
      }
    }
    var objectHierarchyParentEntry = BnkSubCategoryParentHierarchyEntry("Object Hierarchy");
    add(objectHierarchyParentEntry);
    int directChildren = 0;
    // Add children to parents using parent ids
    for (var entry in hircEntries.entries) {
      var hasParent = entry.value.parentIds.isNotEmpty;
      if (hasParent) {
        for (var parentId in entry.value.parentIds.toList()) {
          var parent = hircEntries[parentId];
          if (parent == null) {
            entry.value.parentIds.remove(parentId);
          } else if (!parent.children.contains(entry.value)) {
            var child = entry.value;
            parent.add(child);
          } else {
            // print("Duplicate parent-child relationship: ${parent.name.value} -> ${entry.value.name.value}");
          }
        }
      }
      else {
        var child = entry.value;
        objectHierarchyParentEntry.add(child);
        directChildren++;
      }
    }
    if (directChildren > 50)
      objectHierarchyParentEntry.isCollapsed.value = true;

    bool useUniqueActionChildren = hircEntries.length * actionEntries.length < 4*1000*1000;
    for (var actionEntry in actionEntries.values) {
      var action = actionEntry.hirc as BnkAction;
      var actionChild = hircEntries[action.initialParams.idExt];
      if (actionChild != null) {
        actionEntry.add(actionChild, uniqueChildren: useUniqueActionChildren);
      }
      else {
        var actionChildName = wemIdsToNames[action.initialParams.idExt] ?? "Target ${action.initialParams.idExt.toString()}";
        var actionChildId = randomId();
        var actionChildEntry = BnkHircHierarchyEntry(actionChildName, "", "ActionTarget", id: actionChildId, parentIds: [action.uid], entryName: wemIdsToNames[action.initialParams.idExt]);
        hircEntries[actionChildId] = actionChildEntry;
        actionEntry.add(actionChildEntry);
      }
    }

    var eventHierarchyParentEntry = BnkSubCategoryParentHierarchyEntry("Event Hierarchy");
    add(eventHierarchyParentEntry);
    eventEntries.sort((a, b) {
      if (a.entryName != null && b.entryName != null)
        return a.entryName!.toLowerCase().compareTo(b.entryName!.toLowerCase());
      return a.id.compareTo(b.id);
    });
    for (var entry in eventEntries)
      eventHierarchyParentEntry.add(entry);
    if (eventEntries.length > 50)
      eventHierarchyParentEntry.isCollapsed.value = true;

    print("Total tree size: ${countAllRec()}");
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

  @override
  void add(HierarchyEntry child, { bool uniqueChildren = true }) {
    if (uniqueChildren && child is BnkHircHierarchyEntry) {
      child.usages++;
      if (child.usages > 1)
        child = child.takeSnapshot() as BnkHircHierarchyEntry;
    }
    super.add(child);
  }
}

class BnkHircHierarchyEntry extends GenericFileHierarchyEntry {
  static const nonCollapsibleTypes = { "WEM", "Group Entry", "Game Parameter", "State" };
  static const openableTypes = { "MusicPlaylist", "WEM" };
  final String type;
  final int id;
  final String? entryName;
  final BnkHircChunkBase? hirc;
  List<int> parentIds;
  List<int> childIds;
  List<(bool, List<String>)>? properties;
  int usages = 0;
  bool _isDisposed = false;

  BnkHircHierarchyEntry(String name, String path, this.type, {required this.id, String? entryName, this.parentIds = const [], this.childIds = const [], this.properties, this.hirc}) :
    entryName = entryName ?? wemIdsToNames[id],
    super(StringProp(name, fileId: null), path, !nonCollapsibleTypes.contains(type), openableTypes.contains(type)) {
    isCollapsed.value = true;
  }

  @override
  HierarchyEntry clone() {
    return BnkHircHierarchyEntry(name.value, path, type, id: id, parentIds: parentIds, childIds: childIds, properties: properties);
  }

  @override
  void add(HierarchyEntry child, { bool uniqueChildren = true }) {
    if (uniqueChildren && child is BnkHircHierarchyEntry) {
      child.usages++;
      if (child.usages > 1)
        child = child.takeSnapshot() as BnkHircHierarchyEntry;
    }
    super.add(child);
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      if (entryName != null || wemIdsToNames.containsKey(id))
        HierarchyEntryAction(
          name: "Copy Name",
          icon: Icons.copy,
          action: () => copyToClipboard(entryName ?? wemIdsToNames[id]!),
        ),
      HierarchyEntryAction(
        name: "Copy ID",
        icon: Icons.copy,
        action: () => copyToClipboard(id.toString()),
      ),
      ...super.getContextMenuActions(),
    ];
  }

  @override
  void dispose() {
    if (_isDisposed)
      return;
    super.dispose();
    _isDisposed = true;
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
