

import '../../../fileSystem/FileSystem.dart';
import 'TextFileData.dart';

class PlainTextFileData extends TextFileData {
  PlainTextFileData(super.name, super.path, { super.secondaryName, super.icon, super.iconColor, super.initText });

  @override
  Future<void> save() async {
    await FS.i.writeAsString(path, text.value);
    setHasUnsavedChanges(false);
    await super.save();
  }

  @override
  TextFileData copyBase() {
    return PlainTextFileData(name.value, path, initText: text.value);
  }
}
