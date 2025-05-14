
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import 'serviceWorker.dart';


Future<void> initWeb() async {
  _webPreventEvents();
  unawaited(ServiceWorkerHelper.register());
}

void _webPreventEvents() {
  EventStreamProvider("contextmenu").forTarget(document).listen((event) {
    if (event.target != null && event.target.instanceOfString("HTMLElement")) {
      var target = event.target as HTMLElement;
      if (target.tagName == "FLUTTER-VIEW") {
        event.preventDefault();
      }
    }
  });
}
