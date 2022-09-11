import 'dart:convert';
import 'dart:math';

import 'package:crclib/catalog.dart';
import 'package:uuid/uuid.dart';

import 'fileTypeUtils/yax/japToEng.dart';
import 'stateManagement/miscValues.dart';

final uuidGen = Uuid();

enum HorizontalDirection { left, right }

T clamp<T extends num> (T value, T minVal, T maxVal) {
  return max(min(value, maxVal), minVal);
}

const double titleBarHeight = 25;

String tryToTranslate(String jap) {
  if (!shouldAutoTranslate.value)
    return jap;
  var eng = japToEng[jap];
  return eng ?? jap;
}

int crc32(String str) {
  return Crc32().convert(utf8.encode(str)).toBigInt().toInt();
}

bool isInt(String str) {
  return int.tryParse(str) != null;
}

bool isHexInt(String str) {
  return str.startsWith("0x") && int.tryParse(str, radix: 16) != null;
}

bool isDouble(String str) {
  return double.tryParse(str) != null;
}

bool isVector(String str) {
 return str.split(" ").every((val) => isDouble(val));
}
