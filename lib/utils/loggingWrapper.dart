
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import 'utils.dart';

final _logFileName = join(Directory.current.path, "log.txt");

void loggingWrapper(void Function() run) {
  // log all output to file
  runZonedGuarded(
    () {
      FlutterError.presentError = (details) {
        _logErrorToFile(details.exceptionAsString());
        FlutterError.dumpErrorToConsole(details);
      };
      run();
    },
    (error, stackTrace) {
      FlutterError.presentError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
      ));
    },
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        _logToFile(line);
        parent.print(zone, line);
      },
    ),
  );
}

List<String> _logBuffer = [];

void _logToFile(String line) {
  var now = DateTime.now();
  var time = "${now.hour}:${now.minute}:${now.second}.${now.millisecond}";
  var logLine = "$time: $line";
  _logBuffer.add(logLine);
  _saveLogBufferThrottled();
}

void _logErrorToFile(String err) {
  var now = DateTime.now();
  var time = "${now.hour}:${now.minute}:${now.second}.${now.millisecond}";
  var logLine = "$time: ERROR: $err";
  _logBuffer.add(logLine);
  _saveLogBufferThrottled();
}

Future<void> _saveLogBuffer() async {
  var logBuffer = _logBuffer;
  _logBuffer = [];
  var file = File(_logFileName);
  var logFile = await file.open(mode: FileMode.append);
  await logFile.writeString("${logBuffer.join("\n")}\n");
  await logFile.close();
}

final _saveLogBufferThrottled = throttle(_saveLogBuffer, 100);
