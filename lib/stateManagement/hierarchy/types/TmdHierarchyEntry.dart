
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class TmdHierarchyEntry extends FileHierarchyEntry {
  TmdHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 30);
}
