import 'dart:math';

import 'package:uuid/uuid.dart';

final uuidGen = Uuid();

enum HorizontalDirection { left, right }

T clamp<T extends num> (T value, T _min, T _max) {
  return max(min(value, _max), _min);
}
