import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nier_scripts_editor/titlebar/TitlebarButton.dart';
import 'package:window_manager/window_manager.dart';

import '../customTheme.dart';

final windowTitleProvider = StateProvider<String>((ref) => "Nier Scripts Editor");
final titleBarHeightProvider = Provider<double>((ref) => 25);

class TitleBar extends ConsumerStatefulWidget {
  const TitleBar({Key? key}) : super(key: key);

  @override
  TitleBarState createState() => TitleBarState();
}

class TitleBarState extends ConsumerState<TitleBar> with WindowListener {
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    init();
  }

  void init() async {
    isExpanded = await windowManager.isMaximized();
    var titleProvider = ref.read(windowTitleProvider.notifier);
    await windowManager.setTitle(titleProvider.state);
    titleProvider.state = await windowManager.getTitle();
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
    var title = ref.watch(windowTitleProvider);
    var height = ref.watch(titleBarHeightProvider);

    return Container(
      decoration: BoxDecoration(
        color: getTheme(context).titleBarColor,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: height,
          maxHeight: height,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                onPanUpdate: (details) => windowManager.startDragging(),
                onDoubleTap: toggleMaximize,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  child: Text(title, style: TextStyle(color: getTheme(context).titleBarTextColor)),
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
