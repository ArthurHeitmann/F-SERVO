import 'dart:convert';
import 'dart:io';

import 'package:crclib/catalog.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/dat/datRepacker.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import 'dirs.dart';

final _crc32 = Crc32();
int crc32(String str) {
  return _crc32.convert(utf8.encode(str)).toBigInt().toInt();
}

bool isInt(String str) {
  return int.tryParse(str) != null;
}

const _basicFolders = { "ba", "bg", "bh", "em", "et", "it", "pl", "ui", "um", "wp" };
const Map<String, String> _nameStartToFolder = {
  "q": "quest",
  "core": "core",
  "credit": "credit",
  "Debug": "debug",
  "font": "font",
  "misctex": "misctex",
  "subtitle": "subtitle",
  "txt": "txtmess",
};
String getDatFolder(String datName) {
  var c2 = datName.substring(0, 2);
  if (_basicFolders.contains(c2))
    return c2;
  var c1 = datName[0];
  if (c1 == "r")
    return "st${datName[1]}";
  if (c1 == "p")
    return "ph${datName[1]}";
  if (c1 == "g")
    return "wd${datName[1]}";
  
  for (var start in _nameStartToFolder.keys) {
    if (datName.startsWith(start))
      return _nameStartToFolder[start]!;
  }

  if (isInt(c2))
    return join("effect", "model");
  
  return withoutExtension(datName);
}

Future<void> exportDat(String datFolder) async {
  var datName = basename(datFolder);
  var datSubDir = getDatFolder(datName);
  var datExportDir = join(exportDir, datSubDir, datName);
  await repackDat(datFolder, datExportDir);
}

Future<List<File>> getFilteredDats(String dir, String datPrefix) async {
  var files = await Directory(dir).list().toList();
  return files
    .whereType<File>()
    .where((f) => f.path.endsWith(".dat"))
    .where((f) => basename(f.path).startsWith(datPrefix))
    .toList();
}

Future<List<Directory>> extractDats(List<File> datFiles, { bool includeDtts = false }) async {
  List<File> dtts = [];
  if (includeDtts) {
    dtts = datFiles
      .map((e) => File("${e.path.substring(0, e.path.length - 4)}.dtt"))
      .where((f) => f.existsSync())
      .toList();
  }
  Future.wait(dtts.map((f) async {
    var extractDir = Directory(join(workDir, basename(f.path)));
    await extractDatFiles(f.path, extractDir: extractDir.path);
    return extractDir;
  }));
  return await Future.wait(datFiles.map((f) async {
    var extractDir = Directory(join(workDir, basename(f.path)));
    await extractDatFiles(f.path, extractDir: extractDir.path);
    return extractDir;
  }));

}

class SizeInt {
  final int width;
  final int height;

  const SizeInt(this.width, this.height);
}
Future<SizeInt> getDdsFileSize(String path) async {
  var reader = await ByteDataWrapper.fromFile(path);
  reader.position = 0xc;
  var height = reader.readUint32();
  var width = reader.readUint32();
  return SizeInt(width, height);
}

XmlElement makeXmlElement({ required String name, String? text, Map<String, String> attributes = const {}, List<XmlElement> children = const [] }) {
  return XmlElement(
    XmlName(name),
    attributes.entries.map((attr) => XmlAttribute(XmlName(attr.key), attr.value)).toList(),
    <XmlNode>[
      if (text != null)
        XmlText(text),
      ...children,
    ],
  );
}

XmlElement makeChildXml({ required String tag, String? value }) {
  return makeXmlElement(name: "child", children: [
    makeXmlElement(name: "tag", text: tag),
    if (value != null)
      makeXmlElement(name: "value", text: value),
  ]);
}

bool isStringAscii(String s) {
  return utf8.encode(s).every((byte) => byte < 128);
}
