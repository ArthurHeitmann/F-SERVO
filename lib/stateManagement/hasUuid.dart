
import '../utils.dart';

class HasUuid {
  String _uuid = uuidGen.v1();

  String get uuid => _uuid;

  void overrideUuidForUndoable(String uuid) {
    _uuid = uuid;
  }
}
