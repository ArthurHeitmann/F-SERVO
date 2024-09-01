
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class TmdHierarchyEntry extends GenericFileHierarchyEntry {
  TmdHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 30);

  @override
  HierarchyEntry clone() {
    return TmdHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
