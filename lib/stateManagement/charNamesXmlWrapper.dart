
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:convert/convert.dart';

import '../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../utils/utils.dart';
import '../widgets/propEditors/otherFileTypes/genericTable/tableEditor.dart';
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

class CharNamesXmlProp extends XmlProp with CustomTableConfig {
  static final _textHash = crc32("text");
  static final _valueHash = crc32("value");
  static final _sizeHash = crc32("size");

  final List<CharNameTranslations> names = [];
  String _lastString = "";
  final ChangeNotifier anyChangeNotifier = ChangeNotifier();
  bool _ignoreUpdates = false;
  bool _ignoreAnyChanges = false;
  bool _hasPendingAnyChanges = false;

  CharNamesXmlProp({ super.file, super.children })
    : super(tagId: _textHash, tagName: "root", value: StringProp(""), parentTags: []) {
    
    name = "Character Names";
    columnNames = [
      "KEY",
      ..._nameKeys
    ];
    rowCount = NumberProp(0, true);
    rowCount.changesUndoable = false;
    
    deserialize();

    anyChangeNotifier.addListener(() {
      if (_ignoreAnyChanges) {
        _hasPendingAnyChanges = true;
        return;
      }
      serialize();
      file?.hasUnsavedChanges = true;
      file?.contentNotifier.notifyListeners();
      undoHistoryManager.onUndoableEvent();
    });
  }

  @override
  void notifyListeners() {
    if (_ignoreUpdates)
      return;
    _ignoreUpdates = true;
    super.notifyListeners();
    _ignoreUpdates = false;
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
    _ignoreAnyChanges = true;
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
        var keyProp = StringProp(key);
        var valProp = StringProp(val);
        currentTranslations.add(KeyValProp(keyProp, valProp));
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
    newNames.add(
      CharNameTranslations(
        StringProp(currentKey),
        currentTranslations,
        anyChangeNotifier
      )
    );

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

    _ignoreAnyChanges = false;
    if (_hasPendingAnyChanges) {
      _hasPendingAnyChanges = false;
      anyChangeNotifier.notifyListeners();
    }
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
    lines.add("");

    // convert lines to hex string
    var text = lines.join("\n");
    _lastString = text;
    var bytes = encodeString(text, StringEncoding.utf8);
    const firstLine = "20efbfbd4cefbfbdefbfbdefbfbdefbfbdefbfbdefbfbdefbfbd4fefbfbd65efbfbd5befbfbd75efbfbdefbfbd0a";
    var hexStr = firstLine + hex.encode(bytes);

    // convert hex string to prop rows
    var rows = <String>[];
    for (var i = 0; i < hexStr.length; i += 64) {
      rows.add(hexStr.substring(i, (min(i + 64, hexStr.length))));
    }

    // update
    var bytesLength = hexStr.length ~/ 2;
    var textProp = get("text")!;
    textProp.clear();
    textProp.add(XmlProp(
      file: file,
      tagId: _sizeHash,
      tagName: "size",
      parentTags: parentTags,
      value: HexProp(bytesLength),
    ));
    textProp.addAll(rows.map((r) => XmlProp(
      file: file,
      tagId: _valueHash,
      tagName: "value",
      parentTags: parentTags,
      value: StringProp(r),
    )));
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
  void updateRowWith(int index, List<String?> values) {
    if (index > names.length) {
      assert(index == names.length);
      names.add(CharNameTranslations(
        StringProp(values[0]!),
        List.generate(_nameKeys.length, (i) {
          if (values[i] == null)
            return null;
          return KeyValProp(
            StringProp(_nameKeys[i]),
            StringProp(values[i]!),
          );
        })
        .whereType<KeyValProp>()
        .toList(),
        anyChangeNotifier
      ));
      rowCount.value++;
      serialize();
      return;
    }
    var name = names[index];
    name.key.value = values[0]!;
    for (int i = 0; i < _nameKeys.length; i++) {
      if (values[i] == null) {
        name.translations.removeWhere((t) => t.key.value == _nameKeys[i]);
      }
      else if (!name.translations.any((t) => t.key.value == _nameKeys[i])) {
        name.translations.add(
          KeyValProp(StringProp(_nameKeys[i]), StringProp(values[i]!))
        );
      }
      else {
        name.translations
          .firstWhere((t) => t.key.value == _nameKeys[i])
          .val.value = values[i]!;
      }
    }
    serialize();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = CharNamesXmlProp(
      file: file,
      children: map((p) => p.takeSnapshot() as XmlProp).toList(),
    );
    snapshot.overrideUuid(uuid);
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
