
import 'dart:typed_data';

import 'MsgResult.dart';

Future<void> initWeb() async {}

class ServiceWorkerHelper {
  static ServiceWorkerHelper get i => throw Exception("Not implemented in stub");

  Future<MsgResult<Uint8List>> wemToWav(Uint8List wem) async {
    throw Exception("Not implemented in stub");
  }
  
  Future<MsgResult<Uint8List>> imgToPng(Uint8List wem, int? maxHeight) async {
    throw Exception("Not implemented in stub");
  }

  Future<MsgResult<Uint8List>> imgToDds(Uint8List wem, String compression, int mipmaps) async {
    throw Exception("Not implemented in stub");
  }
}
