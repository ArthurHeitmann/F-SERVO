
import 'package:flutter/material.dart';

abstract class TextEditorWebRenderer {
  Future<bool> loadPath(String path);
  Future<void> postMessage(Map<String, dynamic> data);
  Future<void> setEditorContent(String content);
  void onFocus();
  void onBlur();
  Widget build(BuildContext context);
  void dispose();
}
