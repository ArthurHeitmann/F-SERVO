
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class WmbHierarchyEntry extends FileHierarchyEntry {
  WmbHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true, priority: 12);
}
