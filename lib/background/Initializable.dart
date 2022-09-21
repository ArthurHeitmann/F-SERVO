
import 'dart:async';

mixin Initializable {
  final Completer _awaitInitializedCompleter = Completer<void>();

  Future<void> awaitInitialized() {
    return _awaitInitializedCompleter.future;
  }

  void completeInitialization() {
    _awaitInitializedCompleter.complete();
  }
}
