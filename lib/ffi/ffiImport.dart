
export 'package:wasm_ffi/ffi.dart'
  if (dart.library.ffi) 'dart:ffi';

export 'package:wasm_ffi/ffi_utils.dart'
  if (dart.library.ffi) 'package:ffi/ffi.dart';
