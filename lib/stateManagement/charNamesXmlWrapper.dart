
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:convert/convert.dart';
import 'package:xml/xml.dart';

import '../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../utils.dart';
import '../widgets/propEditors/customXmlProps/tableEditor.dart';
import 'Property.dart';
import 'hasUuid.dart';
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

class CharNameTranslations with HasUuid {
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
  bool ignoreUpdates = false;

  CharNamesXmlProp({ super.file, super.children })
    : super(tagId: textHash, tagName: "text", value: StringProp(""), parentTags: []) {
    
    name = "Character Names";
    columnNames = [
      "KEY",
      ..._nameKeys
    ];
    rowCount = NumberProp(0, true);
    rowCount.changesUndoable = false;
    
    deserialize();

    anyChangeNotifier.addListener(() {
      serialize();
      file?.hasUnsavedChanges = true;
      file?.contentNotifier.notifyListeners();
      undoHistoryManager.onUndoableEvent();
    });
  }

  @override
  void notifyListeners() {
    if (ignoreUpdates)
      return;
    ignoreUpdates = true;
    super.notifyListeners();
    ignoreUpdates = false;
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
    print("deserialize");
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
    for (int i = 0; i < min(names.length, newNames.length); i++) {
      names[i].key.value = newNames[i].key.value;
      // update translations
      for (int j = 0; j < min(names[i].translations.length, newNames[i].translations.length); j++) {
        names[i].translations[j].key.value = newNames[i].translations[j].key.value;
        names[i].translations[j].val.value = newNames[i].translations[j].val.value;
      }
      // add new translations
      if (names[i].translations.length < newNames[i].translations.length) {
        for (int j = names[i].translations.length; j < newNames[i].translations.length; j++) {
          names[i].translations.add(newNames[i].translations[j]);
        }
      }
      // remove old translations
      else if (names[i].translations.length > newNames[i].translations.length) {
        for (int j = names[i].translations.length - 1; j >= newNames[i].translations.length; j--) {
          names[i].translations.removeAt(j);
        }
      }
    }
    // add new names
    if (names.length < newNames.length) {
      for (int i = names.length; i < newNames.length; i++) {
        names.add(newNames[i]);
      }
    }
    // remove old names
    else if (names.length > newNames.length) {
      for (int i = names.length - 1; i >= newNames.length; i--) {
        names.removeAt(i);
      }
    }
    rowCount.value = names.length;
    rowCount.notifyListeners();
  }

  void serialize() {
    print("serialize");
    // convert translations to lines
    var lines = <String>[];
    for (var name in names) {
      lines.add(" ${name.key.value}");
      for (var translation in name.translations) {
        lines.add("  ${translation.key.value} ${translation.val.value}");
      }
    }

    // convert lines to hex string
    const firstLine = " �L�������O�e�[�u��";
    const lastLine = "";
    lines.insert(0, firstLine);
    lines.add(lastLine);
    var text = lines.join("\n");
    _lastString = text;
    var bytes = encodeString(text, StringEncoding.utf8);
    var hexStr = hex.encode(bytes);

    // convert hex string to prop rows
    var rows = <String>[];
    for (var i = 0; i < hexStr.length; i += 64) {
      rows.add(hexStr.substring(i, (min(i + 64, hexStr.length))));
    }

    // update
    var textProp = get("text")!;
    textProp.clear();
    textProp.addAll(rows.map((r) => XmlProp(
      file: file,
      tagId: valueHash,
      tagName: "value",
      parentTags: parentTags,
      value: StringProp(r),
    )));

    // debug print XML
    var doc = XmlDocument();
    doc.children.add(toXml());
    print(doc.toXmlString(pretty: true));
  }

  @override
  RowConfig rowPropsGenerator(int index) {
    var name = names[index];
    RowConfig row = RowConfig(
      key: Key(name.uuid),
      cells: [CellConfig(prop: name.key)]
    );
    var cells = row.cells;
    int ti = 0;
    for (int i = 0; i < _nameKeys.length; i++) {
      if (name.translations[ti].key.value == _nameKeys[i]) {
        cells.add(CellConfig(prop: name.translations[ti].val));
        ti++;
      }
      else {
        cells.add(null);
      }
    }
    
    return row;
  }

  @override
  void onRowAdd() {
    names.add(CharNameTranslations(
      StringProp(""),
      _nameKeys.map((k) => KeyValProp(StringProp(k), StringProp(""))).toList(),
      anyChangeNotifier
    ));
    rowCount.value++;
    serialize();
  }

  @override
  void onRowRemove(int index) {
    names.removeAt(index);
    rowCount.value--;
    serialize();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = CharNamesXmlProp(
      file: file,
      children: map((p) => p.takeSnapshot() as XmlProp).toList(),
    );
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var snapshotProp = snapshot as CharNamesXmlProp;
    var textProp = get("text")!;
    textProp.clear();
    textProp.addAll(snapshotProp.get("text")!.map((p) => p.takeSnapshot() as XmlProp));
    deserialize();
  }
}
