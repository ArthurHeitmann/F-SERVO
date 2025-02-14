
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class WmbHierarchyEntry extends GenericFileHierarchyEntry {
  WmbHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true, priority: 12);
    
  @override
  HierarchyEntry clone() {
    return WmbHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
