
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class PassiveFileHierarchyEntry extends FileHierarchyEntry {

  PassiveFileHierarchyEntry(StringProp name, String path)
    : super(name, path, false, false, priority: 0);
}
