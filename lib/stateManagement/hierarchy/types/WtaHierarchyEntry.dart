
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class WtaHierarchyEntry extends GenericFileHierarchyEntry {
  final String wtpPath;

  WtaHierarchyEntry(StringProp name, String path, this.wtpPath)
      : super(name, path, false, true);

  @override
  HierarchyEntry clone() {
    return WtaHierarchyEntry(name.takeSnapshot() as StringProp, path, wtpPath);
  }
}
