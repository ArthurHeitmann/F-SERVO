
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class EstHierarchyEntry extends FileHierarchyEntry {
  EstHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 5);
}
