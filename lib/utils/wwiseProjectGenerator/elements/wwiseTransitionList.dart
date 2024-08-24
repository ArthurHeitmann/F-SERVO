
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';

XmlElement makeWwiseTransitionList(WwiseProjectGenerator project, String wuId, List<BnkMusicTransitionRule> transitions) {
  return makeXmlElement(name: "TransitionList", children: transitions
    .map((transition) {
      var src = project.lookupElement(idFnv: transition.srcID) as WwiseElement?;
      var dest = project.lookupElement(idFnv: transition.dstID) as WwiseElement?;
      var destPlItem = project.lookupElement(idFnv: transition.dstRule.uJumpToID) as WwiseElement?;
      var transSegment = project.lookupElement(idFnv: transition.musicTransition.segmentID) as WwiseElement?;
      if (transition.srcID > 0 && src == null) {
        project.log(WwiseLogSeverity.warning, "Transition source not found: ${wwiseIdToStr(transition.srcID)}");
        return null;
      }
      if (transition.dstID > 0 && dest == null) {
        project.log(WwiseLogSeverity.warning, "Transition destination not found: ${wwiseIdToStr(transition.dstID)}");
        return null;
      }
      if (transition.dstRule.uJumpToID > 0 && destPlItem == null) {
        project.log(WwiseLogSeverity.warning, "Transition destination playlist item not found: ${wwiseIdToStr(transition.dstRule.uJumpToID)}");
        return null;
      }
      String? srcCustomCueName = transition.srcRule.uMarkerID != 0 ? (project.lookupElement(idFnv: transition.srcRule.uMarkerID) as WwiseElement?)?.name : null;
      String? destCustomCueName = transition.dstRule.uMarkerID != 0 ? (project.lookupElement(idFnv: transition.dstRule.uMarkerID) as WwiseElement?)?.name : null;
      return makeXmlElement(name: "Transition", children: [
        makeXmlElement(name: "Source", children: [
          if (transition.srcID == -1)
            makeXmlElement(name: "Any")
          else if (transition.srcID == 0)
            makeXmlElement(name: "None")
          else
            makeXmlElement(name: "ObjectRef", attributes: {"Name": src!.name, "ID": src.id})
        ]),
        makeXmlElement(name: "Destination", children: [
          if (transition.dstID == -1)
            makeXmlElement(name: "Any")
          else if (transition.dstID == 0)
            makeXmlElement(name: "None")
          else
            makeXmlElement(name: "ObjectRef", attributes: {"Name": dest!.name, "ID": dest.id})
        ]),
        WwiseElement(
          wuId: wuId,
          project: project,
          tagName: "MusicTransition",
          name: "",
          additionalChildren: [makeXmlElement(
            name: "TransitionInfo",
            children: [
              if (transition.dstRule.uJumpToID != 0)
                makeXmlElement(name: "JumpToPlaylistItemRef", attributes: {"Name": destPlItem!.name, "ID": destPlItem.id}),
              if (transition.musicTransition.segmentID != 0)
                makeXmlElement(name: "TransitionObjectRef", attributes: {"Name": transSegment!.name, "ID": transSegment.id}),
              if (!_isFadeParamDefault(transition.srcRule.fadeParam))
                _makeFadeParam(project, wuId, transition.srcRule.fadeParam, "SourceFadeOut", "Source Fade-out", false),
              if (!_isFadeParamDefault(transition.dstRule.fadeParam))
                _makeFadeParam(project, wuId, transition.dstRule.fadeParam, "DestinationFadeIn", "Destination Fade-in", true),
              if (!_isFadeParamDefault(transition.musicTransition.fadeInParams))
                _makeFadeParam(project, wuId, transition.musicTransition.fadeInParams, "TransitionFadeIn", "Transition Fade-in", true),
              if (!_isFadeParamDefault(transition.musicTransition.fadeOutParams))
                _makeFadeParam(project, wuId, transition.musicTransition.fadeOutParams, "TransitionFadeOut", "Transition Fade-out", false),
            ]
          )],
          properties: [
            if (transition.srcRule.eSyncType != 7)
              WwiseProperty("ExitSourceAt", "int16", value: transition.srcRule.eSyncType.toString()),
            if (transition.srcRule.bPlayPostExit == 0)
              WwiseProperty("PlaySourcePostExit", "bool", value: "False"),
            if (!_isFadeParamDefault(transition.srcRule.fadeParam))
              WwiseProperty("EnableSourceFadeOut", "bool", value: "True"),
            if (srcCustomCueName != null)
              WwiseProperty("ExitSourceCustomCueMatchName", "string", value: srcCustomCueName),
            if (transition.dstRule.eEntryType != 0)
              WwiseProperty("DestinationJumpPositionPreset", "int16", value: transition.dstRule.eEntryType.toString()),
            if (!_isFadeParamDefault(transition.dstRule.fadeParam))
              WwiseProperty("EnableDestinationFadeIn", "bool", value: "True"),
            if (transition.dstRule.bPlayPreEntry == 0)
              WwiseProperty("PlayDestinationPreEntry", "bool", value: "False"),
            if (transition.dstRule.bDestMatchSourceCueName != 0)
              WwiseProperty("JumpToCustomCueMatchMode", "int16", value: "0"),
            if (destCustomCueName != null)
              WwiseProperty("JumpToCustomCueMatchName", "string", value: destCustomCueName),
            if (transition.bIsTransObjectEnabled == 1)
              WwiseProperty("UseTransitionObject", "bool", value: "True"),
            if (transition.musicTransition.playPreEntry == 0)
              WwiseProperty("PlayTransitionPreEntry", "bool", value: "False"),
            if (transition.musicTransition.playPostExit == 0)
              WwiseProperty("PlayTransitionPostExit", "bool", value: "False"),
            if (!_isFadeParamDefault(transition.musicTransition.fadeInParams))
              WwiseProperty("EnableTransitionFadeIn", "bool", value: "True"),
            if (!_isFadeParamDefault(transition.musicTransition.fadeOutParams))
              WwiseProperty("EnableTransitionFadeOut", "bool", value: "True"),
          ],
        ).toXml(),
      ]);
    }
    )
    .whereType<XmlElement>()
    .toList()
  );
}

bool _isFadeParamDefault(BnkFadeParams fadeParams) {
  return fadeParams.eFadeCurve == 4 && fadeParams.transitionTime == 0 && fadeParams.iFadeOffset == 0;
}

XmlElement _makeFadeParam(WwiseProjectGenerator project, String wuId, BnkFadeParams fadeParams, String tagName, String name, bool isFadeIn) {
  return makeXmlElement(name: tagName, children: [
    WwiseElement(
      wuId: wuId,
      project: project,
      tagName: "MusicFade",
      name: name,
      properties: [
        if (fadeParams.eFadeCurve != 4)
          WwiseProperty("FadeCurve", "int16", value: fadeParams.eFadeCurve.toString()),
        if (fadeParams.iFadeOffset != 0)
          WwiseProperty("FadeOffset", "Real64", value: (fadeParams.iFadeOffset / 1000).toString()),
        if (fadeParams.transitionTime != 0)
          WwiseProperty("FadeTime", "Real64", value: (fadeParams.transitionTime / 1000).toString()),
        if (!isFadeIn)
          WwiseProperty("FadeType", "int16", value: "1"),
      ]
    ).toXml(),
  ]);
}
