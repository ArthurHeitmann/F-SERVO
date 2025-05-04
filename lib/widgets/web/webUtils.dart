
import 'dart:js_interop';

import 'package:web/web.dart';

void webPreventEvents() {
  EventStreamProvider("contextmenu").forTarget(document).listen((event) {
    if (event.target != null && event.target.instanceOfString("HTMLElement")) {
      var target = event.target as HTMLElement;
      if (target.tagName == "FLUTTER-VIEW") {
        event.preventDefault();
      }
    }
  });
}
