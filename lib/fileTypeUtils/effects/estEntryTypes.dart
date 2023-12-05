

import 'dart:typed_data';

import '../utils/ByteDataWrapper.dart';
import 'estIO.dart';

enum EstTypeName {
  PART ("PART"),
  MOVE ("MOVE"),
  EMIF ("EMIF"),
  TEX  ("TEX "),
  SZSA ("SZSA"),
  PSSA ("PSSA"),
  RTSA ("RTSA"),
  FVWK ("FVWK"),
  FWK  ("FWK "),
  EMMV ("EMMV"),
  EMSA ("EMSA"),
  EMPA ("EMPA"),
  EMRA ("EMRA"),
  EMFV ("EMFV"),
  EMFW ("EMFW"),
  TSC  ("TSC "),
  TSM  ("TSM "),
  TSN  ("TSN "),
  REND ("REND"),
  MJSG ("MJSG"),
  MJCM ("MJCM"),
  MJNM ("MJNM"),
  MJMM ("MJMM"),
  MJDT ("MJDT"),
  MJFN ("MJFN"),
  MJVA ("MJVA");

  final String name;

  const EstTypeName(this.name);
}

final estTypeFullNames = {
  EstTypeName.PART.name: "EffectParticleGenerationData",
  EstTypeName.MOVE.name: "EffectMoveData",
  EstTypeName.EMIF.name: "EffectEmitterData",
  EstTypeName.TEX.name: "EffectTextureInfoData",
  EstTypeName.SZSA.name: "EffectSizeSinAnimation",
  EstTypeName.PSSA.name: "EffectPosSinAnimation",
  EstTypeName.RTSA.name: "EffectRotSinAnimation",
  EstTypeName.FVWK.name: "EffectFreeVecWork",
  EstTypeName.FWK.name: "EffectFreeWork",
  EstTypeName.EMMV.name: "EffectEmitterMoveData",
  EstTypeName.EMSA.name: "Emitter_EffectSizeSinAnimation",
  EstTypeName.EMPA.name: "Emitter_EffectPosSinAnimation",
  EstTypeName.EMRA.name: "Emitter_EffectRotSinAnimation",
  EstTypeName.EMFV.name: "Emitter_EffectFreeVecWork",
  EstTypeName.EMFW.name: "Emitter_EffectFreeWork",
  EstTypeName.TSC.name: "EffectTextureSettingColor",
  EstTypeName.TSM.name: "EffectTextureSettingMask",
  EstTypeName.TSN.name: "EffectTextureSettingNormal",
  EstTypeName.REND.name: "EffectRenderSetting",
  EstTypeName.MJSG.name: "ModelShaderJackSettingData",
  EstTypeName.MJCM.name: "ModelShaderColorMap",
  EstTypeName.MJNM.name: "ModelShaderNormalMap",
  EstTypeName.MJMM.name: "ModelShaderMaskMap",
  EstTypeName.MJDT.name: "ModelShaderJackDistortionData",
  EstTypeName.MJFN.name: "ModelShaderJackFresnelData",
  EstTypeName.MJVA.name: "ModelShaderJackVertexAnimation",
};

final Map<String, EstTypeEntry Function(ByteDataWrapper, EstTypeHeader)> estTypeFactories = {
  EstTypeName.PART.name: EstTypePartEntry.read,
  EstTypeName.MOVE.name: EstTypeMoveEntry.read,
  EstTypeName.EMIF.name: EstTypeEmifEntry.read,
  EstTypeName.TEX.name: EstTypeTexEntry.read,
  EstTypeName.FWK.name: EstTypeFwkEntry.read,
  EstTypeName.EMMV.name: EstTypeEmmvEntry.read,
  EstTypeName.MJCM.name: EstTypeMjcmEntry.read,
};

class EstUnknownTypeEntry extends EstTypeEntry {
  late Uint8List data;

  EstUnknownTypeEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    data = bytes.asUint8List(header.size);
  }

  @override
  void write(ByteDataWrapper bytes) {
    for (var byte in data)
      bytes.writeUint8(byte);
  }
}

/*
typedef struct {
	int16   u_a;
	int16   u_b;
	uint32  u_c <format=hex>;
	uint32  u_d;
	int16   u_e[8];
	uint32  uf[9];
} part_s; 
*/
/// EffectParticleGenerationData
class EstTypePartEntry extends EstTypeEntry {
  late int u_a;
  late int u_b;
  late int u_c;
  late int u_d;
  late List<int> u_e;
  late List<int> uf;

  EstTypePartEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    u_a = bytes.readInt16();
    u_b = bytes.readInt16();
    u_c = bytes.readUint32();
    u_d = bytes.readUint32();
    u_e = bytes.asInt16List(8);
    uf = bytes.asUint32List(9);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeInt16(u_a);
    bytes.writeInt16(u_b);
    bytes.writeUint32(u_c);
    bytes.writeUint32(u_d);
    for (var e in u_e)
      bytes.writeInt16(e);
    for (var f in uf)
      bytes.writeUint32(f);
  }
}

/*
typedef struct {
	uint32  u_a;
	float   offset_x;
	float   offset_y;
	float   offset_z;
	float   unk_1;
	float   top_pos_1;
	float   right_pos_1;
	float   move_speed_x;
	float   move_speed_y;
	float   move_speed_z;
	float   move_small_speed_x;
	float   move_small_speed_y;
	float   move_small_speed_z;
	float   u_b_1[6];
	float   angle;
	float   u_b_2[13];
	float   scale;
	float   u_c[16];
	float   red;
	float   green;
	float   blue;
	float   alpha;//intensity?
		float   u_d_1[4];
	int16   unk_2;
	int16   SmoothAppearance;
	float effect_size_limit_1;
	float effect_size_limit_2;
	float effect_size_limit_3;
	float effect_size_limit_4;
	float SmoothDisappearance;
	float   u_d_2[32];
} move_s;
*/
/// EffectMoveData
class EstTypeMoveEntry extends EstTypeEntry {
  late int u_a;
  late double offset_x;
  late double offset_y;
  late double offset_z;
  late double unk_1;
  late double top_pos_1;
  late double right_pos_1;
  late double move_speed_x;
  late double move_speed_y;
  late double move_speed_z;
  late double move_small_speed_x;
  late double move_small_speed_y;
  late double move_small_speed_z;
  late List<double> u_b_1;
  late double angle;
  late List<double> u_b_2;
  late double scaleX;
  late double scaleY;
  late double scaleZ;
  late List<double> u_c;
  late double red;
  late double green;
  late double blue;
  late double alpha;
  late List<double> u_d_1;
  late double smoothAppearance;
  late double effect_size_limit_1;
  late double effect_size_limit_2;
  late double effect_size_limit_3;
  late double effect_size_limit_4;
  late double smoothDisappearance;
  late List<double> u_d_2;

  EstTypeMoveEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    u_a = bytes.readUint32();
    offset_x = bytes.readFloat32();
    offset_y = bytes.readFloat32();
    offset_z = bytes.readFloat32();
    unk_1 = bytes.readFloat32();
    top_pos_1 = bytes.readFloat32();
    right_pos_1 = bytes.readFloat32();
    move_speed_x = bytes.readFloat32();
    move_speed_y = bytes.readFloat32();
    move_speed_z = bytes.readFloat32();
    move_small_speed_x = bytes.readFloat32();
    move_small_speed_y = bytes.readFloat32();
    move_small_speed_z = bytes.readFloat32();
    u_b_1 = bytes.readFloat32List(6);
    angle = bytes.readFloat32();
    u_b_2 = bytes.readFloat32List(12);
    scaleX = bytes.readFloat32();
    scaleY = bytes.readFloat32();
    scaleZ = bytes.readFloat32();
    u_c = bytes.readFloat32List(15);
    red = bytes.readFloat32();
    green = bytes.readFloat32();
    blue = bytes.readFloat32();
    alpha = bytes.readFloat32();
    u_d_1 = bytes.readFloat32List(4);
    smoothAppearance = bytes.readFloat32();
    effect_size_limit_1 = bytes.readFloat32();
    effect_size_limit_2 = bytes.readFloat32();
    effect_size_limit_3 = bytes.readFloat32();
    effect_size_limit_4 = bytes.readFloat32();
    smoothDisappearance = bytes.readFloat32();
    u_d_2 = bytes.readFloat32List(32);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(u_a);
    bytes.writeFloat32(offset_x);
    bytes.writeFloat32(offset_y);
    bytes.writeFloat32(offset_z);
    bytes.writeFloat32(unk_1);
    bytes.writeFloat32(top_pos_1);
    bytes.writeFloat32(right_pos_1);
    bytes.writeFloat32(move_speed_x);
    bytes.writeFloat32(move_speed_y);
    bytes.writeFloat32(move_speed_z);
    bytes.writeFloat32(move_small_speed_x);
    bytes.writeFloat32(move_small_speed_y);
    bytes.writeFloat32(move_small_speed_z);
    for (var b in u_b_1)
      bytes.writeFloat32(b);
    bytes.writeFloat32(angle);
    for (var b in u_b_2)
      bytes.writeFloat32(b);
    bytes.writeFloat32(scaleX);
    bytes.writeFloat32(scaleY);
    bytes.writeFloat32(scaleZ);
    for (var c in u_c)
      bytes.writeFloat32(c);
    bytes.writeFloat32(red);
    bytes.writeFloat32(green);
    bytes.writeFloat32(blue);
    bytes.writeFloat32(alpha);
    for (var d in u_d_1)
      bytes.writeFloat32(d);
    bytes.writeFloat32(smoothAppearance);
    bytes.writeFloat32(effect_size_limit_1);
    bytes.writeFloat32(effect_size_limit_2);
    bytes.writeFloat32(effect_size_limit_3);
    bytes.writeFloat32(effect_size_limit_4);
    bytes.writeFloat32(smoothDisappearance);
    for (var d in u_d_2)
      bytes.writeFloat32(d);
  }
}

/*
typedef struct {
	int16 count;
	int16 u_a;
	int16 u_a;
	int16 u_a;
	int16 play_delay;
	int16 ShowAtOnce;
	int16 size;
	int16 unk;
	float u_b[8];
} emif_s;
*/
/// EffectEmitterData
class EstTypeEmifEntry extends EstTypeEntry {
  late int count;
  late int u_a;
  late int u_b;
  late int u_c;
  late int play_delay;
  late int showAtOnce;
  late int size;
  late int unk;
  late List<double> u_d;

  EstTypeEmifEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    count = bytes.readInt16();
    u_a = bytes.readInt16();
    u_b = bytes.readInt16();
    u_c = bytes.readInt16();
    play_delay = bytes.readInt16();
    showAtOnce = bytes.readInt16();
    size = bytes.readInt16();
    unk = bytes.readInt16();
    u_d = bytes.readFloat32List(8);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeInt16(count);
    bytes.writeInt16(u_a);
    bytes.writeInt16(u_b);
    bytes.writeInt16(u_c);
    bytes.writeInt16(play_delay);
    bytes.writeInt16(showAtOnce);
    bytes.writeInt16(size);
    bytes.writeInt16(unk);
    for (var d in u_d)
      bytes.writeFloat32(d);
  }
}

/*
typedef struct {
	float speed;
	int16 coreeff_texture_file;
	int16 u_c;
	float size;
	float u_d[3];
	struct {
		float u_d1;
		int16 u_e;
		byte  coreeff_texture_file_index;
		byte  u_f;
		float u_g;
		char  u_h[4];
		float u_i[15];
	} substruct[2];
} tex_s;
*/
/// EffectTextureInfoData
class EstTypeTexEntry extends EstTypeEntry {
  late double speed;
  late int coreeff_texture_file;
  late int u_c;
  late double size;
  late List<double> u_d;
  late List<EstTypeTexSubEntry> substruct;

  EstTypeTexEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    speed = bytes.readFloat32();
    coreeff_texture_file = bytes.readInt16();
    u_c = bytes.readInt16();
    size = bytes.readFloat32();
    u_d = bytes.readFloat32List(3);
    substruct = [];
    for (var i = 0; i < 2; i++) {
      substruct.add(EstTypeTexSubEntry.read(bytes));
    }
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(speed);
    bytes.writeInt16(coreeff_texture_file);
    bytes.writeInt16(u_c);
    bytes.writeFloat32(size);
    for (var d in u_d)
      bytes.writeFloat32(d);
    for (var sub in substruct)
      sub.write(bytes);
  }
}
class EstTypeTexSubEntry {
  late double u_d1;
  late int u_e;
  late int coreeff_texture_file_index;
  late int u_f;
  late double u_g;
  late List<int> u_h;
  late List<double> u_i;

  EstTypeTexSubEntry.read(ByteDataWrapper bytes) {
    u_d1 = bytes.readFloat32();
    u_e = bytes.readInt16();
    coreeff_texture_file_index = bytes.readUint8();
    u_f = bytes.readUint8();
    u_g = bytes.readFloat32();
    u_h = bytes.asUint8List(4);
    u_i = bytes.readFloat32List(15);
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(u_d1);
    bytes.writeInt16(u_e);
    bytes.writeUint8(coreeff_texture_file_index);
    bytes.writeUint8(u_f);
    bytes.writeFloat32(u_g);
    for (var h in u_h)
      bytes.writeUint8(h);
    for (var i in u_i)
      bytes.writeFloat32(i);
  }
}

/*
typedef struct {
	int16 effect_id_on_objects;
	int16 tex_num1;
	int16 tex_num2;
	int16 tex_num3;
	int16 left_pos_1;
	int16 left_pos_2;
	int32 u_c[5];
} fwk_s;
*/
/// EffectFreeWork
class EstTypeFwkEntry extends EstTypeEntry {
  late int effect_id_on_objects;
  late int tex_num1;
  late int tex_num2;
  late int tex_num3;
  late int left_pos_1;
  late int left_pos_2;
  late List<int> u_c;

  EstTypeFwkEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    effect_id_on_objects = bytes.readInt16();
    tex_num1 = bytes.readInt16();
    tex_num2 = bytes.readInt16();
    tex_num3 = bytes.readInt16();
    left_pos_1 = bytes.readInt16();
    left_pos_2 = bytes.readInt16();
    u_c = bytes.asUint32List(5);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeInt16(effect_id_on_objects);
    bytes.writeInt16(tex_num1);
    bytes.writeInt16(tex_num2);
    bytes.writeInt16(tex_num3);
    bytes.writeInt16(left_pos_1);
    bytes.writeInt16(left_pos_2);
    for (var c in u_c)
      bytes.writeUint32(c);
  }
}

/*
typedef struct {
	uint32 u_a;
	float left_pos1;
	float top_pos;
	float unk_pos1;
	float random_pos1;
	float top_bottom_random_pos1;
	float front_back_random_pos1;
	float left_pos2;
	float front_pos1;
	float front_pos2;
	float left_right_random_pos1;
	float random_pos2;
	float front_back_random_pos2;
	float unk_pos2;
	float left_pos_random1;
	float top_pos2;
	float front_pos3;
	float unk_pos3;
	float unk_pos4;
	float unk_pos5;
	float unk_pos6;
	float unk_pos7;
	float unk_pos8;
	float unk_pos9;
	float unk_pos10;
	float unk_pos11;
	float unk_pos25;
	float unk_pos26;
	float unk_pos27;
	float unk_pos28;
	float unk_pos29;
	float unk_pos30;
	float unk_pos31;
	float effect_size;
	float u_b_1[16];  
	float sword_pos;
	float u_b_2[57]; 
} emmv_s;
*/
/// EffectEmitterMoveData
class EstTypeEmmvEntry extends EstTypeEntry {
  late int u_a;
  late double left_pos1;
  late double top_pos;
  late double unk_pos1;
  late double random_pos1;
  late double top_bottom_random_pos1;
  late double front_back_random_pos1;
  late double left_pos2;
  late double front_pos1;
  late double front_pos2;
  late double left_right_random_pos1;
  late double random_pos2;
  late double front_back_random_pos2;
  late double unk_pos2;
  late double left_pos_random1;
  late double top_pos2;
  late double front_pos3;
  late double unk_pos3;
  late double unk_pos4;
  late double unk_pos5;
  late double unk_pos6;
  late double unk_pos7;
  late double unk_pos8;
  late double unk_pos9;
  late double unk_pos10;
  late double unk_pos11;
  late double unk_pos25;
  late double unk_pos26;
  late double unk_pos27;
  late double unk_pos28;
  late double unk_pos29;
  late double unk_pos30;
  late double unk_pos31;
  late double effect_size;
  late List<double> u_b_1;
  late double sword_pos;
  late List<double> u_b_2;

  EstTypeEmmvEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    u_a = bytes.readUint32();
    left_pos1 = bytes.readFloat32();
    top_pos = bytes.readFloat32();
    unk_pos1 = bytes.readFloat32();
    random_pos1 = bytes.readFloat32();
    top_bottom_random_pos1 = bytes.readFloat32();
    front_back_random_pos1 = bytes.readFloat32();
    left_pos2 = bytes.readFloat32();
    front_pos1 = bytes.readFloat32();
    front_pos2 = bytes.readFloat32();
    left_right_random_pos1 = bytes.readFloat32();
    random_pos2 = bytes.readFloat32();
    front_back_random_pos2 = bytes.readFloat32();
    unk_pos2 = bytes.readFloat32();
    left_pos_random1 = bytes.readFloat32();
    top_pos2 = bytes.readFloat32();
    front_pos3 = bytes.readFloat32();
    unk_pos3 = bytes.readFloat32();
    unk_pos4 = bytes.readFloat32();
    unk_pos5 = bytes.readFloat32();
    unk_pos6 = bytes.readFloat32();
    unk_pos7 = bytes.readFloat32();
    unk_pos8 = bytes.readFloat32();
    unk_pos9 = bytes.readFloat32();
    unk_pos10 = bytes.readFloat32();
    unk_pos11 = bytes.readFloat32();
    unk_pos25 = bytes.readFloat32();
    unk_pos26 = bytes.readFloat32();
    unk_pos27 = bytes.readFloat32();
    unk_pos28 = bytes.readFloat32();
    unk_pos29 = bytes.readFloat32();
    unk_pos30 = bytes.readFloat32();
    unk_pos31 = bytes.readFloat32();
    effect_size = bytes.readFloat32();
    u_b_1 = bytes.readFloat32List(16);
    sword_pos = bytes.readFloat32();
    u_b_2 = bytes.readFloat32List(57);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(u_a);
    bytes.writeFloat32(left_pos1);
    bytes.writeFloat32(top_pos);
    bytes.writeFloat32(unk_pos1);
    bytes.writeFloat32(random_pos1);
    bytes.writeFloat32(top_bottom_random_pos1);
    bytes.writeFloat32(front_back_random_pos1);
    bytes.writeFloat32(left_pos2);
    bytes.writeFloat32(front_pos1);
    bytes.writeFloat32(front_pos2);
    bytes.writeFloat32(left_right_random_pos1);
    bytes.writeFloat32(random_pos2);
    bytes.writeFloat32(front_back_random_pos2);
    bytes.writeFloat32(unk_pos2);
    bytes.writeFloat32(left_pos_random1);
    bytes.writeFloat32(top_pos2);
    bytes.writeFloat32(front_pos3);
    bytes.writeFloat32(unk_pos3);
    bytes.writeFloat32(unk_pos4);
    bytes.writeFloat32(unk_pos5);
    bytes.writeFloat32(unk_pos6);
    bytes.writeFloat32(unk_pos7);
    bytes.writeFloat32(unk_pos8);
    bytes.writeFloat32(unk_pos9);
    bytes.writeFloat32(unk_pos10);
    bytes.writeFloat32(unk_pos11);
    bytes.writeFloat32(unk_pos25);
    bytes.writeFloat32(unk_pos26);
    bytes.writeFloat32(unk_pos27);
    bytes.writeFloat32(unk_pos28);
    bytes.writeFloat32(unk_pos29);
    bytes.writeFloat32(unk_pos30);
    bytes.writeFloat32(unk_pos31);
    bytes.writeFloat32(effect_size);
    for (var b in u_b_1)
      bytes.writeFloat32(b);
    bytes.writeFloat32(sword_pos);
    for (var b in u_b_2)
      bytes.writeFloat32(b);
  }
}

/*
typedef struct {
	int16 size_1;
	int16 size_2;
	int16 u_a_1[6];
	int16 effect_lines_type_maybe;
	int16 unk_1;
	int16 unk_2;
	int16 effect_lines_size_maybe;
	float part_size;
	float move_speed_on_player_x;
	float move_speed_on_player_y;
	float u_a_3[4];
	float move_speed_on_player_z;
	float move_speed;
	float move_speed_acceletarion;
	float u_a_4[4];
} mjcm_s;
*/
/// ModelShaderColorMap
class EstTypeMjcmEntry extends EstTypeEntry {
  late int size_1;
  late int size_2;
  late List<int> u_a_1;
  late int effect_lines_type_maybe;
  late int unk_1;
  late int unk_2;
  late int effect_lines_size_maybe;
  late double part_size;
  late double move_speed_on_player_x;
  late double move_speed_on_player_y;
  late List<double> u_a_3;
  late double move_speed_on_player_z;
  late double move_speed;
  late double move_speed_acceletarion;
  late List<double> u_a_4;

  EstTypeMjcmEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    size_1 = bytes.readInt16();
    size_2 = bytes.readInt16();
    u_a_1 = bytes.asInt16List(6);
    effect_lines_type_maybe = bytes.readInt16();
    unk_1 = bytes.readInt16();
    unk_2 = bytes.readInt16();
    effect_lines_size_maybe = bytes.readInt16();
    part_size = bytes.readFloat32();
    move_speed_on_player_x = bytes.readFloat32();
    move_speed_on_player_y = bytes.readFloat32();
    u_a_3 = bytes.readFloat32List(4);
    move_speed_on_player_z = bytes.readFloat32();
    move_speed = bytes.readFloat32();
    move_speed_acceletarion = bytes.readFloat32();
    u_a_4 = bytes.readFloat32List(4);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeInt16(size_1);
    bytes.writeInt16(size_2);
    for (var a in u_a_1)
      bytes.writeInt16(a);
    bytes.writeInt16(effect_lines_type_maybe);
    bytes.writeInt16(unk_1);
    bytes.writeInt16(unk_2);
    bytes.writeInt16(effect_lines_size_maybe);
    bytes.writeFloat32(part_size);
    bytes.writeFloat32(move_speed_on_player_x);
    bytes.writeFloat32(move_speed_on_player_y);
    for (var a in u_a_3)
      bytes.writeFloat32(a);
    bytes.writeFloat32(move_speed_on_player_z);
    bytes.writeFloat32(move_speed);
    bytes.writeFloat32(move_speed_acceletarion);
    for (var a in u_a_4)
      bytes.writeFloat32(a);
  }
}
