
import 'package:flutter/material.dart';

import '../../../../stateManagement/changesExporter.dart';
import '../../../../stateManagement/events/statusInfo.dart';
import '../../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../../stateManagement/openFiles/types/FtbFileData.dart';
import '../../../../stateManagement/openFiles/types/McdFileData.dart';
import '../../../theme/customTheme.dart';

class FontOverridesApplyButton extends StatelessWidget {
  final bool showText;

  const FontOverridesApplyButton({super.key, this.showText = false});

  Future<void> applyAllFontOverrides() async {
    isLoadingStatus.pushIsLoading();
    messageLog.add("Saving MCD...");
    try {
      var savableFiles = areasManager.areas
        .expand((area) => area.files)
        .where((file) => file is McdFileData || file is FtbFileData);
      await Future.wait(savableFiles.map((f) => f.save()));
      messageLog.add("Done :>");
    } catch (e, s) {
      messageLog.add("Error :/");
      print("$e\n$s");
    } finally {
      await processChangedFiles();
      isLoadingStatus.popIsLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showText) {
      return Tooltip(
        message: "Apply all font overrides & export all open mcd/ftb files",
        child: TextButton.icon(
          onPressed: applyAllFontOverrides,
          label: const Text("Apply new font"),
          icon: const Icon(Icons.save),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(getTheme(context).textColor),
            padding: WidgetStateProperty.all(const EdgeInsets.all(14))
          ),
        ),
      );
    }
    else {
      return IconButton(
        onPressed: applyAllFontOverrides,
        tooltip: "Apply all font overrides & export all open mcd/ftb files",
        icon: const Icon(Icons.save)
      );
    }
  }
}
