import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../widgets/theme/customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/miscValues.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../stateManagement/undoable.dart';
import '../../utils/utils.dart';
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
            Tooltip(
              message: "Auto translate Jap to Eng",
              waitDuration: const Duration(milliseconds: 500),
              child: ChangeNotifierBuilder(
                notifier: shouldAutoTranslate,
                builder: (context) => Opacity(
                  opacity: shouldAutoTranslate.value ? 1.0 : 0.25,
                  child: IconButton(
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                    splashRadius: 20,
                    icon: const Icon(Icons.translate, size: 15,),
                    isSelected: shouldAutoTranslate.value,
                    onPressed: () => shouldAutoTranslate.value ^= true,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: "Save all changed files",
              waitDuration: const Duration(milliseconds: 500),
              child: IconButton(
                padding: EdgeInsets.zero,
                splashRadius: 14,
                icon: const Icon(Icons.save, size: 15),
                onPressed: () => areasManager.saveAll(),
              ),
            ),
            Tooltip(
              message: "Settings",
              waitDuration: const Duration(milliseconds: 500),
              child: IconButton(
                padding: EdgeInsets.zero,
                splashRadius: 14,
                icon: const Icon(Icons.settings, size: 15),
                onPressed: () => areasManager.openPreferences(),
              ),
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
