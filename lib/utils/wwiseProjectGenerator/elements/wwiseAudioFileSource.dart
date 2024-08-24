
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../utils.dart';
import '../wwiseAudioFilesPrepare.dart';
import '../wwiseElement.dart';

class WwiseAudioFileSource extends WwiseElement {
  final WwiseAudioFile audio;

  WwiseAudioFileSource({required super.wuId, required super.project, required this.audio}) : super(
    tagName: "AudioFileSource",
    name: audio.name,
    shortId: audio.nextWemId(project.idGen),
    comment: project.getComment(audio.id) ?? project.getComment(audio.prefetchId)
  );

  @override
  XmlElement toXml() {
    var xml = super.toXml();
    xml.children.add(makeXmlElement(name: "Language", text: audio.isVoice ? project.language : "SFX"));
    xml.children.add(makeXmlElement(name: "AudioFile", text: basename(audio.path)));
    return xml;
  }
}
