
import 'localizedString.dart';
import 'questStages.dart';
import 'questStateBind.dart';

class NewQuestConfig {
  final QuestId id;
  final LocalizedString name;
  final List<QuestStageWithDescription> stages;
  final List<GroupedPhaseQuestBind> phaseQuestBinds;
  final List<ChapterQuestBind> chapterQuestBinds;
  final String bind;
  final String owner;
  final String comment;
  final String client;

  const NewQuestConfig(
    this.id,
    this.name,
    this.stages,
    this.phaseQuestBinds,
    this.chapterQuestBinds,
    this.bind,
    {
    this.owner = "Cool Modder",
    this.comment = "Custom Quest",
    this.client = "noname",
    }
  );
}
