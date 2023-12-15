
import '../../main.dart';
import '../../utils/utils.dart';
import '../../widgets/misc/confirmCancelDialog.dart';
import '../openFiles/openFilesManager.dart';
import 'audioResourceManager.dart';

Future<bool> beforeExitConfirmation() async {
  var unsavedFiles = areasManager
    .areas
    .followedBy([areasManager.hiddenArea])
    .expand((area) => area.files)
    .map((f) => f.hasUnsavedChanges.value ? 1 : 0)
    .fold<int>(0, (a, b) => a + b);
  
  if (unsavedFiles > 0) {
    var answer = await confirmOrCancelDialog(
      getGlobalContext(),
      title: "Unsaved files",
      body: "You have ${pluralStr(unsavedFiles, "unsaved file")}. Do you want to exit anyway?"
    );
    if (answer != true)
      return false;
  }

  try {
    await beforeExitCleanup();
  } catch (e) {
    print(e);
  }

  return true;
}

Future<void> beforeExitCleanup() async {
  await audioResourcesManager.disposeAll();
}
