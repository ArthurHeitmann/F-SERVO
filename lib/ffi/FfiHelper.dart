
import 'package:path/path.dart';
import 'package:universal_ffi/ffi_helper.dart' as ffi;

import 'RustyPlatinumUtilsFfi.dart';

class FfiHelper {
  static late final FfiHelper i;
  late final RustyPlatinumUtils rustyPlatinumUtils;

  static Future<void> init(String assetsDir) async {
    i = FfiHelper();
    var rpuPath = join(assetsDir, "bins", "rusty_platinum_utils", "rusty_platinum_utils");
    var lib = await ffi.FfiHelper.load(rpuPath, options: {ffi.LoadOption.isWasmPack});
    i.rustyPlatinumUtils = RustyPlatinumUtils(lib.library);
  }
}
