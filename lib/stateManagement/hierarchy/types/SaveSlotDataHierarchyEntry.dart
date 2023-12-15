
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class SaveSlotDataHierarchyEntry extends GenericFileHierarchyEntry {
  SaveSlotDataHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true);

  @override
  HierarchyEntry clone() {
    return SaveSlotDataHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}
