
import 'package:flutter/material.dart';

import '../../changesExporter.dart';
import 'PlainTextFileData.dart';
import 'TextFileData.dart';

class RubyFileData extends PlainTextFileData {
  RubyFileData(super.name, super.path, { super.secondaryName, super.initText })
      : super(icon: Icons.code);

  @override
  Future<void> save() async {
    await super.save();
    changedRbFiles.add(path);
  }

  @override
  TextFileData copyBase() {
    return RubyFileData(name.value, path, initText: text.value);
  }
}
