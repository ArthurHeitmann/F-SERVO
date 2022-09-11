
import 'package:flutter/material.dart';

abstract class ChangeNotifierWidget extends StatefulWidget {
  final List<ChangeNotifier> _notifiers = [];
  
  ChangeNotifierWidget({super.key, ChangeNotifier? notifier, List<ChangeNotifier>? notifiers }) {
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