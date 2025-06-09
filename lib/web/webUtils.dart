
import 'dart:async';
import 'dart:js_interop';

import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:web/web.dart';
import 'package:pointer_interceptor_web/pointer_interceptor_web.dart';

import '../stateManagement/beforeExitCleanup.dart';
import 'serviceWorker.dart';


Future<void> initWeb() async {
  PointerInterceptorPlatform.instance = PointerInterceptorWeb();
  _webPreventEvents();
  _webBeforeExitConfirmation();
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

void _webBeforeExitConfirmation() {
  bool preventExit = false;
  EventStreamProvider<KeyboardEvent>("keydown").forTarget(document).listen((event) {
    if (event.key == "Control" || event.key == "Meta") {
      preventExit = true;
    }
  });
  EventStreamProvider<KeyboardEvent>("keyup").forTarget(document).listen((event) {
    if (event.key == "Control" || event.key == "Meta") {
      preventExit = false;
    }
  });
  EventStreamProvider("beforeunload").forTarget(window).listen((event) {
    if (!event.instanceOfString("BeforeUnloadEvent"))
      return;
    var beforeUnloadEvent = event as BeforeUnloadEvent;
    if (preventExit || numberOfUnsavedFiles() > 0) {
      beforeUnloadEvent.preventDefault();
      beforeUnloadEvent.returnValue = "Are you sure you want to leave?";
      preventExit = false;
    } else {
      beforeUnloadEvent.returnValue = "";
    }
  });
  EventStreamProvider("blur").forTarget(window).listen((event) {
    preventExit = false;
  });
}
