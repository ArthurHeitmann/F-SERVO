
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class UidHierarchyEntry extends GenericFileHierarchyEntry {
  UidHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true, priority: 6);
    
  @override
  HierarchyEntry clone() {
    return UidHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
