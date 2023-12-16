
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../hierarchy/FileHierarchy.dart';
import '../../hierarchy/types/WaiHierarchyEntries.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import 'WemFileData.dart';

class WspFileData extends OpenFileData {
  List<WemFileData> wems = [];
  final String bgmBnkPath;

  WspFileData(super.name, super.path, this.bgmBnkPath, { super.secondaryName })
      : super(type: FileType.wsp);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var wspHierarchyEntry = openHierarchyManager.findRecWhere((e) => e is WspHierarchyEntry && e.path == path);
    if (wspHierarchyEntry == null) {
      showToast("WSP hierarchy entry not found");
      throw Exception("WSP hierarchy entry not found for $path");
    }
    wems = wspHierarchyEntry.children
        .map((e) => e as WemHierarchyEntry)
        .map((e) => WemFileData(
        e.name.value,
        e.path,
        wemInfo: OptionalWemData(bgmBnkPath, WemSource.wsp)
    ))
        .toList();

    await Future.wait(wems.map((w) => w.load()));

    await super.load();
  }

  @override
  void dispose() {
    for (var wem in wems)
      wem.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = WspFileData(name.value, path, bgmBnkPath);
    snapshot.optionalInfo = optionalInfo;
    snapshot.wems = wems.map((w) => w.takeSnapshot() as WemFileData).toList();
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as WspFileData;
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
    for (var i = 0; i < wems.length; i++)
      wems[i].restoreWith(content.wems[i]);
  }
}
