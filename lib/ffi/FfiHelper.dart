
import 'package:path/path.dart';

import 'dart:ffi';
import 'RustyPlatinumUtilsFfi.dart';

class FfiHelper {
  static late final FfiHelper i;
  final RustyPlatinumUtils rustyPlatinumUtils;


  FfiHelper(String assetsDir) :
    rustyPlatinumUtils = RustyPlatinumUtils(DynamicLibrary.open(join(assetsDir, "rusty_platinum_utils", "target", "release", "rusty_platinum_utils.dll")));
}
