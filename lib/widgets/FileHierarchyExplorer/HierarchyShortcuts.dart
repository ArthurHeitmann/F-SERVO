import 'package:flutter/widgets.dart';

class CallbackIntent extends Intent {
  final VoidCallback callback;

  const CallbackIntent(this.callback);
}

class ArrowUpShortcut extends CallbackIntent {
  const ArrowUpShortcut(super.callback);
}
class ArrowDownShortcut extends CallbackIntent {
  const ArrowDownShortcut(super.callback);
}
class ArrowLeftShortcut extends CallbackIntent {
  const ArrowLeftShortcut(super.callback);
}
class ArrowRightShortcut extends CallbackIntent {
  const ArrowRightShortcut(super.callback);
}
class EnterShortcut extends CallbackIntent {
  const EnterShortcut(super.callback);
}

class CallbackAction extends Action<CallbackIntent> {
  @override
  Object? invoke(covariant CallbackIntent intent) {
    intent.callback();
    return null;
  }
}