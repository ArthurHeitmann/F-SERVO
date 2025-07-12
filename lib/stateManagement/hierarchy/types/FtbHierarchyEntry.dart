
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class FtbHierarchyEntry extends FileHierarchyEntry {
  FtbHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true, priority: 30);
}
