
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class UidHierarchyEntry extends FileHierarchyEntry {
  UidHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true, priority: 6);
}
