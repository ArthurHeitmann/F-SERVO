
import 'questStages.dart';

enum GlobalPhase {
  p100("p100", 0x100),
  p200("p200", 0x200),
  p300("p300", 0x300),
  p400("p400", 0x400),
  pf31("pf31", 0xf31);

  final String value;
  final int intValue;

  const GlobalPhase(this.value, this.intValue);
}

class PhaseQuestBind {
  final String phase;
  final QuestId questId;
  final bool isOn;

  const PhaseQuestBind(this.phase, this.questId, this.isOn);
}

class GroupedPhaseQuestBind {
  final GlobalPhase globalPhase;
  final List<PhaseQuestBind> phaseQuestBinds;

  const GroupedPhaseQuestBind(this.globalPhase, this.phaseQuestBinds);
}

enum PlayerFlag {
  none(0),
  twoB(1),
  nineS(2),
  a2(3),
  common(4);

  final int value;

  const PlayerFlag(this.value);
}

class ChapterQuestBind {
  final GlobalPhase globalPhase;
  final String phaseStart;
  final String? phaseEnd;
  final QuestId questId;
  final PlayerFlag playerFlag;

  const ChapterQuestBind(this.globalPhase, this.phaseStart, this.phaseEnd, this.questId, this.playerFlag);
}
