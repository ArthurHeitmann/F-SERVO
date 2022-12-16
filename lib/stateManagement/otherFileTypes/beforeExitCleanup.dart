
import '../../main.dart';
import '../../utils/utils.dart';
import '../../widgets/misc/confirmCancelDialog.dart';
import '../openFilesManager.dart';
import 'audioResourceManager.dart';

Future<bool> beforeExitConfirmation() async {
  var unsavedFiles = areasManager
    .followedBy([areasManager.hiddenArea])
    .expand((area) => area)
    .map((f) => f.hasUnsavedChanges ? 1 : 0)
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

  await beforeExitCleanup();

  return true;
}

Future<void> beforeExitCleanup() async {
  await audioResourcesManager.disposeAll();
}
