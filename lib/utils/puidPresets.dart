
import 'dart:async';

import '../background/IdLookup.dart';

class PuidPreset {
  final String code;
  final FutureOr<List<String>> Function()? getIds;

  const PuidPreset(this.code, [this.getIds]);
}

final List<PuidPreset> puidPresets = [
  PuidPreset("@SceneState", () async => 
    (await idLookup.getAllSceneStates())
      .map((e) => e.key)
      .toList()
  ),
  PuidPreset("hap::StateObject", () => [
    "@SceneState",
    "@MISC",
    "@Quest",
    "@FastTravel",
    "@pf30",
    "@Continue",
  ]),
  PuidPreset("hap::SceneEntities", () => [
    "buddy",
    "PLAYER",
    "player",
    "buddy_9S",
    "buddy_2B",
    "buddy_pascal",
    "buddy_A2",
  ]),
  const PuidPreset("app::EntityLayout"),
  const PuidPreset("hap::Action"),
  const PuidPreset("hap::Hap"),
  const PuidPreset("hap::GroupImpl"),
  const PuidPreset("LayoutObj"),
  const PuidPreset("GlobalRoom"),
  const PuidPreset("GlobalPhase"),
  const PuidPreset("SubPhase"),
  const PuidPreset("Hacking"),
  const PuidPreset("Event"),
];
var puidPresetsMap = {
  for (var preset in puidPresets)
    preset.code: preset
};
final puidCodes = puidPresets.map((e) => e.code).toList();
final List<PuidPreset> variablePuidPresets = [
  const PuidPreset("app::EntityLayout"),
  const PuidPreset("hap::Action"),
  const PuidPreset("hap::Hap"),
  const PuidPreset("hap::GroupImpl"),
];
