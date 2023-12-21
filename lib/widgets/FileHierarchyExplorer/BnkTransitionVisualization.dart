
import 'package:flutter/material.dart';

import '../../stateManagement/hierarchy/types/BnkHierarchyEntry.dart';
import '../theme/customTheme.dart';

class BnkTransitionVisualization extends StatefulWidget {
  final List<TransitionRule> rules;

  const BnkTransitionVisualization({super.key, required this.rules});

  @override
  State<BnkTransitionVisualization> createState() => _BnkTransitionVisualizationState();
}

class _BnkTransitionVisualizationState extends State<BnkTransitionVisualization> {
  int selectedRuleIndex = 0;
  TransitionRule get selectedRule => widget.rules[selectedRuleIndex];

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          makeRulesList(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    makeSrcVis(context),
                    const SizedBox(height: 12),
                    makeDstVis(context),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  makeTransSegmentVis(context),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget makeSrcObjVis(BuildContext context, TransitionSrc obj) {
    if (obj.entry == null)
      return Text(obj.fallbackText);
    return Text(obj.entry!.name.value);
  }

  Widget makeRulesList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: getTheme(context).propBorderColor!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: getTheme(context).propBorderColor!, width: 1)),
            ),
            height: 22,
            child: const Row(
              children: [
                SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text("No")
                ),
                Expanded(
                  child: Text("Source"),
                ),
                Expanded(
                  child: Text("Destination"),
                ),
              ],
            ),
          ),
          for (int i = 0; i < widget.rules.length; i++)
            Material(
              color: i == selectedRuleIndex
                ? getTheme(context).hierarchyEntrySelected!
                : Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => selectedRuleIndex = i),
                splashColor: getTextColor(context, selectedRuleIndex == i).withOpacity(0.2),
                hoverColor: getTextColor(context, selectedRuleIndex == i).withOpacity(0.1),
                highlightColor: getTextColor(context, selectedRuleIndex == i).withOpacity(0.1),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: getTextColor(context, selectedRuleIndex == i),
                    fontSize: 13,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 30,
                        child: Text((i + 1).toString())
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var src in widget.rules[i].src)
                              makeSrcObjVis(context, src)
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var dst in widget.rules[i].dst)
                              makeSrcObjVis(context, dst)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  Color getTextColor(BuildContext context, bool isSelected) {
    return isSelected
      ? getTheme(context).hierarchyEntrySelectedTextColor!
      : getTheme(context).textColor!;
  }

  Widget makeSrcVis(BuildContext context) {
    var srcRule = selectedRule.srcRule;
    var usesCustomMarker = ["NextMarker", "NextUserMarker"].contains(srcRule.syncType);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: getTheme(context).propBorderColor!.withOpacity(0.5), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Exit source at "),
              makeSelectedValue(context, Text(srcRule.syncType)),
              if (usesCustomMarker) ...[
                const Text(" Match: "),
                makeSelectedValue(context, Text(srcRule.markerId.toString()))
              ]
            ],
          ),
          makeCheckboxText(context, srcRule.playPostExit != 0, "Play post-exit"),
          makeCheckboxText(context, !srcRule.fadeParam.isDefault, "Fade-out"),
          Opacity(
            opacity: srcRule.fadeParam.isDefault ? 0 : 1,
            child: makeFadeParamVis(context, srcRule.fadeParam)
          ),
        ],
      ),
    );
  }

  Widget makeDstVis(BuildContext context) {
    var dstRule = selectedRule.dstRule;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: getTheme(context).propBorderColor!.withOpacity(0.5), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dstRule.jumpToId != 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Jump to playlist item "),
                makeSelectedValue(context, Text(dstRule.jumpToId.toString())),
              ],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Sync to "),
              makeSelectedValue(context, Text(dstRule.entryType)),
            ],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  makeCheckboxText(context, dstRule.playPreEntry, "Play pre-entry"),
                  makeCheckboxText(context, !dstRule.fadeParam.isDefault, "Fade-in"),
                  Opacity(
                    opacity: dstRule.fadeParam.isDefault ? 0 : 1,
                    child: makeFadeParamVis(context, dstRule.fadeParam)
                  ),
                ],
              ),
              if (["RandomMarker", "RandomUserMarker"].contains(dstRule.entryType))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    makeCheckboxText(context, dstRule.matchSourceCueName, "Match source cue name"),
                    makeCheckboxText(context, !dstRule.matchSourceCueName, "Match ", Text(dstRule.markerId.toString())),
                  ],
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget makeTransSegmentVis(BuildContext context) {
    var transSegment = selectedRule.musicTransition;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: getTheme(context).propBorderColor!.withOpacity(0.5), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          makeCheckboxText(context, transSegment != null, "Use transition segment"),
          if (transSegment != null) ...[
            makeSelectedValue(context, makeSrcObjVis(context, transSegment.segment)),
            makeCheckboxText(context, transSegment.playPreEntry, "Play transition pre-entry"),
            makeCheckboxText(context, !transSegment.fadeInParams.isDefault, "Fade-in"),
            Opacity(
              opacity: transSegment.fadeInParams.isDefault ? 0 : 1,
              child: makeFadeParamVis(context, transSegment.fadeInParams),
            ),
            makeCheckboxText(context, transSegment.playPostExit, "Play transition post-exit"),
            makeCheckboxText(context, !transSegment.fadeOutParams.isDefault, "Fade-out"),
            Opacity(
              opacity: transSegment.fadeOutParams.isDefault ? 0 : 1,
              child: makeFadeParamVis(context, transSegment.fadeOutParams),
            ),
          ]
        ],
      ),
    );
  }

  Widget makeFadeParamVis(BuildContext context, FadeParams fadeParam) {
    List<List<Widget>> columns = [
      [
        const Text("Time"),
        makeSelectedValue(context, Text("${fadeParam.time / 1000}s")),
      ],
      [
        const Text("Offset"),
        makeSelectedValue(context, Text("${fadeParam.offset / 1000}s")),
      ],
      [
        const Text(" Curve "),
        makeSelectedValue(context, Text(fadeParam.curve)),
      ],
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var column in columns) ...[
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column[0],
              const SizedBox(height: 4),
              column[1],
            ],
          ),
        ]
      ],
    );
  }

  Widget makeSelectedValue(BuildContext context, Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        color: getTheme(context).formElementBgColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: child,
    );
  }

  Widget makeCheckboxText(BuildContext context, bool isChecked, String text, [Widget? child]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          key: UniqueKey(),
          value: isChecked,
          onChanged: (_) {},
          splashRadius: 0,
        ),
        if (child == null)
          Flexible(
            child: Text(text, overflow: TextOverflow.ellipsis)
          ),
        if (child != null) ...[
          Text(text),
          const SizedBox(width: 6),
          child,
        ]
      ],
    );
  }
}
