
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class WtaHierarchyEntry extends GenericFileHierarchyEntry {
  WtaHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 20);

  @override
  HierarchyEntry clone() {
    return WtaHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
