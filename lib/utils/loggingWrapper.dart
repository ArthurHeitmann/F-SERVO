
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import 'utils.dart';

final logFileName = join(dirname(Platform.resolvedExecutable), "log.txt");

void loggingWrapper(void Function() run) {
  if (isWeb) {
    run();
    return;
  }
  // log all output to file
  runZonedGuarded(
    () {
      FlutterError.presentError = (details) {
        _logErrorToFile(details);
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
  var time = "${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")}.${now.millisecond}";
  var logLine = "$time: $line";
  _logBuffer.add(logLine);
  _saveLogBufferThrottled();
}

void _logErrorToFile(FlutterErrorDetails err) {
  var now = DateTime.now();
  var time = "${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")}.${now.millisecond}";
  var logLine = "$time: ERROR: ${err.exceptionAsString()}"
      "\n"
      "${err.stack.toString()}";
  _logBuffer.add(logLine);
  _saveLogBufferThrottled();
}

Future<void> _saveLogBuffer() async {
  var logBuffer = _logBuffer;
  _logBuffer = [];
  var file = File(logFileName);
  var logFile = await file.open(mode: FileMode.append);
  await logFile.writeString("${logBuffer.join("\n")}\n");
  await logFile.close();
}

final _saveLogBufferThrottled = throttle(_saveLogBuffer, 100);
