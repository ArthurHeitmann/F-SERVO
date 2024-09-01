
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class McdHierarchyEntry extends GenericFileHierarchyEntry {
  McdHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 30);

  @override
  HierarchyEntry clone() {
    return McdHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
