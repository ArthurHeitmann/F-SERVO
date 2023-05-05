
import 'dart:io';

import 'addCoregmData.dart';
import 'addMcdData.dart';
import 'addTmdData.dart';
import 'addHapXmlData.dart';
import 'dirs.dart';
import 'localizedString.dart';
import 'newQuestConfig.dart';
import 'questStages.dart';
import 'questStateBind.dart';


const questId = QuestId(450);
const questConfig = NewQuestConfig(
  questId,
  LocalizedString.us("The Great Escape"),
  [
    QuestStageWithDescription(
      QuestStage_REQ(questId),
    ),
    QuestStageWithDescription(
      QuestStage_RUN(questId, 1),
      LocalizedString.us("Receive the Distress Signal: You receive a distress signal from the abandoned factory in the city ruins.")
    ),
    QuestStageWithDescription(
      QuestStage_RUN(questId, 2),
      LocalizedString.us("Investigate the Factory: You travel to the factory and must fight your way through waves of machines to get inside.")
    ),
    QuestStageWithDescription(
      QuestStage_RUN(questId, 3),
      LocalizedString.us("Search for Clues: Once inside, you search for clues as to the source of the distress signal. You find signs of a struggle, tracks leading to a particular area of the factory, or overhear machines discussing the location of a group of prisoners.")
    ),
    QuestStageWithDescription(
      QuestStage_RUN(questId, 4),
      LocalizedString.us("Find the Prisoners: You eventually discover a large circular room in the depths of the factory, guarded by powerful machines. Inside the room, you find a group of android prisoners who are being held captive by the machines. The prisoners tell you that they were part of a resistance group and were captured while trying to sabotage the factory.")
    ),
    QuestStageWithDescription(
      QuestStage_RUN(questId, 5),
      LocalizedString.us("Escort the Prisoners: You must escort the prisoners through the factory while fighting off waves of machines. Along the way, you encounter new types of machines with unique abilities, such as ones that can fly or shoot lasers.")
    ),
    QuestStageWithDescription(
      QuestStage_RUN(questId, 6),
      LocalizedString.us("Boss Fight: The quest culminates in a boss fight against a powerful machine that is guarding the exit of the factory. The machine has a unique ability, such as the ability to clone itself or the ability to summon other machines to fight alongside it.")
    ),
    QuestStageWithDescription(
      QuestStage_RUN(questId, 7),
      LocalizedString.us("Escape: Once the boss is defeated, you must make your escape from the factory with the prisoners. You encounter obstacles such as collapsing walkways, traps set by the machines, or more waves of enemies. Once you reach the exit, you must fight off one final wave of machines before you can escape the factory and complete the quest.")
    ),
    QuestStageWithDescription(
      QuestStage_CLR(questId),
    ),
    QuestStageWithDescription(
      QuestStage_DONE(questId),
      LocalizedString.us("Thanks to your bravery and quick thinking, you were able to rescue a group of android prisoners from the clutches of the machines. The prisoners were members of a resistance group and were captured while attempting to sabotage a factory in the city ruins. Their escape was made possible by your efforts and the bonds you formed with them during your journey. The resistance group is now one member stronger thanks to your actions.")
    ),
    QuestStageWithDescription(
      QuestStage_DONE2(questId),
    ),
    QuestStageWithDescription(
      QuestStage_BREAK(questId),
    ),
  ],
  [
    GroupedPhaseQuestBind(
      GlobalPhase.p100,
      [
        PhaseQuestBind("30_AB_Ruined_City_ForcedLanding", questId, true),
      ]
    ),
    GroupedPhaseQuestBind(
      GlobalPhase.p200,
      [
        PhaseQuestBind("00_AB_Ruined_City", questId, true),
        PhaseQuestBind("100_A_Submerge_City_2B", questId, false),
      ]
    ),
  ],
  [
    ChapterQuestBind(GlobalPhase.p100, "30_AB_Ruined_City_ForcedLanding", null, questId, PlayerFlag.common),
    ChapterQuestBind(GlobalPhase.p200, "00_AB_Ruined_City", "200_00_AB_Ruined_City_Eve_EV", questId, PlayerFlag.common),
  ],
  "p100,p200",
  client: "resi"
);

void main(List<String> args) async {
  var existingFiles = await Directory(workDir).list().toList();  
  if (existingFiles.isNotEmpty)
    print("Deleting ${existingFiles.length} files...");
  await Future.wait(existingFiles.map((f) {
    if (f is Directory)
      return f.delete(recursive: true);
    else
      return f.delete();
  }));
  
  await addTmdData(questConfig);
  await addMcdData(questConfig);
  await addHapXmlData(questConfig);
  await addCoregmData(questConfig);

  print("Done!");
}
