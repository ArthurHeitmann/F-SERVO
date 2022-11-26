
import 'dart:async';

import '../background/IdLookup.dart';
import '../widgets/propEditors/simpleProps/textFieldAutocomplete.dart';

class ParamPreset {
  final String name;
  final String code;
  final String defaultValue;
  final FutureOr<Iterable<AutocompleteConfig>> Function()? body;

  const ParamPreset(this.name, this.code, this.defaultValue, [this.body]);
}

final paramPresets = [
  ParamPreset("NameTag", "sys::String", "name", () async {
    var names = await idLookup.getAllCharNames();
    return names.map((n) {
      var eng = n.nameTranslations["ENG"];
      if (eng?.isEmpty == true)
        eng = null;
      var pretty = "${n.key} ${eng != null ? "($eng)" : ""}";
      return AutocompleteConfig(
        pretty,
        displayText: pretty,
        insertText: n.key,
      );
    });
  }),
  const ParamPreset("Lv", "int", "20"),
  const ParamPreset("Lv_B", "int", "30"),
  const ParamPreset("Lv_C", "int", "40"),
  const ParamPreset("Lv_D", "int", "50"),
  const ParamPreset("LOOK", "bool", "1"),
  const ParamPreset("NO_HACK", "bool", "1"),
  const ParamPreset("NO_SCARE", "bool", "1"),
  const ParamPreset("HP_MIN", "float", "0.2"),
  const ParamPreset("HP_BAR_OFF", "bool", "1"),
  const ParamPreset("wait", "int", "60"),
  const ParamPreset("ItemTable", "unsigned int", "0x0"),
  const ParamPreset("puid", "app::RoutePuid", "[PUID]"),
  ParamPreset("codeName", "sys::String", "ft_BK", () => _codeNames.map((n) => AutocompleteConfig(n))),
  const ParamPreset("enable_damage", "bool", "1"),
  const ParamPreset("speedRate", "float", "0.5"),
  const ParamPreset("ANIM_FRAME", "float", "0.5"),
  const ParamPreset("EVENT_AUTO_KILL　bool", "bool", "1"),
  const ParamPreset("hp", "int", "2000"),
  const ParamPreset("EMP", "float", "0.5"),
  const ParamPreset("hac", "sys::String", "M0010S0140b_SYSTEMHACK_1"),
  const ParamPreset("Target_ON", "bool", "1"),
  const ParamPreset("route1", "app::RoutePuid", "[PUID]"),
  const ParamPreset("dirPath", "bool", "1"),
  const ParamPreset("WALL_TALK", "bool", "1"),
  const ParamPreset("SUPER_ARMOR", "bool", "1"),
  const ParamPreset("CAPTION_NO_STOP", "bool", "1"),
  const ParamPreset("length", "float", "300"),
  const ParamPreset("frame", "int", "5"),
  const ParamPreset("radius", "float", "10"),
];

final paramPresetsMap = {
  for (var p in paramPresets)
    p.name: p,
};

const paramCodes = [
  "sys::String",
  "int",
  "float",
  "bool",
  "unsigned int",
  "app::RoutePuid",
];

const _codeNames = [
  "ft_CRb",
  "ft_CC",
  "ft_CS",
  "ft_RME",
  "ft_BK",
  "ft_RC",
  "ft_AP",
  "ft_PV",
  "ft_DD",
  "ft_DI",
  "ft_DO",
  "ft_DC",
  "ft_FC",
  "ft_FC2",
  "ft_FC3",
  "ft_SC",
  "ft_AS",
  "ft_RMI",
  "ft_RMI2",
];
