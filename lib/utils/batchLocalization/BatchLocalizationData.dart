
enum BatchLocalizationLanguage {
  jp, de, es, fr, it, us, kor, cn;

  static BatchLocalizationLanguage fromString(String value) {
    for (final language in values) {
      if (language.name == value) {
        return language;
      }
    }
    throw Exception("Invalid language: $value");
  }
}

class BatchLocalizationData {
  final List<BatchLocalizationFileData> files;
  final BatchLocalizationLanguage language;

  BatchLocalizationData(this.files, this.language);

  factory BatchLocalizationData.read(StringReader reader) {
    var langKey = reader.readUntil(_listSeparator);
    assert(langKey == "Original Language");
    final langStr = reader.readUntil("\n$_fileSeparator");
    final language = BatchLocalizationLanguage.fromString(langStr);
    final files = <BatchLocalizationFileData>[];
    while (!reader.isEOF) {
      files.add(BatchLocalizationFileData.read(reader));
    }
    return BatchLocalizationData(files, language);
  }

  factory BatchLocalizationData.fromJson(Map json) {
    final language = BatchLocalizationLanguage.fromString(json["originalLanguage"]);
    final files = (json["files"] as List).map((e) => BatchLocalizationFileData.fromJson(e)).toList();
    return BatchLocalizationData(files, language);
  }

  void writeString(StringSink sink) {
    sink.write("Original Language");
    sink.write(_listSeparator);
    sink.write(language.name);
    sink.writeln();
    sink.write(_fileSeparator);
    for (final file in files) {
      file.writeString(sink);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "originalLanguage": language.name,
      "files": files.map((e) => e.toJson()).toList()
    };
  }
}

class BatchLocalizationFileData {
  final String datName;
  final String fileName;
  final List<BatchLocalizationEntryData> entries;

  BatchLocalizationFileData(this.datName, this.fileName, this.entries);

  factory BatchLocalizationFileData.read(StringReader reader) {
    final datName = reader.readUntil(_listSeparator);
    final fileName = reader.readUntil("\n");
    final entries = <BatchLocalizationEntryData>[];
    var fileEndIndex = reader.indexOf(_fileSeparator);
    while (true) {
      var entryEndIndex = reader.indexOf(_entrySeparator);
      if (entryEndIndex == -1 || entryEndIndex > fileEndIndex)
        break;
      entries.add(BatchLocalizationEntryData.read(reader));
    }
    reader.readUntil(_fileSeparator);
    return BatchLocalizationFileData(datName, fileName, entries);
  }

  factory BatchLocalizationFileData.fromJson(Map json) {
    final datName = json["datName"];
    final fileName = json["fileName"];
    final entries = (json["entries"] as List).map((e) => BatchLocalizationEntryData.fromJson(e)).toList();
    return BatchLocalizationFileData(datName, fileName, entries);
  }

  void writeString(StringSink sink) {
    sink.write(datName);
    sink.write(_listSeparator);
    sink.write(fileName);
    sink.writeln();
    for (final entry in entries) {
      entry.writeString(sink);
    }
    sink.write(_fileSeparator);
  }

  Map<String, dynamic> toJson() {
    return {
      "datName": datName,
      "fileName": fileName,
      "entries": entries.map((e) => e.toJson()).toList()
    };
  }

  Map<String, String> asMap() {
    return {
      for (final entry in entries)
        entry.key: entry.value
    };
  }
  
  Map<String, List<String>> asMapOfLists() {
    Map<String, List<String>> result = {};
    for (final entry in entries) {
      if (!result.containsKey(entry.key)) {
        result[entry.key] = [];
      }
      result[entry.key]!.add(entry.value);
    }
    return result;
  }
}

class BatchLocalizationEntryData {
  final String key;
  final String value;

  BatchLocalizationEntryData(this.key, this.value);

  factory BatchLocalizationEntryData.read(StringReader reader) {
    final key = reader.readUntil(":\n");
    final value = reader.readUntil("\n$_entrySeparator");
    return BatchLocalizationEntryData(key, value);
  }
  
  factory BatchLocalizationEntryData.fromJson(Map json) {
    return BatchLocalizationEntryData(json["key"], json["value"]);
  }

  void writeString(StringSink sink) {
    sink.write(key);
    sink.write(":\n");
    sink.write(value);
    sink.writeln();
    sink.write(_entrySeparator);
  }

  Map<String, dynamic> toJson() {
    return {
      "key": key,
      "value": value
    };
  }
}

const _listSeparator = " -> ";
const _entrySeparator = "----\n";
const _fileSeparator = "====\n";

class StringReader {
  final String _string;
  int _position = 0;

  StringReader(this._string);

  bool get isEOF => _position >= _string.length;

  int indexOf(String pattern) {
    return _string.indexOf(pattern, _position);
  }

  String readUntil(String pattern) {
    final index = _string.indexOf(pattern, _position);
    if (index == -1) {
      throw Exception("Pattern not found");
    }
    final result = _string.substring(_position, index);
    _position = index + pattern.length;
    return result;
  }
}
