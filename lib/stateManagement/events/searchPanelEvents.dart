
import 'dart:async';

final searchPathChangeStream = StreamController<String>.broadcast();
final onSearchPathChange = searchPathChangeStream.stream;
