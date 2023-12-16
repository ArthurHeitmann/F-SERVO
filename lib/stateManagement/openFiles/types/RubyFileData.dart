
import 'package:flutter/material.dart';

import '../../changesExporter.dart';
import 'TextFileData.dart';

class RubyFileData extends TextFileData {
  RubyFileData(super.name, super.path, { super.secondaryName })
      : super(icon: Icons.code);

  @override
  Future<void> save() async {
    await super.save();
    changedRbFiles.add(path);
  }

  @override
  TextFileData copyBase() {
    return RubyFileData(name.value, path);
  }
}
