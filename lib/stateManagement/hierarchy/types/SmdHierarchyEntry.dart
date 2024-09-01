
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class SmdHierarchyEntry extends GenericFileHierarchyEntry {
  SmdHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 30);

  @override
  HierarchyEntry clone() {
    return SmdHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
