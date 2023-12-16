
import 'package:flutter/material.dart';

import '../../../stateManagement/changesExporter.dart';
import '../../../stateManagement/events/statusInfo.dart';
import '../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../stateManagement/openFiles/types/FtbFileData.dart';
import '../../../stateManagement/openFiles/types/McdFileData.dart';

class FontOverridesApplyButton extends StatelessWidget {
  const FontOverridesApplyButton({super.key});

  Future<void> applyAllFontOverrides() async {
    isLoadingStatus.pushIsLoading();
    messageLog.add("Saving MCD...");
    try {
      var savableFiles = areasManager.areas
        .expand((area) => area.files)
        .where((file) => file is McdFileData || file is FtbFileData);
      await Future.wait(savableFiles.map((f) => f.save()));
      messageLog.add("Done :>");
    } catch (e) {
      messageLog.add("Error :/");
      print(e);
    } finally {
      await processChangedFiles();
      isLoadingStatus.popIsLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: applyAllFontOverrides,
      tooltip: "Apply all font overrides & export all open mcd/ftb files",
      icon: const Icon(Icons.save)
    );
  }
}
