
import 'package:path/path.dart';

import '../utils/utils.dart';
import 'FileSystem.dart';

class ExtractedFilesManager {
  static final i = ExtractedFilesManager();
  final Map<String, String> _sourceToExtracted = {};
  final Map<String, String> _extractedToSource = {};

  Future<String> getOrMakeExtracted(String source, { bool createIfMissing = true }) async {
    String extractedPath;
    String parentDir;
    if (!FS.i.isVirtual(source) && FS.i.useVirtualFs)
      parentDir = "\$opened";
    else
      parentDir = dirname(source);
    if (strEndsWithDat(source)) {
      extractedPath = join(parentDir, datSubExtractDir, basename(source));
    } else if (source.endsWith(".bnk") || source.endsWith(".wta") || source.endsWith(".wtb") || source.endsWith(".ctx")) {
      extractedPath = join(parentDir, "${basename(source)}_extracted");
    } else {
      throw Exception("Unsupported file type for extraction: $source");
    }
    if (createIfMissing && !await FS.i.exists(extractedPath))
      await FS.i.createDirectory(extractedPath);
    
    _sourceToExtracted[source] = extractedPath;
    _extractedToSource[extractedPath] = source;
    
    return extractedPath;
  }

  void addExtracted(String source, String extracted) {
    _sourceToExtracted[source] = extracted;
    _extractedToSource[extracted] = source;
  }

  String getSourceOf(String extracted) {
    var source = _sourceToExtracted[extracted];
    if (source != null)
      return source;
    if (strEndsWithDat(extracted)) {
      return join(dirname(dirname(extracted)), basename(extracted));
    } else if (extracted.endsWith(".bnk") || extracted.endsWith(".wta") || extracted.endsWith(".wtb") || extracted.endsWith(".ctx")) {
      return join(dirname(extracted), basename(extracted).replaceAll("_extracted", ""));
    } else {
      throw Exception("Unsupported file type for extraction: $source");
    }    
  }
}
