import 'package:flutter/material.dart';
// import 'package:window_manager/window_manager.dart';

import '../../stateManagement/miscValues.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../stateManagement/undoable.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../help/helpLayout.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/overlayWindow.dart';
import 'TitlebarButton.dart';
import 'logo.dart';


class TitleBar extends ChangeNotifierWidget {
  TitleBar({super.key}) : super(notifiers: [windowTitle]);

  @override
  TitleBarState createState() => TitleBarState();
}

class TitleBarState extends ChangeNotifierState<TitleBar> /*with WindowListener*/ {
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    // if (isDesktop)
    //   windowManager.addListener(this);
    init();
  }

  void init() async {
    // isExpanded = isDesktop ? await windowManager.isMaximized() : true;
    // if (isDesktop) {
    //   await windowManager.setTitle(windowTitle.value);
    //   // windowTitle.value = await windowManager.getTitle();
    // }
  }

  // @override
  // void onWindowMaximize() {
  //   super.onWindowMaximize();
  //   setState(() {
  //     isExpanded = true;
  //   });
  // }

  // @override
  // void onWindowUnmaximize() {
  //   super.onWindowUnmaximize();
  //   setState(() {
  //     isExpanded = false;
  //   });
  // }

  void toggleMaximize() async {
    // if (await windowManager.isMaximized()) {
    //   windowManager.unmaximize();
    // } else {
    //   windowManager.maximize();
    // }
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
        child: activeFileBuilder(
          builder: (context, file) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  splashRadius: 14,
                  icon: const Icon(Icons.undo, size: 17),
                  onPressed: (file?.canUndo ?? false) && (file?.historyEnabled ?? false) ? file!.undo : null,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  splashRadius: 14,
                  icon: const Icon(Icons.redo, size: 17),
                  onPressed: (file?.canRedo ?? false) && (file?.historyEnabled ?? false) ? file!.redo : null,
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
                  message: "Help",
                  waitDuration: const Duration(milliseconds: 500),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                    icon: const Icon(Icons.help_outline, size: 15),
                    onPressed: () => OverlayWindow.show(
                      context: context,
                      initSizePercent: const Size(0.7, 0.7),
                      initSizePercentLimit: const Size(1200, 800),
                      title: "Help",
                      child: HelpLayout(),
                    ),
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
                // Tooltip(
                //   message: "Auto translate Jap to Eng",
                //   waitDuration: const Duration(milliseconds: 500),
                //   child: ChangeNotifierBuilder(
                //     notifier: shouldAutoTranslate,
                //     builder: (context) => Opacity(
                //       opacity: shouldAutoTranslate.value ? 1.0 : 0.25,
                //       child: IconButton(
                //         padding: const EdgeInsets.all(5),
                //         constraints: const BoxConstraints(),
                //         iconSize: 20,
                //         splashRadius: 20,
                //         icon: const Icon(Icons.translate, size: 15,),
                //         isSelected: shouldAutoTranslate.value,
                //         onPressed: () => shouldAutoTranslate.value ^= true,
                //       ),
                //     ),
                //   ),
                // ),
                Expanded(
                  child: GestureDetector(
                    // onPanUpdate: isDesktop ? (details) => windowManager.startDragging() : null,
                    onDoubleTap: isDesktop ? toggleMaximize : null,
                    behavior: HitTestBehavior.translucent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GameLogo(size: const Size(21, 21)),
                        const SizedBox(width: 6),
                        Text(windowTitle.value, style: TextStyle(color: getTheme(context).titleBarTextColor), overflow: TextOverflow.ellipsis),
                      ],
                    )
                  ),
                ),
                if (isDesktop) ...[
                  TitleBarButton(
                    icon: Icons.minimize_rounded,
                    onPressed: null /*windowManager.minimize*/,
                    primaryColor: getTheme(context).titleBarButtonPrimaryColor!,
                  ),
                  TitleBarButton(
                    icon: isExpanded ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                    onPressed: toggleMaximize,
                    primaryColor: getTheme(context).titleBarButtonPrimaryColor!,
                  ),
                  TitleBarButton(
                    icon: Icons.close_rounded,
                    onPressed: null /*windowManager.close*/,
                    primaryColor: getTheme(context).titleBarButtonCloseColor!,
                  ),
                ]
              ],
            );
          }
        ),
      ),
    );
  }

  Widget activeFileBuilder({required Widget Function(BuildContext, HasUndoHistory?) builder}) {
    return ChangeNotifierBuilder(
      notifier: areasManager.activeArea,
      builder: (context) => ChangeNotifierBuilder(
        key: Key(areasManager.activeArea.value?.uuid ?? ""),
        notifier: areasManager.activeArea.value?.currentFile,
        builder: (context) => ChangeNotifierBuilder(
          key: Key(areasManager.activeArea.value?.currentFile.value?.uuid ?? ""),
          notifier: areasManager.activeArea.value?.currentFile.value?.historyNotifier,
          builder: (context) => builder(context, areasManager.activeArea.value?.currentFile.value),
        )
      ),
    );
  }
}
