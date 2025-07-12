
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class McdHierarchyEntry extends FileHierarchyEntry {
  McdHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 30);
}
