
import 'dart:async';

import '../../../fileTypeUtils/utils/ByteDataWrapperRA.dart';
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class CpkHierarchyEntry extends FileHierarchyEntry {
  final ByteDataWrapperRA _cpkFile;

  CpkHierarchyEntry(StringProp name, String path, this._cpkFile)
      : super(name, path, true, false, priority: 999999);

  @override
  void dispose() {
    super.dispose();
    unawaited(_cpkFile.close());
  }
}

class CpkFolderHierarchyEntry extends HierarchyEntry {
  CpkFolderHierarchyEntry(StringProp name)
      : super(name, false, true, false, priority: 99999);
}
