

import 'dart:collection';
import 'dart:typed_data';

import '../utils/ByteDataWrapper.dart';

E? binarySearch<E>(List<E> list, int Function(E) cmp) {
  int low = 0;
  int high = list.length - 1;
  while (low <= high) {
    int mid = (low + high) ~/ 2;
    int c = cmp(list[mid]);
    if (c == 0)
      return list[mid];
    if (c < 0)
      low = mid + 1;
    else
      high = mid - 1;
  }
  return null;
}

class Range {
  late final int start;
  late final int end;

  int compareTo(int value) {
    if (value < start)
      return 1;
    if (value > end)
      return -1;
    return 0;
  }
}

class TtVersion {
  final int major;
  final int minor;

  TtVersion(this.major, this.minor);

  TtVersion.read(ByteDataWrapper bytes) :
    major = bytes.readUint16(),
    minor = bytes.readUint16();
}

class TtOffsetTable {
  final TtVersion sfntVersion;
  final int numTables;
  final int searchRange;
  final int entrySelector;
  final int rangeShift;

  TtOffsetTable.read(ByteDataWrapper bytes) :
    sfntVersion = TtVersion.read(bytes),
    numTables = bytes.readUint16(),
    searchRange = bytes.readUint16(),
    entrySelector = bytes.readUint16(),
    rangeShift = bytes.readUint16();
}

class TtTable {
  final String tag;
  final int checkSum;
  final int offset;
  final int length;

  TtTable.read(ByteDataWrapper bytes) :
    tag = bytes.readString(4),
    checkSum = bytes.readUint32(),
    offset = bytes.readUint32(),
    length = bytes.readUint32();
}

class TtHead {
  final TtVersion version;
  final TtVersion fontRevision;
  final int checkSumAdjustment;
  final int magicNumber;
  final int flags;
  final int unitsPerEm;
  final int created;
  final int modified;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  final int macStyle;
  final int lowestRecPPEM;
  final int fontDirectionHint;
  final int indexToLocFormat;
  final int glyphDataFormat;

  TtHead.read(ByteDataWrapper bytes) :
    version = TtVersion.read(bytes),
    fontRevision = TtVersion.read(bytes),
    checkSumAdjustment = bytes.readUint32(),
    magicNumber = bytes.readUint32(),
    flags = bytes.readUint16(),
    unitsPerEm = bytes.readUint16(),
    created = bytes.readUint64(),
    modified = bytes.readUint64(),
    xMin = bytes.readInt16(),
    yMin = bytes.readInt16(),
    xMax = bytes.readInt16(),
    yMax = bytes.readInt16(),
    macStyle = bytes.readUint16(),
    lowestRecPPEM = bytes.readUint16(),
    fontDirectionHint = bytes.readInt16(),
    indexToLocFormat = bytes.readInt16(),
    glyphDataFormat = bytes.readInt16();
}

class Cmap {
  late final int version;
  late final int numTables;
  late final List<EncodingRecord> encodingRecords;

  Cmap.read(ByteDataWrapper bytes) {
    int cmapOffset = bytes.position;
    version = bytes.readUint16();
    numTables = bytes.readUint16();
    encodingRecords = List.generate(numTables, (i) => EncodingRecord.read(bytes, cmapOffset));
  }
}

class EncodingRecord {
  final int platformID;
  final int encodingID;
  final int offset;
  late final CmapFormat? format;

  EncodingRecord.read(ByteDataWrapper bytes, int cmapOffset) :
    platformID = bytes.readUint16(),
    encodingID = bytes.readUint16(),
    offset = bytes.readUint32() {
    int previous = bytes.position;
    bytes.position = cmapOffset + offset;
    format = CmapFormat.read(bytes);
    bytes.position = previous;
  }
}
abstract class CmapFormat {
  late final int format;
  static CmapFormat? read(ByteDataWrapper bytes) {
    int format = bytes.readUint16();
    bytes.position -= 2;
    switch (format) {
      case 0:
        return CmapFormat0.read(bytes);
      case 4:
        return CmapFormat4.read(bytes);
      case 6:
        return CmapFormat6.read(bytes);
      case 12:
      case 13:
        return CmapFormat1213.read(bytes);
      default:
        // return CmapFormatUnknown.read(bytes);
        return null;
    }
  }

  int? getGlyphIndex(String char);
}
class CmapFormat0 implements CmapFormat {
  late final int format;
  late final int length;
  late final int language;
  late final List<int> glyphIndexArray;

  CmapFormat0.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
    length = bytes.readUint16();
    language = bytes.readUint16();
    glyphIndexArray = bytes.readUint8List(256);
  }

  @override
  int? getGlyphIndex(String char) {
    if (char.length != 1)
      throw Exception("Invalid character: $char");
    int code = char.codeUnitAt(0);
    if (code >= 256)
      return null;
    return glyphIndexArray[code];
  }
}
class CmapFormat4 implements CmapFormat {
  late final int format;
  late final int length;
  late final int language;
  late final int segCountX2;
  late final int searchRange;
  late final int entrySelector;
  late final int rangeShift;
  late final List<int> endCode;
  late final int reservedPad;
  late final List<int> startCode;
  late final List<int> idDelta;
  final Map<int, int> glyphToIndexMap = {};

  CmapFormat4.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
    length = bytes.readUint16();
    language = bytes.readUint16();
    segCountX2 = bytes.readUint16();
    searchRange = bytes.readUint16();
    entrySelector = bytes.readUint16();
    rangeShift = bytes.readUint16();
    var segCount = segCountX2 ~/ 2;
    endCode = bytes.readUint16List(segCount);
    reservedPad = bytes.readUint16();
    startCode = bytes.readUint16List(segCount);
    idDelta = bytes.readInt16List(segCount);
    for (int i = 0; i < segCount - 1; i++) {
      int start = startCode[i];
      int end = endCode[i];
      int delta = idDelta[i];
      int pos = bytes.position;
      int idRangeOffset = bytes.readUint16();
      for (int c = start; c <= end; c++) {
        int glyphIndex;
        if (idRangeOffset == 0) {
          glyphIndex = (c + delta) & 0xFFFF;
        } else {
          int prevPos = bytes.position;
          int offset = pos + idRangeOffset + (c - start) * 2;
          bytes.position = offset;
          glyphIndex = bytes.readUint16();
          bytes.position = prevPos;
          if (glyphIndex != 0)
            glyphIndex = (glyphIndex + delta) & 0xFFFF;
        }
        glyphToIndexMap[c] = glyphIndex;
      }
    }
  }

  @override
  int? getGlyphIndex(String char) {
    if (char.length != 1)
      throw Exception("Invalid character: $char");
    int code = char.codeUnitAt(0);
    return glyphToIndexMap[code];
  }
}
class CmapFormat6 implements CmapFormat {
  late final int format;
  late final int length;
  late final int language;
  late final int firstCode;
  late final int entryCount;
  late final List<int> glyphIndexArray;

  CmapFormat6.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
    length = bytes.readUint16();
    language = bytes.readUint16();
    firstCode = bytes.readUint16();
    entryCount = bytes.readUint16();
    glyphIndexArray = bytes.readUint16List(entryCount);
  }

  @override
  int? getGlyphIndex(String char) {
    if (char.length != 1)
      throw Exception("Invalid character: $char");
    int code = char.codeUnitAt(0);
    if (code < firstCode || code >= firstCode + entryCount)
      return null;
    return glyphIndexArray[code - firstCode];
  }
}
class CmapFormat1213 implements CmapFormat {
  late final int format;
  late final int length;
  late final int language;
  late final int numGroups;
  late final List<GroupRecord> groupRecords;

  CmapFormat1213.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
    length = bytes.readUint32();
    language = bytes.readUint32();
    numGroups = bytes.readUint32();
    groupRecords = List.generate(numGroups, (i) => GroupRecord.read(bytes));
  }

  @override
  int? getGlyphIndex(String char) {
    if (char.length != 1)
      throw Exception("Invalid character: $char");
    int code = char.codeUnitAt(0);
    var group = binarySearch(groupRecords, (group) => group.compareTo(code));
    if (group == null)
      return null;
    if (format == 12)
      return group.id + code - group.startCharCode;
    else
      return group.id;
  }
}
class GroupRecord extends Range {
  late final int id;

  GroupRecord.read(ByteDataWrapper bytes) {
    start = bytes.readUint32();
    end = bytes.readUint32();
    id = bytes.readUint32();
  }

  int get startCharCode => start;
  int get endCharCode => end;
}
class CmapFormatUnknown implements CmapFormat {
  late final int format;

  CmapFormatUnknown.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
  }

  @override
  int? getGlyphIndex(String char) {
    return null;
  }
}


class KernHeader {
  final int version;
  final int nTables;

  KernHeader.read(ByteDataWrapper bytes) :
    version = bytes.readUint16(),
    nTables = bytes.readUint16();
}

class KernCoverage {
  final int format;
  final int flags;

  KernCoverage.read(ByteDataWrapper bytes) :
    format = bytes.readUint8(),
    flags = bytes.readUint8();

  bool get horizontal => flags & 1 == 1;
  bool get minimum => flags & 2 == 2;
  bool get crossStream => flags & 4 == 4;
  bool get override => flags & 8 == 8;
}

class KernSubtableFormat0 {
  final int nPairs;
  final int searchRange;
  final int entrySelector;
  final int rangeShift;
  late final List<KernPair> pairs;

  KernSubtableFormat0.read(ByteDataWrapper bytes) :
    nPairs = bytes.readUint16(),
    searchRange = bytes.readUint16(),
    entrySelector = bytes.readUint16(),
    rangeShift = bytes.readUint16() {
    pairs = List.generate(nPairs, (i) => KernPair.read(bytes));
  }
}

class KernPair {
  final int left;
  final int right;
  final int value;

  KernPair.read(ByteDataWrapper bytes) :
    left = bytes.readUint16(),
    right = bytes.readUint16(),
    value = bytes.readInt16();
}

class KernSubTable {
  final int version;
  final int length;
  final KernCoverage coverage;
  KernSubtableFormat0? format;

  KernSubTable.read(ByteDataWrapper bytes) :
    version = bytes.readUint16(),
    length = bytes.readUint16(),
    coverage = KernCoverage.read(bytes) {
    switch (coverage.format) {
      case 0:
        format = KernSubtableFormat0.read(bytes);
        break;
    }
  }
}

class KernTable {
  final KernHeader header;
  late final List<KernSubTable> subTables;

  KernTable.read(ByteDataWrapper bytes) :
    header = KernHeader.read(bytes) {
    if (header.version != 0)
      throw Exception("Unsupported kern table version: ${header.version}");
    subTables = List.generate(header.nTables, (i) => KernSubTable.read(bytes));
  }

  int? getKernValue(int left, int right) {
    for (var subTable in subTables) {
      if (subTable.coverage.horizontal) {
        var pair = binarySearch(subTable.format!.pairs, (pair) {
          if (pair.left < left)
            return -1;
          if (pair.left > left)
            return 1;
          if (pair.right < right)
            return -1;
          if (pair.right > right)
            return 1;
          return 0;
        });
        if (pair != null)
          return pair.value;
      }
    }
    return null;
  }
}

class GposHeader {
  final TtVersion version;
  final int scriptList;
  final int featureList;
  final int lookupList;

  GposHeader.read(ByteDataWrapper bytes) :
    version = TtVersion.read(bytes),
    scriptList = bytes.readUint16(),
    featureList = bytes.readUint16(),
    lookupList = bytes.readUint16() {
    if (version.major == 1 && version.minor == 1)
      bytes.readUint32();
    else if (version.major != 1 || version.minor != 0)
      throw Exception("Unsupported GPOS table version: ${version.major}.${version.minor}");
  }
}

class ScriptListTable {
  final int scriptCount;
  late final List<ScriptRecord> scripts;

  ScriptListTable.read(ByteDataWrapper bytes) :
    scriptCount = bytes.readUint16() {
    int scriptOffsetBegin = bytes.position - 2;
    scripts = List.generate(scriptCount, (i) => ScriptRecord.read(bytes, scriptOffsetBegin));
  }
}

class ScriptRecord {
  final String tag;
  final int offset;
  late final ScriptTable table;

  ScriptRecord.read(ByteDataWrapper bytes, int offsetBegin) :
    tag = bytes.readString(4),
    offset = bytes.readUint16() {
    int previous = bytes.position;
    bytes.position = offsetBegin + offset;
    table = ScriptTable.read(bytes);
    bytes.position = previous;
  }
}

class ScriptTable {
  final int defaultLangSysOffset;
  final int langSysCount;
  LangSysTable? defaultLangSys;
  late final List<LangSysRecord> langSysRecords;

  ScriptTable.read(ByteDataWrapper bytes) :
    defaultLangSysOffset = bytes.readUint16(),
    langSysCount = bytes.readUint16() {
    int selfOffset = bytes.position - 4;
    langSysRecords = List.generate(langSysCount, (i) => LangSysRecord.read(bytes, selfOffset));
    if (defaultLangSysOffset != 0) {
      int previous = bytes.position;
      bytes.position = selfOffset + defaultLangSysOffset;
      defaultLangSys = LangSysTable.read(bytes);
      bytes.position = previous;
    }
  }
}

class LangSysRecord {
  final String tag;
  final int offset;
  late final LangSysTable table;

  LangSysRecord.read(ByteDataWrapper bytes, int offsetBegin) :
    tag = bytes.readString(4),
    offset = bytes.readUint16() {
    int previous = bytes.position;
    bytes.position = offsetBegin + offset;
    table = LangSysTable.read(bytes);
    bytes.position = previous;
  }
}

class LangSysTable {
  final int lookupOrder;
  final int reqFeatureIndex;
  final int featureIndexCount;
  late final List<int> featureIndices;

  LangSysTable.read(ByteDataWrapper bytes) :
    lookupOrder = bytes.readUint16(),
    reqFeatureIndex = bytes.readUint16(),
    featureIndexCount = bytes.readUint16() {
    featureIndices = bytes.readUint16List(featureIndexCount);
  }
}

class FeatureListTable {
  final int featureCount;
  late final List<FeatureRecord> features;

  FeatureListTable.read(ByteDataWrapper bytes) :
    featureCount = bytes.readUint16() {
    int featureOffsetBegin = bytes.position - 2;
    features = List.generate(featureCount, (i) => FeatureRecord.read(bytes, featureOffsetBegin));
  }

  Iterable<int> getFeatureIndices(String tag) {
    return HashSet.from(features
      .where((feature) => feature.tag == tag)
      .map((feature) => feature.table.lookupListIndices)
      .expand((i) => i)
      // .toSet()
    );
  }
}

class FeatureRecord {
  final String tag;
  final int offset;
  late final FeatureTable table;

  FeatureRecord.read(ByteDataWrapper bytes, int offsetBegin) :
    tag = bytes.readString(4),
    offset = bytes.readUint16() {
    int previous = bytes.position;
    bytes.position = offsetBegin + offset;
    table = FeatureTable.read(bytes);
    bytes.position = previous;
  }
}

class FeatureTable {
  final int featureParamsOffset;
  final int lookupIndexCount;
  late final List<int> lookupListIndices;

  FeatureTable.read(ByteDataWrapper bytes) :
    featureParamsOffset = bytes.readUint16(),
    lookupIndexCount = bytes.readUint16() {
    lookupListIndices = bytes.readUint16List(lookupIndexCount);
  }
}

class LookupListTable {
  final int lookupCount;
  late final List<int> lookupOffsets;
  late final List<LookupTable> lookups;

  LookupListTable.read(ByteDataWrapper bytes) :
    lookupCount = bytes.readUint16() {
    int lookupOffsetBegin = bytes.position - 2;
    lookupOffsets = bytes.readUint16List(lookupCount);
    lookups = List.generate(lookupCount, (i) {
      bytes.position = lookupOffsetBegin + lookupOffsets[i];
      return LookupTable.read(bytes, lookupOffsetBegin);
    });
  }
}

class LookupTable {
  final int selfOffset;
  final int lookupType;
  final int lookupFlag;
  final int subTableCount;
  late final List<int> subTableOffsets;
  late final int markFilteringSet;
  late final List<LookupSubTable?> subTables;

  LookupTable.read(ByteDataWrapper bytes, int offsetBegin) :
    selfOffset = bytes.position,
    lookupType = bytes.readUint16(),
    lookupFlag = bytes.readUint16(),
    subTableCount = bytes.readUint16() {
    subTableOffsets = bytes.readUint16List(subTableCount);
    const useMarkFilteringSet = 0x0010;
    markFilteringSet = lookupFlag & useMarkFilteringSet == useMarkFilteringSet ? bytes.readUint16() : 0;
    subTables = List.generate(subTableCount, (i) {
      bytes.position = selfOffset + subTableOffsets[i];
      return LookupSubTable.read(bytes, lookupType);
    });
  }
}

class LookupSubTable {
  static LookupSubTable? read(ByteDataWrapper bytes, int lookupType) {
    int format = bytes.readUint16();
    bytes.position -= 2;
    switch (lookupType) {
      case 2:
        switch (format) {
          case 1:
            return PairPosFormat1.read(bytes);
          case 2:
            return PairPosFormat2.read(bytes);
        }
        break;
      case 9:
        return PosExtensionFormat1.read(bytes);
    }
    return null;
  }
}

abstract class LookupSubTableKern extends LookupSubTable {
  int? getKernValue(int left, int right);
}

class PosExtensionFormat1 extends LookupSubTable {
  static LookupSubTable? read(ByteDataWrapper bytes) {
    int selfOffset = bytes.position;
    // ignore: unused_local_variable
    int format = bytes.readUint16();
    int extensionLookupType = bytes.readUint16();
    int extensionOffset = bytes.readUint32();
    bytes.position = selfOffset + extensionOffset;
    return LookupSubTable.read(bytes, extensionLookupType);
  }
}

abstract class CoverageTable {
  static CoverageTable read(ByteDataWrapper bytes) {
    int format = bytes.readUint16();
    bytes.position -= 2;
    switch (format) {
      case 1:
        return CoverageFormat1.read(bytes);
      case 2:
        return CoverageFormat2.read(bytes);
      default:
        throw Exception("Unsupported coverage format: $format");
    }
  }

  int? getCoverageIndex(int glyphID);
}
class CoverageFormat1 implements CoverageTable {
  late final int format;
  late final int glyphCount;
  late final List<int> glyphArray;

  CoverageFormat1.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
    glyphCount = bytes.readUint16();
    glyphArray = bytes.readUint16List(glyphCount);
  }

  @override
  int? getCoverageIndex(int glyphID) {
    int index = glyphArray.indexOf(glyphID);
    return index == -1 ? null : index;
  }
}
class CoverageFormat2 implements CoverageTable {
  late final int format;
  late final int rangeCount;
  late final List<CoverageRangeRecord> rangeRecords;

  CoverageFormat2.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
    rangeCount = bytes.readUint16();
    rangeRecords = List.generate(rangeCount, (i) => CoverageRangeRecord.read(bytes));
  }

  @override
  int? getCoverageIndex(int glyphID) {
    var range = binarySearch(rangeRecords, (range) => range.compareTo(glyphID));
    if (range == null)
      return null;
    return range.startCoverageIndex + glyphID - range.start;
  }
}
class CoverageRangeRecord extends Range {
  late final int startCoverageIndex;

  CoverageRangeRecord.read(ByteDataWrapper bytes) {
    start = bytes.readUint16();
    end = bytes.readUint16();
    startCoverageIndex = bytes.readUint16();
  }
}

abstract class ClassDefTable {
  static ClassDefTable read(ByteDataWrapper bytes) {
    int format = bytes.readUint16();
    bytes.position -= 2;
    switch (format) {
      case 1:
        return ClassDefFormat1.read(bytes);
      case 2:
        return ClassDefFormat2.read(bytes);
      default:
        throw Exception("Unsupported class def format: $format");
    }
  }

  int getClassValue(int glyphID);
}
class ClassDefFormat1 implements ClassDefTable {
  late final int format;
  late final int startGlyphID;
  late final int glyphCount;
  late final List<int> classValues;

  ClassDefFormat1.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
    startGlyphID = bytes.readUint16();
    glyphCount = bytes.readUint16();
    classValues = bytes.readUint16List(glyphCount);
  }

  @override
  int getClassValue(int glyphID) {
    if (glyphID < startGlyphID || glyphID >= startGlyphID + glyphCount)
      return 0;
    return classValues[glyphID - startGlyphID];
  }
}
class ClassDefFormat2 implements ClassDefTable {
  late final int format;
  late final int classRangeCount;
  late final List<ClassRangeRecord> classRangeRecords;

  ClassDefFormat2.read(ByteDataWrapper bytes) {
    format = bytes.readUint16();
    classRangeCount = bytes.readUint16();
    classRangeRecords = List.generate(classRangeCount, (i) => ClassRangeRecord.read(bytes));
  }
  
  @override
  int getClassValue(int glyphID) {
    var range = binarySearch(classRangeRecords, (range) => range.compareTo(glyphID));
    if (range == null)
      return 0;
    return range.classValue;
  }
}
class ClassRangeRecord extends Range {
  late final int classValue;

  ClassRangeRecord.read(ByteDataWrapper bytes) {
    start = bytes.readUint16();
    end = bytes.readUint16();
    classValue = bytes.readUint16();
  }
}

class PairPosFormat1 implements LookupSubTableKern {
  late final int format;
  late final int coverageOffset;
  late final int valueFormat1;
  late final int valueFormat2;
  late final int pairSetCount;
  late final List<int> pairSetOffsets;
  late final CoverageTable coverage;
  late final List<PairSet> pairSets;

  PairPosFormat1.read(ByteDataWrapper bytes) {
    int selfOffset = bytes.position;
    format = bytes.readUint16();
    coverageOffset = bytes.readUint16();
    valueFormat1 = bytes.readUint16();
    valueFormat2 = bytes.readUint16();
    pairSetCount = bytes.readUint16();
    pairSetOffsets = bytes.readUint16List(pairSetCount);
    bytes.position = selfOffset + coverageOffset;
    coverage = CoverageTable.read(bytes);
    pairSets = List.generate(pairSetCount, (i) {
      bytes.position = selfOffset + pairSetOffsets[i];
      return PairSet.read(bytes, valueFormat1, valueFormat2);
    });
  }

  @override
  int? getKernValue(int left, int right) {
    if (valueFormat1 & 4 == 0)
      return null;
    int? coverageIndex = coverage.getCoverageIndex(left);
    if (coverageIndex == null)
      return null;
    var pairSet = pairSets[coverageIndex];
    var pairValueRecord = binarySearch(pairSet.pairValueRecords, (pairValueRecord) {
      if (pairValueRecord.secondGlyph < right)
        return -1;
      if (pairValueRecord.secondGlyph > right)
        return 1;
      return 0;
    });
    return pairValueRecord?.value1.xAdvance;
  }
}

class PairSet {
  late final int pairValueCount;
  late final List<PairValueRecord> pairValueRecords;

  PairSet.read(ByteDataWrapper bytes, int valueFormat1, int valueFormat2) {
    pairValueCount = bytes.readUint16();
    pairValueRecords = List.generate(pairValueCount, (i) => PairValueRecord.read(bytes, valueFormat1, valueFormat2));
  }
}

class PairValueRecord {
  final int secondGlyph;
  final ValueRecord value1;
  final ValueRecord value2;

  PairValueRecord.read(ByteDataWrapper bytes, int valueFormat1, int valueFormat2) :
    secondGlyph = bytes.readUint16(),
    value1 = ValueRecord.read(bytes, valueFormat1),
    value2 = ValueRecord.read(bytes, valueFormat2);
}

class ValueRecord {
  final int xPlacement;
  final int yPlacement;
  final int xAdvance;
  final int yAdvance;

  ValueRecord.read(ByteDataWrapper bytes, int valueFormat) :
    xPlacement = valueFormat & 1 != 0 ? bytes.readInt16() : 0,
    yPlacement = valueFormat & 2 != 0 ? bytes.readInt16() : 0,
    xAdvance = valueFormat & 4 != 0 ? bytes.readInt16() : 0,
    yAdvance = valueFormat & 8 != 0 ? bytes.readInt16() : 0 {
    if (valueFormat & 0x10 != 0)
      bytes.readUint16();
    if (valueFormat & 0x20 != 0)
      bytes.readUint16();
    if (valueFormat & 0x40 != 0)
      bytes.readUint16();
    if (valueFormat & 0x80 != 0)
      bytes.readUint16();
    if (valueFormat & 0xFF00 != 0)
      throw Exception("Unsupported value format: $valueFormat");
  }
}

class PairPosFormat2 implements LookupSubTableKern {
  late final int format;
  late final int coverageOffset;
  late final int valueFormat1;
  late final int valueFormat2;
  late final int classDef1Offset;
  late final int classDef2Offset;
  late final int class1Count;
  late final int class2Count;
  late final List<List<Class2Record>> classRecords;
  late final CoverageTable coverage;
  late final ClassDefTable classDef1;
  late final ClassDefTable classDef2;

  PairPosFormat2.read(ByteDataWrapper bytes) {
    int selfOffset = bytes.position;
    format = bytes.readUint16();
    coverageOffset = bytes.readUint16();
    valueFormat1 = bytes.readUint16();
    valueFormat2 = bytes.readUint16();
    classDef1Offset = bytes.readUint16();
    classDef2Offset = bytes.readUint16();
    class1Count = bytes.readUint16();
    class2Count = bytes.readUint16();
    classRecords = List.generate(class1Count, (i) {
      return List.generate(class2Count, (j) => Class2Record.read(bytes, valueFormat1, valueFormat2));
    });
    bytes.position = selfOffset + coverageOffset;
    coverage = CoverageTable.read(bytes);
    bytes.position = selfOffset + classDef1Offset;
    classDef1 = ClassDefTable.read(bytes);
    bytes.position = selfOffset + classDef2Offset;
    classDef2 = ClassDefTable.read(bytes);
  }

  @override
  int? getKernValue(int left, int right) {
    if (valueFormat1 & 4 == 0)
      return null;
    int? coverageIndex = coverage.getCoverageIndex(left);
    if (coverageIndex == null)
      return null;
    int class1 = classDef1.getClassValue(left);
    int class2 = classDef2.getClassValue(right);
    return classRecords[class1][class2].valueRecord1.xAdvance;
  }
}
class Class2Record {
  final ValueRecord valueRecord1;
  final ValueRecord valueRecord2;

  Class2Record.read(ByteDataWrapper bytes, int valueFormat1, int valueFormat2) :
    valueRecord1 = ValueRecord.read(bytes, valueFormat1),
    valueRecord2 = ValueRecord.read(bytes, valueFormat2);
}

class Gpos {
  late final GposHeader header;
  late final ScriptListTable scriptList;
  late final FeatureListTable featureList;
  late final LookupListTable? lookupList;

  Gpos.read(ByteDataWrapper bytes) {
    int selfOffset = bytes.position;
    header = GposHeader.read(bytes);
    int previous = bytes.position;
    bytes.position = selfOffset + header.scriptList;
    scriptList = ScriptListTable.read(bytes);
    bytes.position = selfOffset + header.featureList;
    featureList = FeatureListTable.read(bytes);
    if (header.lookupList != 0) {
      bytes.position = selfOffset + header.lookupList;
      lookupList = LookupListTable.read(bytes);
    }
    else {
      lookupList = null;
    }
    bytes.position = previous;
  }

  int? getKernValue(int left, int right) {
    if (lookupList == null)
      return null;
    var kernLookups = featureList.getFeatureIndices("kern");
    for (var lookupIndex in kernLookups) {
      var lookup = lookupList!.lookups[lookupIndex];
      for (var subtable in lookup.subTables) {
        if (subtable is LookupSubTableKern) {
          int? value = subtable.getKernValue(left, right);
          if (value != null)
            return value;
        }
      }
    }
    return null;
  }
}

class TtfFile {
  late final TtOffsetTable offsetTable;
  late final List<TtTable> tables;
  late final TtHead head;
  late final Cmap cmap;
  KernTable? kern;
  Gpos? gpos;

  TtfFile.read(ByteDataWrapper bytes) {
    bytes.endian = Endian.big;
    offsetTable = TtOffsetTable.read(bytes);
    tables = List.generate(offsetTable.numTables, (i) => TtTable.read(bytes));
    bool hasHead = false;
    bool hasCmap = false;
    for (var table in tables) {
      switch (table.tag) {
        case "head":
          bytes.position = table.offset;
          head = TtHead.read(bytes);
          hasHead = true;
          break;
        case "cmap":
          bytes.position = table.offset;
          cmap = Cmap.read(bytes);
          hasCmap = true;
          break;
        case "kern":
          bytes.position = table.offset;
          kern = KernTable.read(bytes);
          break;
        case "GPOS":
          bytes.position = table.offset;
          gpos = Gpos.read(bytes);
          break;
      }

    }

    if (!hasHead)
      throw Exception("Missing head table");
    if (!hasCmap)
      throw Exception("Missing cmap table");
  }

  int? getGlyphIndex(String char) {
    return cmap.encodingRecords
      .map((record) => record.format?.getGlyphIndex(char))
      .firstWhere((index) => index != null, orElse: () => null);
  }

  int getKerning(String left, String right) {
    int? leftIndex = getGlyphIndex(left);
    int? rightIndex = getGlyphIndex(right);
    if (leftIndex == null || rightIndex == null)
      return 0;
    int? value = gpos?.getKernValue(leftIndex, rightIndex);
    // if (value != null && kern != null)
    //   assert (value == kern!.getKernValue(leftIndex, rightIndex));
    value ??= kern?.getKernValue(leftIndex, rightIndex);
    return value ?? 0;
  }

  double getKerningScaled(String left, String right, int fontSize) {
    return getKerning(left, right) * fontSize / head.unitsPerEm;
  }
}
