
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class WtbHierarchyEntry extends GenericFileHierarchyEntry {
  WtbHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true);

  @override
  HierarchyEntry clone() {
    return WtbHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
