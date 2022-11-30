
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../stateManagement/preferencesData.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';

Future<String> _makeWwiseProject() async {
  String wwiseProjectTemplate = join(assetsDir!, "wwiseProjectTemplate.zip");
  String tempProjectDir = (await Directory.systemTemp.createTemp("wwiseProject")).path;

  var archive = ZipDecoder().decodeBuffer(InputFileStream(wwiseProjectTemplate));
  extractArchiveToDisk(archive, tempProjectDir);  // TODO compute?

  return tempProjectDir;
}

XmlDocument _getWwiseSourcesXml(String wavPath, String wemPath) {
  return XmlDocument([
    XmlProcessing("xml", "version=\"1.0\" encoding=\"UTF-8\""),
    XmlElement(XmlName("ExternalSourcesList"), [
      XmlAttribute(XmlName("SchemaVersion"), "1"),
      XmlAttribute(XmlName("Root"), dirname(wavPath)),
    ], [
      XmlElement(XmlName("Source"), [
        XmlAttribute(XmlName("Path"), wavPath),
        XmlAttribute(XmlName("Destination"), wemPath),
        XmlAttribute(XmlName("AnalysisTypes"), "2"),  // TODO 6?
        XmlAttribute(XmlName("Conversion"), "External_HighQuality"),
      ]),
    ]),
  ]);
}

Future<void> wavToWem(String wavPath, String wemSavePath) async {
  var prefs = PreferencesData();
  if (assetsDir == null) {
    showToast("Assets directory not found");
    throw Exception("Assets directory not found");
  }
  if (prefs.wwiseCliPath!.value.isEmpty) {
    showToast("Wwise CLI path not set");
    throw Exception("Wwise CLI path not set");
  }

  String projectPath = await _makeWwiseProject();

  String wavSrcDir = join(projectPath, "wavSrc");
  await File(wavPath).copy(join(wavSrcDir, basename(wavPath)));
  XmlDocument wSourcesXml = _getWwiseSourcesXml(wavPath, wemSavePath);
  String wSourcesXmlPath = join(wavSrcDir, "ExtSourceList.xml");
  await File(wSourcesXmlPath).writeAsString(wSourcesXml.toXmlString(pretty: true));

  String wwiseCliPath = prefs.wwiseCliPath!.value;
  String wwiseProjectPath = join(projectPath, "WwiseProject.wproj");  // TODO check
  List<String> args = [
    wwiseProjectPath,
    "-ConvertExternalSources",
    "Windows",
    wSourcesXmlPath,
    "-NoWwiseDat"
    "-Verbose",
  ];
  var result = await Process.run(wwiseCliPath, args);
  print(result.stdout);
  print(result.stderr);
  if (result.exitCode != 0) {
    showToast("Error converting WAV to WEM");
    throw Exception("Error converting WAV to WEM");
  } 

  await Directory(projectPath).delete(recursive: true);

  print("WAV to WEM conversion successful");
}
