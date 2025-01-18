

// ignore_for_file: non_constant_identifier_names

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
  EstTypeName.FVWK.name: EstTypeFvwkEntry.read,
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
	int16   effect_length;
	uint32  u_c <format=hex>;
	uint32  u_d;
	int16   anchor_bone;
	int16   u_e[7];
	uint32  uf[9];
} part_s; 
*/
/// EffectParticleGenerationData
class EstTypePartEntry extends EstTypeEntry {
  late int u_a;
  late int effect_length;
  late int u_c;
  late int u_d;
  late int anchor_bone;
  late List<int> u_e;
  late List<int> uf;

  EstTypePartEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    u_a = bytes.readInt16();
    effect_length = bytes.readInt16();
    u_c = bytes.readUint32();
    u_d = bytes.readUint32();
    anchor_bone = bytes.readInt16();
    u_e = bytes.asInt16List(7);
    uf = bytes.asUint32List(9);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeInt16(u_a);
    bytes.writeInt16(effect_length);
    bytes.writeUint32(u_c);
    bytes.writeUint32(u_d);
    bytes.writeInt16(anchor_bone);
    for (var e in u_e)
      bytes.writeInt16(e);
    for (var f in uf)
      bytes.writeUint32(f);
  }
}

/*
typedef struct {
	uint32 u_a;
	float offset_x;
	float offset_y;
	float offset_z;
	float spawn_area_width;
	float spawn_area_height;
	float spawn_area_depth;
	float move_speed_x;
	float move_speed_y;
	float move_speed_z;
	float move_small_speed_x;
	float move_small_speed_y;
	float move_small_speed_z;
	float u_b_1[6];
	float angle;
	float u_b_2[12];
	float scale1;
	float scale2;
	float scale3;
	float u_c[15];
	float red;
	float green;
	float blue;
	float alpha;
	float u_d_1[4];
	float fadeInSpeed;
	float effect_size_limit_1;
	float effect_size_limit_2;
	float effect_size_limit_3;
	float effect_size_limit_4;
	float fadeOutSpeed;
	float u_d_2[32];
} move_s;
*/
/// EffectMoveData
class EstTypeMoveEntry extends EstTypeEntry {
  late int u_a;
  late double offset_x;
  late double offset_y;
  late double offset_z;
  late double spawn_area_width;
  late double spawn_area_height;
  late double spawn_area_depth;
  late double move_speed_x;
  late double move_speed_y;
  late double move_speed_z;
  late double move_speed_range_x;
  late double move_speed_range_y;
  late double move_speed_range_z;
  late List<double> u_b_1;
  late double angle;
  late List<double> u_b_2;
  late double scale1;
  late double scale2;
  late double scale3;
  late List<double> u_c;
  late double red;
  late double green;
  late double blue;
  late double alpha;
  late List<double> u_d_1;
  late double fadeInSpeed;
  late double effect_size_limit_1;
  late double effect_size_limit_2;
  late double effect_size_limit_3;
  late double effect_size_limit_4;
  late double fadeOutSpeed;
  late List<double> u_d_2;

  EstTypeMoveEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    u_a = bytes.readUint32();
    offset_x = bytes.readFloat32();
    offset_y = bytes.readFloat32();
    offset_z = bytes.readFloat32();
    spawn_area_width = bytes.readFloat32();
    spawn_area_height = bytes.readFloat32();
    spawn_area_depth = bytes.readFloat32();
    move_speed_x = bytes.readFloat32();
    move_speed_y = bytes.readFloat32();
    move_speed_z = bytes.readFloat32();
    move_speed_range_x = bytes.readFloat32();
    move_speed_range_y = bytes.readFloat32();
    move_speed_range_z = bytes.readFloat32();
    u_b_1 = bytes.readFloat32List(6);
    angle = bytes.readFloat32();
    u_b_2 = bytes.readFloat32List(12);
    scale1 = bytes.readFloat32();
    scale2 = bytes.readFloat32();
    scale3 = bytes.readFloat32();
    u_c = bytes.readFloat32List(15);
    red = bytes.readFloat32();
    green = bytes.readFloat32();
    blue = bytes.readFloat32();
    alpha = bytes.readFloat32();
    u_d_1 = bytes.readFloat32List(4);
    fadeInSpeed = bytes.readFloat32();
    effect_size_limit_1 = bytes.readFloat32();
    effect_size_limit_2 = bytes.readFloat32();
    effect_size_limit_3 = bytes.readFloat32();
    effect_size_limit_4 = bytes.readFloat32();
    fadeOutSpeed = bytes.readFloat32();
    u_d_2 = bytes.readFloat32List(32);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(u_a);
    bytes.writeFloat32(offset_x);
    bytes.writeFloat32(offset_y);
    bytes.writeFloat32(offset_z);
    bytes.writeFloat32(spawn_area_width);
    bytes.writeFloat32(spawn_area_height);
    bytes.writeFloat32(spawn_area_depth);
    bytes.writeFloat32(move_speed_x);
    bytes.writeFloat32(move_speed_y);
    bytes.writeFloat32(move_speed_z);
    bytes.writeFloat32(move_speed_range_x);
    bytes.writeFloat32(move_speed_range_y);
    bytes.writeFloat32(move_speed_range_z);
    for (var b in u_b_1)
      bytes.writeFloat32(b);
    bytes.writeFloat32(angle);
    for (var b in u_b_2)
      bytes.writeFloat32(b);
    bytes.writeFloat32(scale1);
    bytes.writeFloat32(scale2);
    bytes.writeFloat32(scale3);
    for (var c in u_c)
      bytes.writeFloat32(c);
    bytes.writeFloat32(red);
    bytes.writeFloat32(green);
    bytes.writeFloat32(blue);
    bytes.writeFloat32(alpha);
    for (var d in u_d_1)
      bytes.writeFloat32(d);
    bytes.writeFloat32(fadeInSpeed);
    bytes.writeFloat32(effect_size_limit_1);
    bytes.writeFloat32(effect_size_limit_2);
    bytes.writeFloat32(effect_size_limit_3);
    bytes.writeFloat32(effect_size_limit_4);
    bytes.writeFloat32(fadeOutSpeed);
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
  late int instance_duplicate_count;
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
    instance_duplicate_count = bytes.readInt16();
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
    bytes.writeInt16(instance_duplicate_count);
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
	float u_a;
	int16 texture_file_id;
	int16 u_c;
	float u_d1;
	float u_d2;
	float u_d3;
	float u_d4;
	float u_d5;
	int16 video_fps_maybe;
	byte  texture_file_texture_index;
	byte  is_single_frame;
	float u_g;
	int16  frame_offset;
	int16  u_h;
	float distortion_effect_strength;
	uint16 mesh_id<format=hex>;
	uint16 mesh_i1<format=hex>;
	float u_i2[8];
	uint32 u_i3<format=hex>;
	float u_i4[4];
	float u_j;
	float brightness;
	float u_n;
	float u_o;
	uint32 u_p<format=hex>;
	uint32 u_q<format=hex>;
	uint32 u_r<format=hex>;
	float u_s[12];
} tex_s;
*/
/// EffectTextureInfoData
class EstTypeTexEntry extends EstTypeEntry {
  late double speed;
  late int texture_file_id;
  late int u_c;
  late double size;
  late double u_d2;
  late double u_d3;
  late double left_right_distribution;
  late double up_down_distribution;
  late int video_fps_maybe;
  late int texture_file_texture_index;
  late int is_single_frame;
  late double u_g;
  late int frame_offset;
  late int u_h;
  late double distortion_effect_strength;
  late int mesh_id;
  late int mesh_i1;
  late List<double> u_i2;
  late int u_i3;
  late List<double> u_i4;
  late double u_j;
  late double brightness;
  late double u_n;
  late double u_o;
  late int u_p;
  late int u_q;
  late int u_r;
  late List<double> u_s;

  EstTypeTexEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    speed = bytes.readFloat32();
    texture_file_id = bytes.readInt16();
    u_c = bytes.readInt16();
    size = bytes.readFloat32();
    u_d2 = bytes.readFloat32();
    u_d3 = bytes.readFloat32();
    left_right_distribution = bytes.readFloat32();
    up_down_distribution = bytes.readFloat32();
    video_fps_maybe = bytes.readInt16();
    texture_file_texture_index = bytes.readUint8();
    is_single_frame = bytes.readUint8();
    u_g = bytes.readFloat32();
    frame_offset = bytes.readInt16();
    u_h = bytes.readInt16();
    distortion_effect_strength = bytes.readFloat32();
    mesh_id = bytes.readUint16();
    mesh_i1 = bytes.readUint16();
    u_i2 = bytes.readFloat32List(8);
    u_i3 = bytes.readUint32();
    u_i4 = bytes.readFloat32List(4);
    u_j = bytes.readFloat32();
    brightness = bytes.readFloat32();
    u_n = bytes.readFloat32();
    u_o = bytes.readFloat32();
    u_p = bytes.readUint32();
    u_q = bytes.readUint32();
    u_r = bytes.readUint32();
    u_s = bytes.readFloat32List(12);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(speed);
    bytes.writeInt16(texture_file_id);
    bytes.writeInt16(u_c);
    bytes.writeFloat32(size);
    bytes.writeFloat32(u_d2);
    bytes.writeFloat32(u_d3);
    bytes.writeFloat32(left_right_distribution);
    bytes.writeFloat32(up_down_distribution);
    bytes.writeInt16(video_fps_maybe);
    bytes.writeUint8(texture_file_texture_index);
    bytes.writeUint8(is_single_frame);
    bytes.writeFloat32(u_g);
    bytes.writeInt16(frame_offset);
    bytes.writeInt16(u_h);
    bytes.writeFloat32(distortion_effect_strength);
    bytes.writeUint16(mesh_id);
    bytes.writeUint16(mesh_i1);
    for (var i in u_i2)
      bytes.writeFloat32(i);
    bytes.writeUint32(u_i3);
    for (var i in u_i4)
      bytes.writeFloat32(i);
    bytes.writeFloat32(u_j);
    bytes.writeFloat32(brightness);
    bytes.writeFloat32(u_n);
    bytes.writeFloat32(u_o);
    bytes.writeUint32(u_p);
    bytes.writeUint32(u_q);
    bytes.writeUint32(u_r);
    for (var s in u_s)
      bytes.writeFloat32(s);
  }
}

/*
typedef struct {
	float init_rotation_range;
	float base_rotation_speed;
	float base_rotation_speed_range;
	float x_wiggle_range;
	float x_wiggle_period_seconds;
	float y_wiggle_speed;
	float y_wiggle_speed_range;
	float z_wiggle_range;
	float z_wiggle_period_seconds;
	float u_9;
	float u_10;
	float u_11;
	float u_12;
	float x_repeat_instance_offset_max_range;
	float y_repeat_instance_offset_max_range;
	float z_repeat_instance_offset_max_range;
	float u_16;
	float u_17;
	float u_18;
	float u_19;
} fvwk_s <bgcolor = 0x00F0FF00>;
*/
/// EffectFreeVecWork
class EstTypeFvwkEntry extends EstTypeEntry {
  late double init_rotation_range;
  late double base_rotation_speed;
  late double base_rotation_speed_range;
  late double x_wiggle_range;
  late double x_wiggle_speed;
  late double y_wiggle_range;
  late double y_wiggle_speed;
  late double z_wiggle_range;
  late double z_wiggle_speed;
  late double u_9;
  late double u_10;
  late double u_11;
  late double u_12;
  late double x_repeat_instance_offset_max_range;
  late double y_repeat_instance_offset_max_range;
  late double z_repeat_instance_offset_max_range;
  late double u_16;
  late double u_17;
  late double u_18;
  late double u_19;

  EstTypeFvwkEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    init_rotation_range = bytes.readFloat32();
    base_rotation_speed = bytes.readFloat32();
    base_rotation_speed_range = bytes.readFloat32();
    x_wiggle_range = bytes.readFloat32();
    x_wiggle_speed = bytes.readFloat32();
    y_wiggle_range = bytes.readFloat32();
    y_wiggle_speed = bytes.readFloat32();
    z_wiggle_range = bytes.readFloat32();
    z_wiggle_speed = bytes.readFloat32();
    u_9 = bytes.readFloat32();
    u_10 = bytes.readFloat32();
    u_11 = bytes.readFloat32();
    u_12 = bytes.readFloat32();
    x_repeat_instance_offset_max_range = bytes.readFloat32();
    y_repeat_instance_offset_max_range = bytes.readFloat32();
    z_repeat_instance_offset_max_range = bytes.readFloat32();
    u_16 = bytes.readFloat32();
    u_17 = bytes.readFloat32();
    u_18 = bytes.readFloat32();
    u_19 = bytes.readFloat32();
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(init_rotation_range);
    bytes.writeFloat32(base_rotation_speed);
    bytes.writeFloat32(base_rotation_speed_range);
    bytes.writeFloat32(x_wiggle_range);
    bytes.writeFloat32(x_wiggle_speed);
    bytes.writeFloat32(y_wiggle_range);
    bytes.writeFloat32(y_wiggle_speed);
    bytes.writeFloat32(z_wiggle_range);
    bytes.writeFloat32(z_wiggle_speed);
    bytes.writeFloat32(u_9);
    bytes.writeFloat32(u_10);
    bytes.writeFloat32(u_11);
    bytes.writeFloat32(u_12);
    bytes.writeFloat32(x_repeat_instance_offset_max_range);
    bytes.writeFloat32(y_repeat_instance_offset_max_range);
    bytes.writeFloat32(z_repeat_instance_offset_max_range);
    bytes.writeFloat32(u_16);
    bytes.writeFloat32(u_17);
    bytes.writeFloat32(u_18);
    bytes.writeFloat32(u_19);
  }
}

/*
typedef struct {
	int16 u_a0;
	int16 u_a1;
	int16 imported_effect_id;
	int16 u_b[3];
	int32 u_c[5];
} fwk_s;
*/
/// EffectFreeWork
class EstTypeFwkEntry extends EstTypeEntry {
  late int particle_count;
  late int center_distance;
  late int spawn_radius_or_imported_effect_id;
  late int edge_fade_range;
  late List<int> u_b;
  late List<int> u_c;

  EstTypeFwkEntry.read(ByteDataWrapper bytes, EstTypeHeader header) {
    this.header = header;
    particle_count = bytes.readInt16();
    center_distance = bytes.readInt16();
    spawn_radius_or_imported_effect_id = bytes.readInt16();
    edge_fade_range = bytes.readInt16();
    u_b = bytes.asInt16List(2);
    u_c = bytes.asInt32List(5);
  }

  @override
  void write(ByteDataWrapper bytes) {
    bytes.writeInt16(particle_count);
    bytes.writeInt16(center_distance);
    bytes.writeInt16(spawn_radius_or_imported_effect_id);
    bytes.writeInt16(edge_fade_range);
    for (var b in u_b)
      bytes.writeInt16(b);
    for (var c in u_c)
      bytes.writeInt32(c);
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
