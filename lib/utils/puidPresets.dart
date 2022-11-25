
import 'dart:async';

import '../background/IdLookup.dart';

class PuidPreset {
  final String code;
  final FutureOr<List<String>> Function()? getOptions;

  const PuidPreset(this.code, [this.getOptions]);
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
final List<PuidPreset> variablePuidPresets = [
  const PuidPreset("app::EntityLayout"),
  const PuidPreset("hap::Action"),
  const PuidPreset("hap::Hap"),
  const PuidPreset("hap::GroupImpl"),
];
