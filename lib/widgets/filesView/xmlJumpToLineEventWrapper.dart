
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import '../../stateManagement/events/jumpToEvents.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../utils/utils.dart';
import '../../utils/xmlLineParser.dart';

class _XmlJumpToLineEventIW extends InheritedWidget {
  final Stream<JumpToIdEvent> jumpToIdEvents;

  const _XmlJumpToLineEventIW({ required super.child, required this.jumpToIdEvents });

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }
  
  static _XmlJumpToLineEventIW? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_XmlJumpToLineEventIW>();
  }
}

class XmlJumpToLineEventWrapper extends StatefulWidget {
  final Widget child;
  final OpenFileId file;

  const XmlJumpToLineEventWrapper({super.key, required this.file, required this.child});

  @override
  State<XmlJumpToLineEventWrapper> createState() => _XmlJumpToLineEventWrapperState();
}

class _XmlJumpToLineEventWrapperState extends State<XmlJumpToLineEventWrapper> {
  final jumpToIdEvents = StreamController<JumpToIdEvent>.broadcast();
  StreamSubscription<JumpToEvent>? jumpToSubscription;

  @override
  void initState() {
    jumpToSubscription = jumpToEvents.listen(onJumpToEvent);
    super.initState();
  }

  @override
  void dispose() {
    jumpToSubscription?.cancel();
    super.dispose();
  }

  void onJumpToEvent(JumpToEvent event) async {
    if (event.file.uuid != widget.file)
      return;
    if (event is JumpToLineEvent)
      onJumpToLineEvent(event);
    else if (event is JumpToIdEvent)
      onJumpToIdEvent(event);
  }
    
  void onJumpToLineEvent(JumpToLineEvent event) async {
    var file = areasManager.fromId(widget.file)!;
    var fileXml = await File(file.path).readAsString();
    var xml = parseXmlWL(fileXml);
    var element = xml.getByLine(event.line);
    if (element == null)
      return;
    
    int? id;
    int? actionId;

    if (element.tag == "id") {
      id = int.parse(element.text);
    } else if (element.get("id") != null) {
      id = int.parse(element.get("id")!.text);
    } else {
      var parent = element.parent;
      while (parent != null) {
        var idTag = parent.get("id");
        if (idTag != null) {
          id = int.parse(idTag.text);
          break;
        }
        parent = parent.parent;
      }
    }

    // var parent = element.parent;
    // while (parent != null) {
    //   if (parent.tag == "action") {
    //     actionId = int.parse(parent.get("id")!.text);
    //     break;
    //   }
    //   parent = parent.parent;
    // }

    if (id != null) {
      jumpToIdEvents.add(JumpToIdEvent(file, id, actionId));
    }
  }

  void onJumpToIdEvent(JumpToIdEvent event) {
    jumpToIdEvents.add(event);
  }

  @override
  Widget build(BuildContext context) {
    return _XmlJumpToLineEventIW(
      jumpToIdEvents: jumpToIdEvents.stream,
      child: widget.child,
    );
  }
}


class XmlWidgetWithId extends StatefulWidget {
  final HexProp id;
  final Widget child;

  const XmlWidgetWithId({ super.key, required this.id, required this.child });

  @override
  State<XmlWidgetWithId> createState() => _XmlWidgetWithIdState();
}

class _XmlWidgetWithIdState extends State<XmlWidgetWithId> {
  StreamSubscription<JumpToIdEvent>? jumpToIdSubscription;
  BuildContext? savedContext;

  void initSubscription(BuildContext context) {
    jumpToIdSubscription?.cancel();
    var events = _XmlJumpToLineEventIW.of(context)?.jumpToIdEvents;
    if (events != null)
      jumpToIdSubscription = events.listen(onJumpToIdEvent);
  }

  @override
  void dispose() {
    jumpToIdSubscription?.cancel();
    super.dispose();
  }

  void onJumpToIdEvent(JumpToIdEvent event) {
    if (savedContext == null)
      return;
    if (event.id != widget.id.value)
      return;
    scrollIntoView(savedContext!, duration: const Duration(milliseconds: 400), viewOffset: 45);
  }

  @override
  Widget build(BuildContext context) {
    savedContext = context;
    if (jumpToIdSubscription == null)
      initSubscription(context);
    return widget.child;
  }
}
