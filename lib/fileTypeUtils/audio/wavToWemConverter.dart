
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';
import 'riffParser.dart';
import '../xml/xmlExtension.dart';

const _defaultTemplateFile = "wavToWemTemplate_default.zip";
const _bgmTemplateFile = "wavToWemTemplate_BGM.zip";

Future<String> _makeWwiseProject(bool isBgm) async {
  String wwiseProjectTemplate = join(assetsDir!, isBgm ? _bgmTemplateFile : _defaultTemplateFile);
  String tempProjectDir = (await Directory.systemTemp.createTemp("wwiseProject")).path;

  var fs = InputFileStream(wwiseProjectTemplate);
  var archive = ZipDecoder().decodeBuffer(fs);
  extractArchiveToDisk(archive, tempProjectDir);
  await fs.close();

  return tempProjectDir;
}

XmlDocument _getWwiseSourcesXml(String wavPath, bool enableVolumeNormalization) {
  return XmlDocument([
    XmlProcessing("xml", "version=\"1.0\" encoding=\"UTF-8\""),
    XmlElement(XmlName("ExternalSourcesList"), [
      XmlAttribute(XmlName("SchemaVersion"), "1"),
      XmlAttribute(XmlName("Root"), "wavSrc"),
    ], [
      XmlElement(XmlName("Source"), [
        XmlAttribute(XmlName("Path"), wavPath),
        if (enableVolumeNormalization)
          XmlAttribute(XmlName("AnalysisTypes"), "2"),
        XmlAttribute(XmlName("Conversion"), "External_HighQuality"),
      ]),
    ]),
  ]);
}

Future<void> wavToWem(String wavPath, String wemSavePath, bool isBgm, [bool enableVolumeNormalization = false]) async {
  var prefs = PreferencesData();
  if (assetsDir == null) {
    showToast("Assets directory not found");
    throw Exception("Assets directory not found");
  }
  if (prefs.wwise2012CliPath!.value.isEmpty) {
    showToast("Please set Wwise CLI path in settings");
    throw Exception("Wwise CLI path not set");
  }
  var riff = RiffFile.onlyFormat(await ByteDataWrapper.fromFile(wavPath));
  var formatChunk = riff.chunks.whereType<FormatChunk>().firstOrNull;
  if (formatChunk == null) {
    showToast("WAV file has no format chunk");
    throw Exception("WAV file has no format chunk");
  }
  if (![16, 24].contains(formatChunk.bitsPerSample)) {
    showToast("WAV file must be 16 or 24 bits per sample (instead ${formatChunk.bitsPerSample})");
    throw Exception("WAV file must be 16 or 24 bits per sample (instead ${formatChunk.bitsPerSample})");
  }

  messageLog.add("Preparing Wwise project");
  String projectPath = await _makeWwiseProject(isBgm);

  try {
    String wavSrcDir = join(projectPath, "wavSrc");
    XmlDocument wSourcesXml = _getWwiseSourcesXml(wavPath, enableVolumeNormalization);
    String wSourcesXmlPath = join(wavSrcDir, "ExtSourceList.wsources");
    var xmlStr = wSourcesXml.toPrettyString();
    await File(wSourcesXmlPath).writeAsString(xmlStr);

    messageLog.add("Converting WAV to WEM");
    String wwiseCliPath = prefs.wwise2012CliPath!.value;
    String wwiseProjectPath = join(projectPath, "wavToWemTemplate.wproj");
    List<String> args = [
      wwiseProjectPath,
      "-ConvertExternalSources",
      "Windows",
      wSourcesXmlPath,
      "-NoWwiseDat"
      "-Verbose",
    ];
    print("$wwiseCliPath ${args.join(" ")}");
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
