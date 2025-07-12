
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class SmdHierarchyEntry extends FileHierarchyEntry {
  SmdHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 30);
}
