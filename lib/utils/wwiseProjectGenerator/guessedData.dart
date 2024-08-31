
import 'wwiseProjectGenerator.dart';

class GuessedData {
  final WwiseProjectGenerator _project;
  String? _confident;
  final Set<String> _guessed = {};

  GuessedData(this._project);

  bool get hasData => _confident != null || _guessed.isNotEmpty;

  String? get value => _confident ?? _guessed.firstOrNull;

  bool get isConfident => _confident != null;

  void _setConfident(String value) {
    if (_confident != null && _confident != value)
      _project.log(WwiseLogSeverity.warning, "Value should be $_confident, but now is conflicting with $value");
    _confident = value;
    _guessed.remove(value);
  }

  void addGuess(String value, bool isConfident) {
    if (isConfident) {
      _setConfident(value);
      return;
    }
    _guessed.add(value);
  }
}

class GuessedObjectData {
  final GuessedData name;
  final GuessedData parentPath;

  GuessedObjectData(WwiseProjectGenerator project) :
    name = GuessedData(project),
    parentPath = GuessedData(project);
  
}
