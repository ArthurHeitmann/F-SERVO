
import 'dart:async';

import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../theme/customTheme.dart';

class MessageLog extends ChangeNotifierWidget {
  MessageLog({super.key}) : super(notifier: messageLog);

  @override
  State<MessageLog> createState() => _MessageLogState();
}

class _MessageLogState extends ChangeNotifierState<MessageLog> {
  Timer? fadeOutTimer;
  bool isVisible = false;

  @override
  void onNotified() {
    fadeOutTimer?.cancel();
    fadeOutTimer = Timer(const Duration(seconds: 5), _fadeOut);
    isVisible = true;
    super.onNotified();
  }

  void _fadeOut() {
    setState(() {
      isVisible = false;
    });
  }

  void _expand() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      // pageBuilder: (_, __, ___) => _MessageLogDialog()
      builder: (_) => _MessageLogDialog()
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: InkWell(
        onTap: _expand,
        child: Row(
          children: [
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isVisible ? 1 : 0,
                child: Text(
                  messageLog.isNotEmpty ? messageLog.last : "",
                  textAlign: TextAlign.right,
                  textScaleFactor: 0.9,
                  style: TextStyle(color: getTheme(context).textColor!.withOpacity(0.75)),
                ),
              ),
            ),
            const SizedBox(width: 4,),
            Icon(
              Icons.clear_all,
              size: 20,
              color: getTheme(context).textColor!.withOpacity(0.35),
            ),
            const SizedBox(width: 4,),
          ],
        )
      ),
    );
  }
}

class _MessageLogDialog extends ChangeNotifierWidget {
  _MessageLogDialog() : super(notifier: messageLog);

  @override
  State<_MessageLogDialog> createState() => _MessageLogDialogState();
}

class _MessageLogDialogState extends ChangeNotifierState<_MessageLogDialog> {
  var controller = ScrollController();

  @override
  void initState() {
    jumpToEnd();
    super.initState();
  }

  @override
  void onNotified() {
    super.onNotified();
    jumpToEnd();
  }

  void jumpToEnd() async {
    await waitForNextFrame();
    controller.jumpTo(controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    var shadowColor = Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withOpacity(0.4)
      : Colors.black.withOpacity(0.2);
    return Stack(
      children: [
        Positioned(
          bottom: 30,
          right: 20,
          width: 400,
          height: 250,
          child: Container(
            decoration: BoxDecoration(
              color: getTheme(context).sidebarBackgroundColor,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  spreadRadius: 0,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: shadowColor,
                  spreadRadius: 0,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: shadowColor,
                  spreadRadius: 0,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: shadowColor,
                  spreadRadius: 0,
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 25,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 10, top: 8),
                      child: Text(
                        "Messages:",
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: messageLog.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(messageLog[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
