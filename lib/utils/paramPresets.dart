
class ParamPreset {
  final String name;
  final String code;
  final String defaultValue;

  const ParamPreset(this.name, this.code, this.defaultValue);
}

const paramPresets = [
  ParamPreset("NameTag", "sys::String", "name"),
  ParamPreset("Lv", "int", "20"),
  ParamPreset("Lv_B", "int", "30"),
  ParamPreset("Lv_C", "int", "40"),
  ParamPreset("Lv_D", "int", "50"),
  ParamPreset("LOOK", "bool", "1"),
  ParamPreset("NO_HACK", "bool", "1"),
  ParamPreset("NO_SCARE", "bool", "1"),
  ParamPreset("HP_MIN", "float", "0.2"),
  ParamPreset("HP_BAR_OFF", "bool", "1"),
  ParamPreset("wait", "int", "60"),
  ParamPreset("ItemTable", "unsigned int", "0x0"),
  ParamPreset("puid", "app::RoutePuid", "[PUID]"),
  ParamPreset("codeName", "sys::String", "ft_BK"),
  ParamPreset("enable_damage", "bool", "1"),
  ParamPreset("speedRate", "float", "0.5"),
  ParamPreset("ANIM_FRAME", "float", "0.5"),
  ParamPreset("EVENT_AUTO_KILL　bool", "bool", "1"),
  ParamPreset("hp", "int", "2000"),
  ParamPreset("EMP", "float", "0.5"),
  ParamPreset("hac", "sys::String", "M0010S0140b_SYSTEMHACK_1"),
  ParamPreset("Target_ON", "bool", "1"),
  ParamPreset("route1", "app::RoutePuid", "[PUID]"),
  ParamPreset("dirPath", "bool", "1"),
  ParamPreset("WALL_TALK", "bool", "1"),
  ParamPreset("SUPER_ARMOR", "bool", "1"),
  ParamPreset("CAPTION_NO_STOP", "bool", "1"),
  ParamPreset("length", "float", "300"),
  ParamPreset("frame", "int", "5"),
  ParamPreset("radius", "float", "10"),
];
