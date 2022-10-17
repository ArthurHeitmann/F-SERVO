
import 'package:shared_preferences/shared_preferences.dart';

import '../background/IdLookup.dart';
import 'Property.dart';
import 'nestedNotifier.dart';
import 'openFileTypes.dart';
import 'undoable.dart';

class SavableProp<T> extends ValueProp<T> {
  final String key;

  SavableProp(this.key, SharedPreferences prefs, T fallback)
    : super(prefs.get(key) as T? ?? fallback) {
    addListener(saveChanges);
  }
  
  void saveChanges() {
    var prefs = PreferencesData()._prefs!;
    if (T == String)
      prefs.setString(key, value as String);
    else if (T == int)
      prefs.setInt(key, value as int);
    else if (T == double)
      prefs.setDouble(key, value as double);
    else if (T == bool)
      prefs.setBool(key, value as bool);
    else if (T == List<String>)
      prefs.setStringList(key, value as List<String>);
    else
      throw Exception("Unsupported type: $T");
  }
  
  @override
  PropType get type => throw UnimplementedError();
  @override
  Undoable takeSnapshot() => this;
  @override
  void updateWith(String str) {
  }

}

class PreferencesData extends OpenFileData {
  static PreferencesData? _instance;
  Future<SharedPreferences> prefsFuture;
  SharedPreferences? _prefs;

  IndexingPathsProp? indexingPaths;
  SavableProp<String>? dataExportPath;
  SavableProp<bool>? exportDats;
  SavableProp<bool>? exportPaks;
  SavableProp<bool>? convertXmls;

  PreferencesData._() 
    : prefsFuture = SharedPreferences.getInstance(),
    super("Preferences", "preferences")
  {
    prefsFuture.then((prefs) {
      _prefs = prefs;
      load();
    });
  }
  
  factory PreferencesData() {
    _instance ??= PreferencesData._();
    return _instance!;
  }

  @override
  Future<void> load() async {
    await prefsFuture;

    var paths = _prefs!.getStringList("indexingPaths") ?? [];
    if (indexingPaths == null) {
      indexingPaths = IndexingPathsProp(_prefs!, paths);
    }
    else {
      await indexingPaths!.clearPaths();
      await indexingPaths!.addPaths(paths);
    }

    dataExportPath = SavableProp<String>("dataExportPath", _prefs!, "");
    exportDats = SavableProp<bool>("exportDat", _prefs!, true);
    exportPaks = SavableProp<bool>("exportPak", _prefs!, true);
    convertXmls = SavableProp<bool>("convertXml", _prefs!, true);

    await super.load();
  }
}

class IndexingPathsProp extends NestedNotifier<StringProp> {
  final SharedPreferences _prefs;

  IndexingPathsProp(this._prefs, List<String> paths)
    : super(paths.map((path) => StringProp(path)).toList());

  List<String> _getPaths() => map((e) => e.value).toList();

  Future<void> addPath(String path) async {
    add(StringProp(path));
    await _prefs.setStringList("indexingPaths", _getPaths());
    await idLookup.addIndexingPaths([path]);
  }

  Future<void> addPaths(List<String> paths) async {
    addAll(paths.map((path) => StringProp(path)));
    await _prefs.setStringList("indexingPaths", _getPaths());
    await idLookup.addIndexingPaths(paths);
  }

  Future<void> removePath(StringProp path) async {
    remove(path);
    await _prefs.setStringList("indexingPaths", _getPaths());
    await idLookup.removeIndexingPaths([path.value]);
  }

  Future<void> clearPaths() async {
    clear();
    await _prefs.setStringList("indexingPaths", _getPaths());
    await idLookup.clearIndexingPaths();
  }

  Future<void> setPath(StringProp prop, String path) async {
    var removeFuture = idLookup.removeIndexingPaths([prop.value]);
    prop.value = path;
    await _prefs.setStringList("indexingPaths", _getPaths());
    await removeFuture;
    await idLookup.addIndexingPaths([path]);
  }

  @override
  Undoable takeSnapshot() {
    return IndexingPathsProp(_prefs, _getPaths());
  }

  @override
  void restoreWith(Undoable snapshot) async {
    var paths = snapshot as IndexingPathsProp;
    await clearPaths();
    await addPaths(paths._getPaths());
  }
}
