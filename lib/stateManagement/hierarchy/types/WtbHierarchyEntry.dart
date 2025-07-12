
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class WtbHierarchyEntry extends FileHierarchyEntry {
  WtbHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 21);
}
