
import 'package:xml/xml.dart';

import '../../utils.dart';
import '../wwiseElementBase.dart';
import '../wwiseProjectGenerator.dart';

class WwiseConversionInfo extends WwiseElementBase {
  final String conversionId;

  WwiseConversionInfo({required super.project, required this.conversionId}) : super(name: "");

  WwiseConversionInfo.projectDefault(WwiseProjectGenerator project)
    : this(project: project, conversionId: project.defaultConversion.id);

  @override
  XmlElement toXml() {
    var conversion = project.lookupElement(idV4: conversionId)!;
    return makeXmlElement(name: "ConversionInfo", children: [
      makeXmlElement(name: "ConversionRef", attributes: {
        "Name": conversion.name,
        "ID": conversion.id,
      }),
    ]);
  }

}
