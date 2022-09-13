import 'dart:async';
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
  return str.startsWith("0x") && int.tryParse(str.substring(2), radix: 16) != null;
}

bool isDouble(String str) {
  return double.tryParse(str) != null;
}

bool isVector(String str) {
 return str.split(" ").every((val) => isDouble(val));
}

void Function() throttle(void Function() func, int waitMs, { bool leading = true, bool trailing = false }) {
  Timer? timeout;
  int previous = 0;
  void later() {
		previous = leading == false ? 0 : DateTime.now().millisecondsSinceEpoch;
		timeout = null;
		func();
	}
	return () {
		var now = DateTime.now().millisecondsSinceEpoch;
		if (previous != 0 && leading == false)
      previous = now;
		var remaining = waitMs - (now - previous);
		if (remaining <= 0 || remaining > waitMs) {
			if (timeout != null) {
				timeout!.cancel();
				timeout = null;
			}
			previous = now;
			func();
		}
    else if (timeout != null && trailing) {
			timeout = Timer(Duration(milliseconds: remaining), later);
		}
	};
}

void Function() debounce(void Function() func, int waitMs, { bool leading = false }) {
  Timer? timeout;
  return () {
		timeout?.cancel();
		timeout = Timer(Duration(milliseconds: waitMs), () {
			timeout = null;
			if (!leading)
        func();
		});
		if (leading && timeout != null)
      func();
	};
}
