

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../background/wemFilesIndexer.dart';
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../../fileTypeUtils/audio/convertStreamedToInMemory.dart';
import '../../../fileTypeUtils/audio/removePrefetchWems.dart';
import '../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../../fileTypeUtils/audio/wwiseObjectPath.dart';
import '../../../utils/utils.dart';
import '../../../widgets/misc/wwiseProjectGeneratorPopup.dart';
import '../../Property.dart';
import '../../openFiles/types/WemFileData.dart';
import '../HierarchyEntryTypes.dart';
import 'WaiHierarchyEntries.dart';
import '../../../fileSystem/FileSystem.dart';

mixin _Cloneable on HierarchyEntry {
  HierarchyEntry clone();
}

class BnkHierarchyEntry extends FileHierarchyEntry with _Cloneable {
  final String extractedPath;
  final BnkFile bnk;

  BnkHierarchyEntry(StringProp name, String path, this.extractedPath, this.bnk)
      : super(name, path, true, false, priority: 50);

  @override
  HierarchyEntry clone() {
    return BnkHierarchyEntry(name.takeSnapshot() as StringProp, path, extractedPath, bnk);
  }

  Future<void> generateHierarchy(String bnkName, bool collapseCategories) async {
    var bnkHeader = bnk.chunks.whereType<BnkHeader>().first;
    var bnkId = bnkHeader.bnkId;
    var hircChunk = bnk.chunks.whereType<BnkHircChunk>().firstOrNull;
    if (hircChunk == null)
      return;
    Map<int, BnkHircHierarchyEntry> hircEntries = {};
    Map<int, BnkHircHierarchyEntry> actionEntries = {};
    List<BnkHircHierarchyEntry> eventEntries = [];
    Map<int, Set<int>> usedSwitchGroups = {};
    Map<int, Set<int>> usedStateGroups = {};
    Map<int, Set<String>> usedGameParameters = {};
    void addGroupUsage<S, T>(Map<S, Set<T>> map, S groupName, T id) {
      if (!map.containsKey(groupName))
        map[groupName] = {};
      map[groupName]!.add(id);
    }
    for (var hirc in hircChunk.chunks) {
      var uidNameLookup = wemIdsToNames[hirc.uid];
      var uidNameStr = uidNameLookup ?? "";
      String entryPath;
      if (hirc is BnkMusicPlaylist)
        entryPath = "$path#p=${hirc.uid}";
      else
        entryPath = "";
      List<int> parentId = [];
      List<int> childIds = [];
      List<(bool, List<String>)> props = [];
      List<TransitionRule> transitionRules = [];
      if (hirc is BnkHircChunkWithBaseParamsGetter) {
        var hircChunk = hirc;
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
            addGroupUsage(usedStateGroups, stateGroup.ulStateGroupID, state.ulStateID);
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
        Future<void> addWemChild(int srcId, int streamType) async {
          var srcName = wemIdsToNames.containsKey(srcId) ? "${wemIdsToNames[srcId]!} ($srcId)" : srcId.toString();
          var wemPath = await wemFilesLookup.lookupWithAdditionalDir(srcId, extractedPath);
          if (hircEntries.containsKey(srcId)) {
            var child = hircEntries[srcId]!;
            child.parentIds.add(hirc.uid);
          }
          else {
            var srcEntry = BnkHircHierarchyEntry(srcName, wemPath ?? "", "WEM", id: srcId, parentIds: [hirc.uid]);
            srcEntry.optionalFileInfo = OptionalWemData(path, WemSource.bnk, isStreamed: streamType > 0, isPrefetched: streamType == 2);
            hircEntries[srcId] = srcEntry;
          }
        }
        if (hircChunk is BnkMusicTrack) {
          for (var src in hircChunk.sources) {
            var srcId = src.fileID;
            await addWemChild(srcId, src.streamType);
          }
        }
        for (var rtpc in baseParams.rtpc.rtpc) {
          addGroupUsage(usedGameParameters, rtpc.rtpcId, "");
        }
        if (hircChunk is BnkSound) {
          var srcId = hircChunk.bankData.mediaInformation.uFileID;
          if (srcId == bnkId)
            srcId = hircChunk.bankData.mediaInformation.sourceID;
          await addWemChild(srcId, hircChunk.bankData.streamType);
        }
        if (hircChunk is BnkMusicSwitch) {
          if (wemIdsToNames.containsKey(hircChunk.ulGroupID))
            uidNameStr = wemIdsToNames[hircChunk.ulGroupID].toString();
          var groupName = wemIdsToNames[hircChunk.ulGroupID] ?? hircChunk.ulGroupID.toString();
          var defaultValue = wemIdsToNames[hircChunk.ulDefaultSwitch] ?? hircChunk.ulDefaultSwitch.toString();
          addGroupUsage(usedSwitchGroups, hircChunk.ulGroupID, hircChunk.ulDefaultSwitch);
          props.addAll([
            (false, ["Switch Group", "Default Switch"]),
            (true, [groupName, defaultValue]),
          ]);
          for (var switchAssoc in hircChunk.pAssocs) {
            var switchAssocName = wemIdsToNames[switchAssoc.switchID] ?? switchAssoc.switchID.toString();
            if (switchAssoc.switchID == hircChunk.ulDefaultSwitch)
              switchAssocName += " (Default)";
            addGroupUsage(usedSwitchGroups, hircChunk.ulGroupID, switchAssoc.switchID);
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
        if (hircChunk is BnkSoundSwitch) {
          if (wemIdsToNames.containsKey(hircChunk.ulGroupID))
            uidNameStr = wemIdsToNames[hircChunk.ulGroupID].toString();
          var groupName = wemIdsToNames[hircChunk.ulGroupID] ?? hircChunk.ulGroupID.toString();
          var defaultValue = wemIdsToNames[hircChunk.ulDefaultSwitch] ?? hircChunk.ulDefaultSwitch.toString();
          addGroupUsage(usedSwitchGroups, hircChunk.ulGroupID, hircChunk.ulDefaultSwitch);
          props.addAll([
            (false, ["Switch Group", "Default Switch"]),
            (true, [groupName, defaultValue]),
          ]);
          for (var switchAssoc in hircChunk.switches) {
            var switchAssocName = wemIdsToNames[switchAssoc.ulSwitchID] ?? switchAssoc.ulSwitchID.toString();
            if (switchAssoc.ulSwitchID == hircChunk.ulDefaultSwitch)
              switchAssocName += " (Default)";
            addGroupUsage(usedSwitchGroups, hircChunk.ulGroupID, switchAssoc.ulSwitchID);
            var childNodeIds = switchAssoc.nodeIDs;
            for (var childNodeId in childNodeIds) {
              var switchId = randomId();
              List<(bool, List<String>)>? childProps;
              var param = hircChunk.switchParams.where((p) => p.ulNodeID == childNodeId).firstOrNull;
              if (param != null) {
                childProps = [];
                if (param.bIsFirstOnly != 0)
                  childProps.add((true, ["Is First Only", "True"]));
                if (param.bContinuePlayback != 0)
                  childProps.add((true, ["Continue Playback", "True"]));
                if (param.eOnSwitchMod != 1)
                  childProps.add((true, ["On Switch Mod", "${param.eOnSwitchMod}"]));
                if (param.fadeOutTime != 0)
                  childProps.add((true, ["Fade Out Time", "${param.fadeOutTime}"]));
                if (param.fadeInTime != 0)
                  childProps.add((true, ["Fade In Time", "${param.fadeInTime}"]));
                if (childProps.isNotEmpty)
                  print("Child props: $childProps (${hircChunk.uid})");
              }
              var switchAssocEntry = BnkHircHierarchyEntry(
                switchAssocName, "", "SwitchAssoc",
                id: switchId,
                parentIds: [hirc.uid],
                childIds: [childNodeId],
                entryName: wemIdsToNames[switchAssoc.ulSwitchID],
                properties: childProps
              );
              hircEntries[switchId] = switchAssocEntry;
              var nodeChild = hircEntries[childNodeId];
              if (nodeChild != null) {
                nodeChild.parentIds.add(switchId);
              } else {
                var nodeEntry = BnkHircHierarchyEntry(
                    "Node $switchAssocName", "", "Node",
                    id: childNodeId,
                    parentIds: [switchId],
                    entryName: wemIdsToNames[switchAssoc.ulSwitchID]);
                hircEntries[childNodeId] = nodeEntry;
              }
            }
          }
        }
        if (hircChunk is BnkHircChunkWithTransNodeParams) {
          var rules = (hircChunk as BnkHircChunkWithTransNodeParams).musicTransParams.rules;
          for (var rule in rules) {
            transitionRules.add(TransitionRule.make(rule, hircEntries));
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
          uidNameStr = _actionIdToStr(hirc.ulActionType);
        props.addAll(BnkHircHierarchyEntry.makePropsFromParams(hirc.initialParams.propValues, hirc.initialParams.rangedPropValues));
        var specificParams = hirc.specificParams;
        if (specificParams is BnkSwitchActionParams) {
          var groupName = wemIdsToNames[specificParams.ulSwitchGroupID] ?? specificParams.ulSwitchGroupID.toString();
          var switchValue = wemIdsToNames[specificParams.ulSwitchStateID] ?? specificParams.ulSwitchStateID.toString();
          addGroupUsage(usedSwitchGroups, specificParams.ulSwitchGroupID, specificParams.ulSwitchStateID);
          props.addAll([
            (false, ["Switch Group", "Switch State"]),
            (true, [groupName, switchValue]),
          ]);
        }
        if (specificParams is BnkStateActionParams) {
          var groupName = wemIdsToNames[specificParams.ulStateGroupID] ?? specificParams.ulStateGroupID.toString();
          var stateValue = wemIdsToNames[specificParams.ulTargetStateID] ?? specificParams.ulTargetStateID.toString();
          addGroupUsage(usedStateGroups, specificParams.ulStateGroupID, specificParams.ulTargetStateID);
          props.addAll([
            (false, ["State Group", "Target State"]),
            (true, [groupName, stateValue]),
          ]);
        }
        if (specificParams is BnkValueActionParams) {
          if (gameParamActionTypes.contains(hirc.ulActionType & 0xFF00)) {
            var gameParamName = wemIdsToNames[hirc.initialParams.idExt] ?? hirc.initialParams.idExt.toString();
            addGroupUsage(usedGameParameters, hirc.initialParams.idExt, "");
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
      var entry = BnkHircHierarchyEntry(entryFullName, entryPath, chunkType,
        id: hirc.uid,
        entryName: entryName,
        parentIds: parentId,
        childIds: childIds,
        properties: props,
        hirc: hirc,
        transitionRules: transitionRules,
      );

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

    // Add entries to hierarchy
    Map<int, String> bnkPaths = wwiseObjectBnkToIdObjectPath[bnkName] ?? wwiseObjectBnkToIdObjectPath[wemIdsToNames[bnkId]] ?? wwiseIdToObjectPath;
    void addToTopLevel(BnkHircHierarchyEntry entry, BnkSubCategoryParentHierarchyEntry topLevelEntry) {
      var localBnkPaths = bnkPaths;
      if (!localBnkPaths.containsKey(entry.hirc?.uid ?? entry.id)) {
        localBnkPaths = wwiseObjectBnkToIdObjectPath["Init"]!;
        if (!localBnkPaths.containsKey(entry.hirc?.uid ?? entry.id)) {
          topLevelEntry.add(entry);
          return;
        }
      }
      var path = localBnkPaths[entry.id]!.split("/").skip(1);
      path = path.take(path.length - 1);
      if (path.isEmpty) {
        topLevelEntry.add(entry);
        return;
      }
      HierarchyEntry resolvePath(Iterable<String> path, HierarchyEntry parent) {
        var childName = path.firstOrNull;
        if (childName == null)
          return parent;
        var child = parent.children.where((child) => child.name.value == childName).firstOrNull;
        if (child == null) {
          child = BnkSubCategoryParentHierarchyEntry(childName, isFolder: true);
          parent.add(child);
        }
        return resolvePath(path.skip(1), child);
      }
      var parent = resolvePath(path, topLevelEntry);
      parent.add(entry);
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
      List<({int id, String name, List<int> values})> groupEntries = groupMap.entries
        .map((e) => (id: e.key, name: wemIdsToNames[e.key] ?? e.key.toString(), values: e.value.toList()))
        .toList();
      groupEntries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (var group in groupEntries) {
        var groupEntry = BnkHircHierarchyEntry(group.name, "", groupName, id: group.id);
        addToTopLevel(groupEntry, groupParentEntry);
        var groupValues = group.values.map((v) => (v, wemIdsToNames[v] ?? v.toString())).toList();
        groupValues.sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
        for (var (vId, vName) in groupValues) {
          var entry = BnkHircHierarchyEntry(vName, "", "Group Entry", id: vId);
          groupEntry.add(entry);
        }
      }
    }
    if (usedGameParameters.isNotEmpty) {
      var gameParamParentEntry = BnkSubCategoryParentHierarchyEntry("Game Parameters", isCollapsed: true);
      add(gameParamParentEntry);
      var gameParameters = usedGameParameters.keys
        .map((id) => (id, wemIdsToNames[id] ?? id.toString()))
        .toList();
      gameParameters.sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
      for (var (paramId, paramName) in gameParameters) {
        var gameParamEntry = BnkHircHierarchyEntry(paramName, "", "Game Parameter", id: paramId);
        addToTopLevel(gameParamEntry, gameParamParentEntry);
      }
    }
    var objectHierarchyParentEntry = BnkSubCategoryParentHierarchyEntry("Object Hierarchy", isCollapsed: collapseCategories);
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
        addToTopLevel(child, objectHierarchyParentEntry);
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

    var eventHierarchyParentEntry = BnkSubCategoryParentHierarchyEntry("Event Hierarchy", isCollapsed: collapseCategories);
    add(eventHierarchyParentEntry);
    eventEntries.sort((a, b) {
      if (a.entryName != null && b.entryName != null)
        return a.entryName!.toLowerCase().compareTo(b.entryName!.toLowerCase());
      return a.id.compareTo(b.id);
    });
    for (var entry in eventEntries)
      addToTopLevel(entry, eventHierarchyParentEntry);
    if (eventEntries.length > 50)
      eventHierarchyParentEntry.isCollapsed.value = true;
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions()
    ];
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Create Wwise project",
        icon: Icons.drive_folder_upload,
        action: () => showWwiseProjectGeneratorPopup(path),
      ),
      HierarchyEntryAction(
        name: "Remove prefetch WEMs",
        icon: Icons.playlist_remove,
        action: _removePrefetchWems,
      ),
      HierarchyEntryAction(
        name: "Generate cues info file",
        icon: Icons.playlist_add_check,
        action: _generateCuesTxtFile,
      ),
      ...super.getActions()
    ];
  }

  Future<void> _removePrefetchWems() async {
    await backupFile(path);
    var removedWemIds = await removePrefetchWems(path);
    var wemsParent = children.where((child) => child.name.value == "WEM files").firstOrNull;
    if (wemsParent != null) {
      for (var child in wemsParent.children.whereType<WemHierarchyEntry>().toList()) {
        if (removedWemIds.contains(child.wemId))
          wemsParent.remove(child, dispose: true);
      }
    }

    if (removedWemIds.isEmpty)
     showToast("No prefetched WEMs found in ${basename(path)}");
    else
      showToast("Removed ${pluralStr(removedWemIds.length, "prefetched WEM")} from ${basename(path)}");
  }

  void _generateCuesTxtFile() async {
    var txt = "";
    var parent = children.where((e) => e.name.value == "Object Hierarchy").firstOrNull;
    for (var child in parent?.children.whereType<BnkHircHierarchyEntry>() ?? const Iterable.empty()) {
      txt += _generateCuesTxt(child, null, 0);
    }
    
    var cuesTxtPath = await FS.i.saveFile(
      text: txt,
      dialogTitle: "Save cues info file",
      fileName: "${basenameWithoutExtension(path)}_cues.txt",
    );
    if (cuesTxtPath == null)
      return;
    showToast("Saved cues info file");
  }

  String _generateCuesTxt(BnkHircHierarchyEntry entry, BnkHircHierarchyEntry? parent, int depth) {
    var chunk = entry.hirc;
    var parentChunk = parent?.hirc;
    
    if (chunk is BnkMusicSegment) {
      var txt = "${"  " * depth}- ${entry.name} (duration ${(chunk.fDuration / 1000).toStringAsFixed(3)}s)";
      if (parentChunk is BnkMusicPlaylist) {
        var plItem = parentChunk.playlistItems.where((e) => e.segmentId == chunk.uid).firstOrNull;
        if (plItem != null)
         txt += " (loops ${plItem.loop == 0 ? "Infinite" : plItem.loop})";
      }
      txt += "\n";
      for (var (i, marker) in chunk.wwiseMarkers.indexed) {
        String name;
        if (i == 0)
          name = "Entry";
        else if (i + 1 == chunk.wwiseMarkers.length)
          name = "Exit ";
        else
          name = "Custom $i";
        txt += "${"  " * (depth + 1)}- $name cue: ${(marker.fPosition / 1000).toStringAsFixed(3)}s\n";
      }
      return txt;
    }
    
    var txt = "";
    var children = entry.children.whereType<BnkHircHierarchyEntry>();
    if (chunk is BnkMusicSwitch)
      children = children.where((e) => e.type == "SwitchAssoc");
    for (var child in children) {
      txt += _generateCuesTxt(child, entry, depth + 1);
    }
    if (txt.isEmpty)
      return txt;
    txt = "${"  " * depth}- ${entry.name.toString()}\n$txt";
    return txt;
  }
}

class BnkSubCategoryParentHierarchyEntry extends HierarchyEntry with _Cloneable {
  final bool isFolder;

  BnkSubCategoryParentHierarchyEntry(String name, { bool isCollapsed = false, this.isFolder = false })
      : super(StringProp(name, fileId: null), false, true, false) {
    this.isCollapsed.value = isCollapsed;
  }

  @override
  HierarchyEntry clone() {
    var entry = BnkSubCategoryParentHierarchyEntry(name.value);
    entry.overrideUuid(uuid);
    entry.isSelected.value = isSelected.value;
    entry.isCollapsed.value = isCollapsed.value;
    entry.clear();
    entry.addAll(children.map((child) => child is _Cloneable ? child.clone() : child));
    return entry;
  }

  @override
  void add(HierarchyEntry child, { bool uniqueChildren = true }) {
    if (uniqueChildren && child is BnkHircHierarchyEntry) {
      child.usages++;
      if (child.usages > 1)
        child = (child as _Cloneable).clone();
    }
    super.add(child);
  }
}

class BnkHircHierarchyEntry extends FileHierarchyEntry with _Cloneable {
  static const nonCollapsibleTypes = { "WEM", "Group Entry", "Game Parameter", "State" };
  static const openableTypes = { "MusicPlaylist", "WEM" };
  final String type;
  final int id;
  final String? entryName;
  final BnkHircChunkBase? hirc;
  final List<TransitionRule> transitionRules;
  List<int> parentIds;
  List<int> childIds;
  List<(bool, List<String>)>? properties;
  int usages = 0;
  bool _isDisposed = false;

  BnkHircHierarchyEntry(String name, String path, this.type, {required this.id, String? entryName, this.parentIds = const [], this.childIds = const [], this.properties, this.hirc, this.transitionRules = const []}) :
    entryName = entryName ?? wemIdsToNames[id],
    super(StringProp(name, fileId: null), path, !nonCollapsibleTypes.contains(type), openableTypes.contains(type)) {
    isCollapsed.value = true;
  }

  @override
  HierarchyEntry clone() {
    return BnkHircHierarchyEntry(name.value, path, type, id: id, entryName: entryName, parentIds: parentIds, childIds: childIds, properties: properties, hirc: hirc, transitionRules: transitionRules);
  }

  @override
  void add(HierarchyEntry child, { bool uniqueChildren = true }) {
    if (uniqueChildren && child is BnkHircHierarchyEntry) {
      child.usages++;
      if (child.usages > 1)
        child = (child as _Cloneable).clone();
    }
    super.add(child);
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    var fileInfo = optionalFileInfo;
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
      if (fileInfo is OptionalWemData && (fileInfo.isStreamed || fileInfo.isPrefetched))
        HierarchyEntryAction(
          name: "Make in memory",
          icon: Icons.swap_horiz,
          action: () => convertStreamedToInMemory(fileInfo.bnkPath, id),
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

class TransitionSrc {
  final String fallbackText;
  final BnkHircHierarchyEntry? entry;

  const TransitionSrc(this.fallbackText, this.entry);

  static TransitionSrc fromId(int id, Map<int, BnkHircHierarchyEntry> hircEntries) {
    if (id == -1)
      return const TransitionSrc("Any", null);
    if (id == 0)
      return const TransitionSrc("None", null);
    var entry = hircEntries[id];
    if (entry != null)
      return TransitionSrc("", entry);
    return TransitionSrc(id.toString(), null);
  }
}

class TransitionRule {
  final TransitionSrc src;
  final TransitionSrc dst;
  final TransitionSrcRule srcRule;
  final TransitionDstRule dstRule;
  final bool isTransObjectEnabled;
  final TransitionObject musicTransition;

  const TransitionRule(this.src, this.dst, this.srcRule, this.dstRule, this.isTransObjectEnabled, this.musicTransition);

  static TransitionRule make(BnkMusicTransitionRule transitionRule, Map<int, BnkHircHierarchyEntry> hircEntries) {
    return TransitionRule(
      TransitionSrc.fromId(transitionRule.srcID, hircEntries),
      TransitionSrc.fromId(transitionRule.dstID, hircEntries),
      TransitionSrcRule.make(transitionRule.srcRule),
      TransitionDstRule.make(transitionRule.dstRule),
      transitionRule.bIsTransObjectEnabled != 0,
      TransitionObject.make(transitionRule.musicTransition, hircEntries)
    );
  }
}

class TransitionSrcRule {
  final FadeParams fadeParam;
  final String syncType;
  final int markerId;
  final int playPostExit;

  const TransitionSrcRule(this.fadeParam, this.syncType, this.markerId, this.playPostExit);

  static TransitionSrcRule make(BnkMusicTransSrcRule srcRule) {
    return TransitionSrcRule(
      FadeParams.make(srcRule.fadeParam),
      syncTypes[srcRule.eSyncType] ?? srcRule.eSyncType.toString(),
      srcRule.uMarkerID,
      srcRule.bPlayPostExit
    );
  }
}

class TransitionDstRule {
  final FadeParams fadeParam;
  final int markerId;
  final int jumpToId;
  final String entryType;
  final bool playPreEntry;
  final bool matchSourceCueName;

  const TransitionDstRule(this.fadeParam, this.markerId, this.jumpToId, this.entryType, this.playPreEntry, this.matchSourceCueName);

  static TransitionDstRule make(BnkMusicTransDstRule dstRule) {
    return TransitionDstRule(
      FadeParams.make(dstRule.fadeParam),
      dstRule.uMarkerID,
      dstRule.uJumpToID,
      entryTypes[dstRule.eEntryType] ?? dstRule.eEntryType.toString(),
      dstRule.bPlayPreEntry != 0,
      dstRule.bDestMatchSourceCueName != 0
    );
  }
}

class TransitionObject {
  final TransitionSrc segment;
  final FadeParams fadeInParams;
  final FadeParams fadeOutParams;
  final bool playPreEntry;
  final bool playPostExit;

  const TransitionObject(this.segment, this.fadeInParams, this.fadeOutParams, this.playPreEntry, this.playPostExit);

  static TransitionObject make(BnkMusicTransitionObject transitionObject, Map<int, BnkHircHierarchyEntry> hircEntries) {
    return TransitionObject(
      TransitionSrc.fromId(transitionObject.segmentID, hircEntries),
      FadeParams.make(transitionObject.fadeInParams),
      FadeParams.make(transitionObject.fadeOutParams),
      transitionObject.playPreEntry != 0,
      transitionObject.playPostExit != 0
    );
  }

  bool get isDefault => segment.fallbackText == "None" && fadeInParams.isDefault && fadeOutParams.isDefault && !playPreEntry && !playPostExit;
}

class FadeParams {
  final String curve;
  final int time;
  final int offset;

  const FadeParams(this.curve, this.time, this.offset);

  static FadeParams make(BnkFadeParams fadeParams) {
    return FadeParams(
      curveInterpolations[fadeParams.eFadeCurve] ?? fadeParams.eFadeCurve.toString(),
      fadeParams.transitionTime,
      fadeParams.iFadeOffset
    );
  }

  bool get isDefault => curve == "Linear" && time == 0 && offset == 0;
}

String _actionIdToStr(int id) {
  const gameObjectFlag = 0x01;
  const allFlag = 0x04;
  const allExceptFlag = 0x08;
  var name = actionTypes[id]!.split("_").first;
  if (id & allFlag != 0 && name != "SetState")
    name += " All";
  else if (id & allExceptFlag != 0)
    name += " All Except";
  if (id & gameObjectFlag != 0)
    name += " (Game Object)";
  else
    name += " (Global)";
  return name;
}
