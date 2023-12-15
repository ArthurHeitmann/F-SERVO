
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class EstHierarchyEntry extends GenericFileHierarchyEntry {
  EstHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true);

  @override
  HierarchyEntry clone() {
    return EstHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
