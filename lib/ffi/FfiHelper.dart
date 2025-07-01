
import 'dart:ffi';
import 'package:path/path.dart';

import 'RustyPlatinumUtilsFfi.dart';

class FfiHelper {
  static late final FfiHelper i;
  late final RustyPlatinumUtils rustyPlatinumUtils;


  FfiHelper(String assetsDir);
}
