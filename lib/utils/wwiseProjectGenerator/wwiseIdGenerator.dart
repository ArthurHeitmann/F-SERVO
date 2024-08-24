
import 'dart:math';

import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/v4.dart';

import '../utils.dart';
import 'wwiseProjectGenerator.dart';
import 'wwiseUtils.dart';

class WwiseIdGenerator {
  final UuidV4 _uuid;
  final Random _random;
  final Set<int> _usedIds = {};

  WwiseIdGenerator(String name) :
    _uuid = UuidV4(goptions: GlobalOptions(MathRNG(seed: crc32(name)))),
    _random = Random(crc32(name));
  
  void init(WwiseProjectGenerator project) {
    for (var file in project.soundFiles.values)
      _usedIds.add(file.id);
    for (var group in project.stateGroups.values)
      _usedIds.add(group.id);
    for (var group in project.switchGroups.values)
      _usedIds.add(group.id);
    for (var bus in project.buses.values) {
      _usedIds.add(fnvHash(bus.name));
    }
    for (var chunk in project.hircChunks)
      _usedIds.add(chunk.uid);
  }

  void markIdUsed(int id) {
    _usedIds.add(id);
  }

  String uuid() {
    return "{${_uuid.generate().toUpperCase()}}";
  }

  int shortId({int min = 0, int max = 0xffffffff}) {
    int id;
    do {
      id = _random.nextInt(max - min) + min;
    } while (_usedIds.contains(id));
    _usedIds.add(id);
    return id;
  }

  int wemId({int min = 0}) {
    return shortId(min: min, max: 0x3fffffff);
  }
}
