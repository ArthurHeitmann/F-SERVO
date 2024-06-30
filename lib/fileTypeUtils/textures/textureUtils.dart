
import 'dart:io';


import 'package:flutter/painting.dart';

import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';

var _ddsMagic = "DDS ";
Future<SizeInt> getImageSize(String path) async {
  var bytes = await File(path).readAsBytes();
  var byteWrapper = ByteDataWrapper(bytes.buffer);
  if (byteWrapper.readString(4) == _ddsMagic) {
    byteWrapper.position = 12;
    var height = byteWrapper.readUint32();
    var width = byteWrapper.readUint32();
    return SizeInt(width, height);
  }
  else {
    var img = await decodeImageFromList(bytes);
    return SizeInt(img.width, img.height);
  }
}
