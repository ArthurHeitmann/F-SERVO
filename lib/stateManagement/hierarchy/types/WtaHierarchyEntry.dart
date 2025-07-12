
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class WtaHierarchyEntry extends FileHierarchyEntry {
  WtaHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 20);
}
