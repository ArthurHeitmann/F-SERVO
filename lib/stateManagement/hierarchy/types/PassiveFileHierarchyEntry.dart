
import '../../Property.dart';
import '../../undoable.dart';
import '../HierarchyEntryTypes.dart';

class PassiveFileHierarchyEntry extends FileHierarchyEntry {

  PassiveFileHierarchyEntry(StringProp name, String path)
    : super(name, path, false, false, priority: 0);

  @override
  Undoable takeSnapshot() {
    var entry = PassiveFileHierarchyEntry(name, path);
    entry.overrideUuid(uuid);
    entry.isSelected.value = isSelected.value;
    return entry;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as HierarchyEntry;
    name.restoreWith(entry.name);
    isSelected.value = entry.isSelected.value;
  }
}
