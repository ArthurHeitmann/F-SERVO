import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crclib/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  return str.startsWith("0x") && int.tryParse(str) != null;
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

String doubleToStr(num d) {
  var int = d.toInt();
    return int == d
      ? int.toString()
      : d.toString();
}

Future<void> scrollIntoView(BuildContext context, {
  double viewOffset = 0,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeInOut,
  ScrollPositionAlignmentPolicy alignment = ScrollPositionAlignmentPolicy.keepVisibleAtStart,
}) async {
  assert(alignment != ScrollPositionAlignmentPolicy.explicit, "ScrollPositionAlignmentPolicy.explicit is not supported");
  final ScrollableState? scrollState = Scrollable.of(context);
  final RenderObject? renderObject = context.findRenderObject();
  if (scrollState == null)
    return;
  if (renderObject == null)
    return;
  final RenderAbstractViewport? viewport = RenderAbstractViewport.of(renderObject);
  if (viewport == null)
    return;
  final position = scrollState.position;
  double target;
  if (alignment == ScrollPositionAlignmentPolicy.keepVisibleAtStart) {
    target = clamp(viewport.getOffsetToReveal(renderObject, 0.0).offset - viewOffset, position.minScrollExtent, position.maxScrollExtent);
  }
  else {
    target = clamp(viewport.getOffsetToReveal(renderObject, 1.0).offset + viewOffset, position.minScrollExtent, position.maxScrollExtent);
  }

  if (target == position.pixels)
    return;

  await position.animateTo(target, duration: duration, curve: curve);
}
