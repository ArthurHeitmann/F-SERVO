
import 'package:flutter/material.dart';
import 'package:convert/convert.dart';

import '../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../utils.dart';
import '../widgets/propEditors/customXmlProps/tableEditor.dart';
import 'Property.dart';
import 'undoable.dart';
import 'xmlProps/xmlProp.dart';

class KeyValProp extends ChangeNotifier {
  StringProp key;
  StringProp val;
  KeyValProp(this.key, this.val) {
    key.addListener(notifyListeners);
    val.addListener(notifyListeners);
  }
}

class CharNameTranslations {
  final ChangeNotifier anyChangeNotifier;
  StringProp key;
  List<KeyValProp> translations;

  CharNameTranslations(this.key, this.translations, this.anyChangeNotifier) {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    key.addListener(anyChangeNotifier.notifyListeners);
    for (var element in translations) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      element.addListener(anyChangeNotifier.notifyListeners);
    }
  }
}

const _nameKeys = [
  "CommonVoice",
  "JPN",
  "ENG",
  "FRA",
  "ITA",
  "GER",
  "ESP",
  "CHT",
  "KOR",
];

class CharNamesXmlProp extends XmlProp with XmlTableConfig {
  static final textHash = crc32("text");
  static final valueHash = crc32("value");

  final List<CharNameTranslations> names = [];
  String _lastString = "";
  final ChangeNotifier anyChangeNotifier = ChangeNotifier();

  CharNamesXmlProp({ super.file, super.children })
    : super(tagId: textHash, tagName: "text", value: StringProp(""), parentTags: []) {
    columnNames = [
      "KEY",
      ..._nameKeys
    ];
    
    deserialize();
    addListener(serialize);

    anyChangeNotifier.addListener(() {
      file?.hasUnsavedChanges = true;
      file?.contentNotifier.notifyListeners();
      undoHistoryManager.onUndoableEvent();
    });
  }

  String _getString() {
    var hexStr = get("text")!.getAll("value")
      .map((t) => (t.value as StringProp).value)
      .join();
    var bytes = hex.decode(hexStr);
    var text = decodeString(bytes, StringEncoding.utf8);
    return text;
  }

  void deserialize() {
    // convert prop rows of hex to single string
    var text = _getString();
    if (text == _lastString)
      return;
    _lastString = text;

    // parse lines into translations
    var lines = text.split("\n");
    lines = lines.sublist(1, lines.length - 1);
    List<CharNameTranslations> newNames = [];
    String currentKey = "";
    List<KeyValProp> currentTranslations = [];
    for (var line in lines) {
      if (line.startsWith("  ")) {
        line = line.substring(2);
        var spaceIndex = line.indexOf(" ");
        var key = line.substring(0, spaceIndex);
        var val = line.substring(spaceIndex + 1);
        currentTranslations.add(KeyValProp(StringProp(key), StringProp(val)));
      }
      else {
        if (currentKey != "") {
          newNames.add(
            CharNameTranslations(
              StringProp(currentKey),
              currentTranslations,
              anyChangeNotifier
            )
          );
        }
        currentKey = line.substring(1);
        currentTranslations = [];
      }
    }

    // update
    names.clear();
    names.addAll(newNames);
  }

  void serialize() {
    // convert translations to lines
    var lines = <String>[];
    for (var name in names) {
      lines.add("  ${name.key.value}");
      for (var translation in name.translations) {
        lines.add("  ${translation.key.value} ${translation.val.value}");
      }
    }

    // convert lines to hex string
    const firstLine = " �ｿｽL�ｿｽ�ｿｽ�ｿｽ�ｿｽ�ｿｽ�ｿｽ�ｿｽO�ｿｽe�ｿｽ[�ｿｽu�ｿｽ�ｿｽ";
    const lastLine = "";
    lines.insert(0, firstLine);
    lines.add(lastLine);
    var text = lines.join("\n");
    var bytes = encodeString(text, StringEncoding.utf8);
    var hexStr = hex.encode(bytes);

    // convert hex string to prop rows
    var rows = <String>[];
    for (var i = 0; i < hexStr.length; i += 64) {
      rows.add(hexStr.substring(i, i + 64));
    }

    // update
    clear();
    addAll(rows.map((r) => XmlProp(
      file: file,
      tagId: textHash,
      tagName: "text",
      parentTags: parentTags,
      value: StringProp(r),
    )));
  }

  @override
  int get rowCount => names.length;

  @override
  List<CellConfig?> rowPropsGenerator(int index) {
    var name = names[index];
    List<CellConfig?> cells = [CellConfig(prop: name.key)];
    int ti = 0;
    for (int i = 0; i < _nameKeys.length; i++) { // TODO reenable
      if (name.translations[ti].key.value == _nameKeys[i]) {
        cells.add(CellConfig(prop: name.translations[ti].val));
        ti++;
      }
      else {
        cells.add(null);
      }
    }
    
    return cells;
  }

  @override
  Undoable takeSnapshot() {
    return CharNamesXmlProp(
      file: file,
      children: map((p) => p.takeSnapshot() as XmlProp).toList(),
    );
  }

  @override
  void restoreWith(Undoable snapshot) {
    var snapshotProp = snapshot as CharNamesXmlProp;
    clear();
    addAll(snapshotProp.map((p) => p.takeSnapshot() as XmlProp));
    deserialize();
  }
}
