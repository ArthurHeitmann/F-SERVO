
import 'package:flutter/material.dart';

import '../../utils/utils.dart';

abstract class ChangeNotifierWidget extends StatefulWidget {
  final List<Listenable> _notifiers = [];
  
  ChangeNotifierWidget({super.key, Listenable? notifier, List<Listenable>? notifiers }) {
    if (notifier != null)
      _notifiers.add(notifier);
    if (notifiers != null)
      _notifiers.addAll(notifiers);
  }
}

abstract class ChangeNotifierState<T extends ChangeNotifierWidget> extends State<T> {
  bool _isInitialized = false;

  void onNotified() {
    if (!_isInitialized)
      return;
    setState(() {});
  }

  @override
  void initState() {
    for (var notifier in widget._notifiers)
      notifier.addListener(onNotified);
    super.initState();
    waitForNextFrame().then((_) => _isInitialized = true);
  }

  @override
  void dispose() {
    for (var notifier in widget._notifiers)
      notifier.removeListener(onNotified);
    super.dispose();
  }
}

class ChangeNotifierBuilder extends ChangeNotifierWidget {
  final Widget Function(BuildContext context) builder;

  ChangeNotifierBuilder({super.key, super.notifier, super.notifiers, required this.builder });

  @override
  State<ChangeNotifierBuilder> createState() => _ChangeNotifierBuilderState();
}

class _ChangeNotifierBuilderState extends ChangeNotifierState<ChangeNotifierBuilder> {
  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}