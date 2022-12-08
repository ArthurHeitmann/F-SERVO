
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';

Future<String> _makeWwiseProject() async {
  String wwiseProjectTemplate = join(assetsDir!, "wavToWemTemplate.zip");
  String tempProjectDir = (await Directory.systemTemp.createTemp("wwiseProject")).path;

  var fs = InputFileStream(wwiseProjectTemplate);
  var archive = ZipDecoder().decodeBuffer(fs);
  extractArchiveToDisk(archive, tempProjectDir);
  fs.close();

  return tempProjectDir;
}

XmlDocument _getWwiseSourcesXml(String wavPath) {
  return XmlDocument([
    XmlProcessing("xml", "version=\"1.0\" encoding=\"UTF-8\""),
    XmlElement(XmlName("ExternalSourcesList"), [
      XmlAttribute(XmlName("SchemaVersion"), "1"),
      XmlAttribute(XmlName("Root"), "wavSrc"),
    ], [
      XmlElement(XmlName("Source"), [
        XmlAttribute(XmlName("Path"), wavPath),
        // XmlAttribute(XmlName("AnalysisTypes"), "2"),
        XmlAttribute(XmlName("Conversion"), "External_HighQuality"),
      ]),
    ]),
  ]);
}

Future<void> wavToWem(String wavPath, String wemSavePath, bool patchForBgm) async {
  var prefs = PreferencesData();
  if (assetsDir == null) {
    showToast("Assets directory not found");
    throw Exception("Assets directory not found");
  }
  if (prefs.wwiseCliPath!.value.isEmpty) {
    showToast("Wwise CLI path not set");
    throw Exception("Wwise CLI path not set");
  }

  messageLog.add("Preparing Wwise project");
  String projectPath = await _makeWwiseProject();

  try {
    String wavSrcDir = join(projectPath, "wavSrc");
    XmlDocument wSourcesXml = _getWwiseSourcesXml(wavPath);
    String wSourcesXmlPath = join(wavSrcDir, "ExtSourceList.wsources");
    var xmlStr = wSourcesXml.toXmlString(pretty: true, indent: "\t");
    await File(wSourcesXmlPath).writeAsString(xmlStr);

    messageLog.add("Converting WAV to WEM${patchForBgm ? " (with BGM patch)" : ""}");
    String wwiseCliPath = prefs.wwiseCliPath!.value;
    String wwiseProjectPath = join(projectPath, "wavToWemTemplate.wproj");
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
    var wemExportedPath = join(projectPath, "GeneratedSoundBanks", "Windows", "${basenameWithoutExtension(wavPath)}.wem");
    if (!await File(wemExportedPath).exists()) {
      showToast("Error converting WAV to WEM");
      throw Exception("Error converting WAV to WEM");
    }

    await File(wemExportedPath).copy(wemSavePath);

    print("WAV to WEM conversion successful");
    messageLog.add("WAV to WEM conversion successful");
  } finally {
    await Directory(projectPath).delete(recursive: true);
  }
}
