
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class FtbHierarchyEntry extends GenericFileHierarchyEntry {
  FtbHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 30);

  @override
  HierarchyEntry clone() {
    return FtbHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
