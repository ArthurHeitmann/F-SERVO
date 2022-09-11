import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/miscValues.dart';
import '../../utils.dart';
import 'TitlebarButton.dart';


class TitleBar extends ChangeNotifierWidget {
  TitleBar({Key? key}) : super(key: key, notifier: windowTitle);

  @override
  TitleBarState createState() => TitleBarState();
}

class TitleBarState extends ChangeNotifierState<TitleBar> with WindowListener {
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    init();
  }

  void init() async {
    isExpanded = await windowManager.isMaximized();
    await windowManager.setTitle(windowTitle.value);
    windowTitle.value = await windowManager.getTitle();
  }

  @override
  void onWindowMaximize() {
    super.onWindowMaximize();
    setState(() {
      isExpanded = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    super.onWindowUnmaximize();
    setState(() {
      isExpanded = false;
    });
  }

  void toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getTheme(context).titleBarColor,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: titleBarHeight,
          maxHeight: titleBarHeight,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                onPanUpdate: (details) => windowManager.startDragging(),
                onDoubleTap: toggleMaximize,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  child: Text(windowTitle.value, style: TextStyle(color: getTheme(context).titleBarTextColor)),
                )
              ),
            ),
            TitleBarButton(
              icon: Icons.minimize_rounded,
              onPressed: windowManager.minimize,
              primaryColor: getTheme(context).titleBarButtonPrimaryColor!,
              
            ),
            TitleBarButton(
              icon: isExpanded ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              onPressed: toggleMaximize,
              primaryColor: getTheme(context).titleBarButtonPrimaryColor!,
            ),
            TitleBarButton(
              icon: Icons.close_rounded,
              onPressed: windowManager.close,
              primaryColor: getTheme(context).titleBarButtonCloseColor!,
            ),
          ],
        ),
      ),
    );
  }
}