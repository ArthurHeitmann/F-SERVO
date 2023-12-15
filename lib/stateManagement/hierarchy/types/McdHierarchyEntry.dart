
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class McdHierarchyEntry extends GenericFileHierarchyEntry {
  McdHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true);

  @override
  HierarchyEntry clone() {
    return McdHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
