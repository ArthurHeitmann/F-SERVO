import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../widgets/theme/customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/miscValues.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../stateManagement/undoable.dart';
import '../../utils.dart';
import 'TitlebarButton.dart';


class TitleBar extends ChangeNotifierWidget {
  TitleBar({Key? key}) : super(key: key, notifiers: [windowTitle, undoHistoryManager]);

  @override
  TitleBarState createState() => TitleBarState();
}

class TitleBarState extends ChangeNotifierState<TitleBar> with WindowListener {
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    if (isDesktop)
      windowManager.addListener(this);
    init();
  }

  void init() async {
    isExpanded = isDesktop ? await windowManager.isMaximized() : true;
    if (isDesktop) {
      await windowManager.setTitle(windowTitle.value);
      windowTitle.value = await windowManager.getTitle();
    }
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
    return Material(
      color: getTheme(context).titleBarColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: titleBarHeight,
          maxHeight: titleBarHeight,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 14,
              icon: const Icon(Icons.undo, size: 17),
              onPressed: undoHistoryManager.canUndo ? undoHistoryManager.undo : null,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 14,
              icon: const Icon(Icons.redo, size: 17),
              onPressed: undoHistoryManager.canRedo ? undoHistoryManager.redo : null,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 14,
              icon: const Icon(Icons.save, size: 15),
              onPressed: () => areasManager.saveAll(),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 14,
              icon: const Icon(Icons.settings, size: 15),
              onPressed: () => areasManager.openPreferences(),
            ),
            Expanded(
              child: GestureDetector(
                onPanUpdate: isDesktop ? (details) => windowManager.startDragging() : null,
                onDoubleTap: isDesktop ? toggleMaximize : null,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  child: Text(windowTitle.value, style: TextStyle(color: getTheme(context).titleBarTextColor)),
                )
              ),
            ),
            if (isDesktop) ...[
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
            ]
          ],
        ),
      ),
    );
  }
}
