
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class FtbHierarchyEntry extends GenericFileHierarchyEntry {
  FtbHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true);

  @override
  HierarchyEntry clone() {
    return FtbHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
