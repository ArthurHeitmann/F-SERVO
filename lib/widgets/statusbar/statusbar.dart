

import 'dart:async';

import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/statusInfo.dart';

class Statusbar extends StatelessWidget {
  const Statusbar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25,
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).sidebarBackgroundColor,
        ),
        child: Row(
          children: [
            Expanded(child: Container(),),
            ChangeNotifierBuilder(
              notifier: messageLog,
              builder: (context) => _FadeOut(
                key: UniqueKey(),
                showDuration: const Duration(seconds: 5),
                fadeDuration: const Duration(milliseconds: 500),
                child: messageLog.isEmpty ? Container() : Text(messageLog.last),
              ),
            ),
            Container(
              width: 25,
              height: 25,
              padding: const EdgeInsets.all(6),
              child: ChangeNotifierBuilder(
                notifier: isLoadingStatus,
                builder: (context) => 
                  AnimatedOpacity(
                    opacity: isLoadingStatus.isLoading ? 0.35 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: CircularProgressIndicator(strokeWidth: 2, color: getTheme(context).textColor,),
                  ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _FadeOut extends StatefulWidget {
  final Duration showDuration;
  final Duration fadeDuration;
  final Widget child;

  const _FadeOut({ super.key, required this.showDuration, required this.fadeDuration, required this.child });

  @override
  State<_FadeOut> createState() => __FadeOutState();
}

class __FadeOutState extends State<_FadeOut> {
  bool visible = true;
  bool removed = false;
  Timer? visibilityTimer;
  Timer? removalTimer;

  @override
  void initState() {
    super.initState();
    visibilityTimer = Timer(widget.showDuration, () {
      setState(() => visible = false);
    });
    removalTimer = Timer(widget.showDuration + widget.fadeDuration, () {
      setState(() => removed = true);
    });
  }

  @override
  void dispose() {
    visibilityTimer?.cancel();
    removalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (removed)
      return Container();
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: widget.fadeDuration,
      child: widget.child,
    );
  }
}
