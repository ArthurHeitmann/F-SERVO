
import 'package:flutter/material.dart';

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
  void onNotified() {
    setState(() {});
  }

  @override
  void initState() {
    for (var notifier in widget._notifiers)
      notifier.addListener(onNotified);
    super.initState();
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

  ChangeNotifierBuilder({super.key, Listenable? notifier, List<Listenable>? notifiers, required this.builder })
    : super(notifier: notifier, notifiers: notifiers);

  @override
  State<ChangeNotifierBuilder> createState() => _ChangeNotifierBuilderState();
}

class _ChangeNotifierBuilderState extends ChangeNotifierState<ChangeNotifierBuilder> {
  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}