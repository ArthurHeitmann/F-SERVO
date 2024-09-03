import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crclib/catalog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../fileTypeUtils/dat/datExtractor.dart';
import '../fileTypeUtils/dat/datRepacker.dart';
import '../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../fileTypeUtils/yax/japToEng.dart';
import '../main.dart';
import '../stateManagement/Property.dart';
import '../stateManagement/events/statusInfo.dart';
import '../stateManagement/miscValues.dart';
import '../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../stateManagement/preferencesData.dart';
import '../widgets/misc/confirmCancelDialog.dart';
import '../widgets/misc/contextMenuBuilder.dart';
import '../widgets/theme/customTheme.dart';
import 'assetDirFinder.dart';

const uuidGen = Uuid();

enum HorizontalDirection { left, right }

T clamp<T extends num> (T value, T minVal, T maxVal) {
  return max(min(value, maxVal), minVal);
}

const double titleBarHeight = 25;

String tryToTranslate(String jap) {
  if (!shouldAutoTranslate.value)
    return jap;
  var eng = japToEng[jap];
  return eng ?? jap;
}

final _crc32 = Crc32();
int crc32(String str) {
  return _crc32.convert(utf8.encode(str)).toBigInt().toInt();
}

bool isInt(String str) {
  return int.tryParse(str) != null;
}

bool isHexInt(String str) {
  return str.startsWith("0x") && int.tryParse(str) != null;
}

bool isDouble(String str) {
  return double.tryParse(str) != null;
}

bool isVector(String str) {
 return str.split(" ").every((val) => isDouble(val));
}

void Function() throttle(void Function() func, int waitMs, { bool leading = true, bool trailing = false }) {
  Timer? timeout;
  int previous = 0;
  void later() {
		previous = leading == false ? 0 : DateTime.now().millisecondsSinceEpoch;
		timeout = null;
		func();
	}
	return () {
		var now = DateTime.now().millisecondsSinceEpoch;
		if (previous != 0 && leading == false)
      previous = now;
		var remaining = waitMs - (now - previous);
		if (remaining <= 0 || remaining > waitMs) {
			if (timeout != null) {
				timeout!.cancel();
				timeout = null;
			}
			previous = now;
			func();
		}
    else if (timeout != null && trailing) {
			timeout = Timer(Duration(milliseconds: remaining), later);
		}
	};
}

void Function() debounce(void Function() func, int waitMs, { bool leading = false }) {
  Timer? timeout;
  return () {
		timeout?.cancel();
		timeout = Timer(Duration(milliseconds: waitMs), () {
			timeout = null;
			if (!leading)
        func();
		});
		if (leading && timeout != null)
      func();
	};
}

String doubleToStr(num d) {
  var int = d.toInt();
    return int == d
      ? int.toString()
      : d.toString();
}

Future<void> scrollIntoView(BuildContext context, {
  double viewOffset = 0,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeInOut,
  ScrollPositionAlignmentPolicy alignment = ScrollPositionAlignmentPolicy.keepVisibleAtStart,
}) async {
  assert(alignment != ScrollPositionAlignmentPolicy.explicit, "ScrollPositionAlignmentPolicy.explicit is not supported");
  final ScrollableState scrollState = Scrollable.of(context);
  final RenderObject? renderObject = context.findRenderObject();
  if (renderObject == null)
    return;
  final RenderAbstractViewport viewport = RenderAbstractViewport.of(renderObject);
  final position = scrollState.position;
  double target;
  if (alignment == ScrollPositionAlignmentPolicy.keepVisibleAtStart) {
    target = clamp(viewport.getOffsetToReveal(renderObject, 0.0).offset - viewOffset, position.minScrollExtent, position.maxScrollExtent);
  }
  else {
    target = clamp(viewport.getOffsetToReveal(renderObject, 1.0).offset + viewOffset, position.minScrollExtent, position.maxScrollExtent);
  }

  if (target == position.pixels)
    return;

  if (duration == Duration.zero)
    position.jumpTo(target);
  else
    await position.animateTo(target, duration: duration, curve: curve);
}

void scrollIntoViewOptionally(BuildContext context, {
  double viewOffset = 0,
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeInOut,
  bool smallStep = true,
}) {
  var scrollState = Scrollable.of(context);
  var scrollViewStart = 0;
  var scrollEnd = scrollViewStart + scrollState.position.viewportDimension;
  var renderObject = context.findRenderObject() as RenderBox;
  var renderObjectStart = renderObject.localToGlobal(Offset.zero, ancestor: scrollState.context.findRenderObject()).dy;
  var renderObjectEnd = renderObjectStart + renderObject.size.height;
  ScrollPositionAlignmentPolicy? alignment;
  if (renderObjectStart < scrollViewStart) {
    if (smallStep)
      alignment = ScrollPositionAlignmentPolicy.keepVisibleAtStart;
    else
      alignment = ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
  } else if (renderObjectEnd > scrollEnd) {
    if (smallStep)
      alignment = ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
    else
      alignment = ScrollPositionAlignmentPolicy.keepVisibleAtStart;
  }
  if (alignment != null)
    scrollIntoView(context, viewOffset: viewOffset, duration: duration, curve: curve, alignment: alignment);
}

bool isShiftPressed() {
  return (
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shift) ||
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.shiftRight)
  );
}

bool isCtrlPressed() {
  return (
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.control) ||
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.controlRight)
  );
}

bool isAltPressed() {
  return (
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.alt) ||
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.altLeft) ||
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.altRight)
  );
}

bool isMetaPressed() {
  return (
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.meta) ||
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
    RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.metaRight)
  );
}

Future<List<String>> getDatFiles(String extractedDir) async {
  var pakInfo = path.join(extractedDir, "dat_info.json");
  if (await File(pakInfo).exists()) {
    var datInfoJson = jsonDecode(await File(pakInfo).readAsString()) as Map;
    return datInfoJson["files"].cast<String>();
  }
  var fileOrderMetadata = path.join(extractedDir, "file_order.metadata");
  if (await File(fileOrderMetadata).exists()) {
    var filesBytes = await ByteDataWrapper.fromFile(fileOrderMetadata);
    var numFiles = filesBytes.readUint32();
    var nameLength = filesBytes.readUint32();
    List<String> datFiles = List
      .generate(numFiles, (i) => filesBytes.readString(nameLength)
        .split("\u0000")[0]);
    return datFiles;
  }

  return await (Directory(extractedDir).list())
    .where((file) => file is File && path.extension(file.path).length <= 3)
    .map((file) => file.path)
    .toList();
}

Future<void> waitForNextFrame() {
  var completer = Completer<void>();
  SchedulerBinding.instance.addPostFrameCallback((_) => completer.complete());
  return completer.future;
}

({String msg, int time})? lastToast;
void showToast(String msg, [Duration duration = const Duration(seconds: 4)]) {
  var now = DateTime.now().millisecondsSinceEpoch;
  if (lastToast?.msg == msg && now - lastToast!.time < duration.inMilliseconds) {
    lastToast = (msg: msg, time: now);
    return;
  }
  print("showToast: $msg");
  messageLog.add(msg);
  FToast toast = FToast();
  var context = getGlobalContext();
  toast.init(context);
  toast.showToast(
    toastDuration: duration,
    child: Container(
      decoration: BoxDecoration(
        color: getTheme(context).contextMenuBgColor,
        borderRadius: const BorderRadius.all(Radius.circular(10))
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        msg,
        style: TextStyle(
          fontSize: 17,
          color: getTheme(context).textColor!,
        ),
      ),
    )
  );
}

Future<void> copyToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}

Future<String?> getClipboardText() async {
  return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
}

Future<void> copyPuidRef(String code, int id) {
  var hash = crc32(code);
  return copyToClipboard(
    "<puid>\n"
      "<code str=\"$code\">0x${hash.toRadixString(16)}</code>\n"
      "<id>0x${id.toRadixString(16)}</id>\n"
    "</puid>"
  );
}

class PuidRefData {
  final String code;
  final int codeHash;
  final int id;
 
  const PuidRefData(this.code, this.codeHash, this.id);
}

Future<PuidRefData?> getClipboardPuidRefData() async {
  var text = await getClipboardText();
  if (text == null)
    return null;
  try {
    var root = XmlDocument.parse(text).rootElement;
    if (root.name.local != "puid")
      return null;
    var hash = int.parse(root.findElements("code").single.text);
    var code = root.getElement("code")?.getAttribute("str") ?? hashToStringMap[hash] ?? "";
    var id = int.parse(root.findElements("id").single.text);
    return PuidRefData(code, hash, id);
  } catch (e) {
    return null;
  }
}

XmlElement makeXmlElement({ required String name, String? text, Map<String, String> attributes = const {}, List<XmlElement> children = const [] }) {
  return XmlElement(
    XmlName(name),
    attributes.entries.map((attr) => XmlAttribute(XmlName(attr.key), attr.value)).toList(),
    <XmlNode>[
      if (text != null)
        XmlText(text),
      ...children,
    ],
  );
}

final _randomGen = Random();
int randomId() {
  return _randomGen.nextInt(0xFFFFFFFF);
}

ContextMenuConfig optionalValPropButtonConfig(XmlProp parent, String tagName, int Function() getInsertPos, FutureOr<Prop> Function() makePropVal) {
  if (parent.get(tagName) == null)
    return ContextMenuConfig(
      label: "Add $tagName prop",
      icon: const Icon(Icons.add, size: 14),
      action: () async {
        var prop = await makePropVal();
        parent.insert(
          getInsertPos(),
          XmlProp(file: parent.file, tagId: crc32(tagName), tagName: tagName, value: prop, parentTags: parent.nextParents()),
        );
      },
    );
  else
    return ContextMenuConfig(
      label: "Remove $tagName prop",
      icon: const Icon(Icons.remove, size: 14),
      action: () => parent.remove(
        parent.get(tagName)!
          ..dispose()
      )
    );
}

ContextMenuConfig optionalPropButtonConfig(XmlProp parent, String tagName, int Function() getInsertPos, FutureOr<List<XmlProp>> Function() makePropChildren) {
  if (parent.get(tagName) == null)
    return ContextMenuConfig(
      label: "Add $tagName prop",
      icon: const Icon(Icons.add, size: 14),
      action: () async {
        var props = await makePropChildren();
        parent.insert(
          getInsertPos(),
          XmlProp(file: parent.file, tagId: crc32(tagName), tagName: tagName, children: props, parentTags: parent.nextParents()),
        );
      },
    );
  else
    return ContextMenuConfig(
      label: "Remove $tagName prop",
      icon: const Icon(Icons.remove, size: 14),
      action: () => parent.remove(
        parent.get(tagName)!
          ..dispose()
      )
    );
}

int getNextInsertIndexAfter(XmlProp parent, List<String> insertAfterPriorities, [int fallback = 0]) {
  for (var prevTag in insertAfterPriorities) {
    var prev = parent.get(prevTag);
    if (prev != null)
      return parent.indexOf(prev) + 1;
  }
  return fallback;
}

int getNextInsertIndexBefore(XmlProp parent, List<String> insertBeforeProp, [int fallback = 0]) {
  for (var nextTag in insertBeforeProp) {
    var next = parent.get(nextTag);
    if (next != null)
      return parent.indexOf(next);
  }
  return fallback;
}

Key makeReferenceKey(Key key) {
  if (key is GlobalKey || key is UniqueKey)
    return ValueKey(key);
  return key;
}

Future<List<dynamic>> getPakInfoData(String dir) async {
  var pakInfoPath = join(dir, "pakInfo.json");
  if (!await File(pakInfoPath).exists())
    return [];
  Map pakInfoJson = jsonDecode(await File(pakInfoPath).readAsString());
  return pakInfoJson["files"];
}

Future<dynamic> getPakInfoFileData(String path) async {
  var pakInfoPath = join(dirname(path), "pakInfo.json");
  if (!await File(pakInfoPath).exists())
    return null;
  Map pakInfoJson = jsonDecode(await File(pakInfoPath).readAsString());
  var yaxName = "${basenameWithoutExtension(path)}.yax";
  var fileInfoIndex = (pakInfoJson["files"] as List)
    .indexWhere((file) => file["name"] == yaxName);
  if (fileInfoIndex == -1)
    return null;
  return pakInfoJson["files"][fileInfoIndex];
}

Future<void> updatePakInfoFileData(String path, void Function(dynamic data) updater) async {
  var pakInfoPath = join(dirname(path), "pakInfo.json");
  if (!await File(pakInfoPath).exists())
    return;
  Map pakInfoJson = jsonDecode(await File(pakInfoPath).readAsString());
  var yaxName = "${basenameWithoutExtension(path)}.yax";
  var fileInfoIndex = (pakInfoJson["files"] as List)
    .indexWhere((file) => file["name"] == yaxName);
  if (fileInfoIndex == -1)
    return;
  updater(pakInfoJson["files"][fileInfoIndex]);
  await File(pakInfoPath).writeAsString(const JsonEncoder.withIndent("\t").convert(pakInfoJson));
}

Future<void> addPakInfoFileData(String path, int type) async {
  var pakInfoPath = join(dirname(path), "pakInfo.json");
  if (!await File(pakInfoPath).exists())
    return;
  Map pakInfoJson = jsonDecode(await File(pakInfoPath).readAsString());
  var yaxName = "${basenameWithoutExtension(path)}.yax";
  (pakInfoJson["files"] as List).add({
    "name": yaxName,
    "type": type,
  });
  await File(pakInfoPath).writeAsString(const JsonEncoder.withIndent("\t").convert(pakInfoJson));
}

Future<void> removePakInfoFileData(String path) async {
  var pakInfoPath = join(dirname(path), "pakInfo.json");
  if (!await File(pakInfoPath).exists())
    return;
  Map pakInfoJson = jsonDecode(await File(pakInfoPath).readAsString());
  var yaxName = "${basenameWithoutExtension(path)}.yax";
  var fileInfoIndex = (pakInfoJson["files"] as List)
    .indexWhere((file) => file["name"] == yaxName);
  if (fileInfoIndex == -1)
    return;
  (pakInfoJson["files"] as List).removeAt(fileInfoIndex);
  await File(pakInfoPath).writeAsString(const JsonEncoder.withIndent("\t").convert(pakInfoJson));
}

bool isStringAscii(String s) {
  return utf8.encode(s).every((byte) => byte < 128);
}


const _basicFolders = { "ba", "bg", "bh", "em", "et", "it", "pl", "ui", "um", "wp" };
const Map<String, String> _nameStartToFolder = {
  "q": "quest",
  "core": "core",
  "credit": "credit",
  "ev": "event",
  "Debug": "debug",
  "font": "font",
  "misctex": "misctex",
  "subtitle": "subtitle",
  "txt": "txtmess",
};
const _topLevelFileNames = {
  "autoshadereff.dat",
  "autoshadereffInfo.bxm",
  "shader.dat",
  "shader2.dat",
  "shadereff.dat",
  "shadereffcs.dat",
};
String getDatFolder(String datName) {
  if (_topLevelFileNames.contains(datName))
    return "";
  if (datName.endsWith(".eff"))
    return "effect";
  var c2 = datName.substring(0, 2);
  if (_basicFolders.contains(c2))
    return c2;
  var c1 = datName[0];
  if (c1 == "r")
    return "st${datName[1]}";
  if (c1 == "p")
    return "ph${datName[1]}";
  if (c1 == "g")
    return "wd${datName[1]}";
  
  for (var start in _nameStartToFolder.keys) {
    if (datName.startsWith(start))
      return _nameStartToFolder[start]!;
  }

  if (isInt(c2))
    return path.join("effect", "model");
  
  return path.withoutExtension(datName);
}

Future<List<String>> getDatFileList(String datDir) async {
  var datInfoPath = path.join(datDir, "dat_info.json");
  if (await File(datInfoPath).exists())
    return _getDatFileListFromJson(datInfoPath);
  var metadataPath = path.join(datDir, "file_order.metadata");
  if (await File(metadataPath).exists())
    return _getDatFileListFromMetadata(metadataPath);
  
  throw Exception("No dat_info.json or file_order.metadata found in $datDir");
}

Future<List<String>> _getDatFileListFromJson(String datInfoPath) async {
  var datInfoJson = jsonDecode(await File(datInfoPath).readAsString());
  List<String> files = [];
  var dir = path.dirname(datInfoPath);
  for (var file in datInfoJson["files"]) {
    files.add(path.join(dir, file));
  }
  files = files.toSet().toList();
  files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return files;
}

Future<List<String>> _getDatFileListFromMetadata(String metadataPath) async {
  var metadataBytes = await ByteDataWrapper.fromFile(metadataPath);
  var numFiles = metadataBytes.readUint32();
  var nameLength = metadataBytes.readUint32();
  List<String> files = [];
  for (var i = 0; i < numFiles; i++)
    files.add(metadataBytes.readString(nameLength).trimNull());
  files = files.toSet().toList();
  files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  var dir = path.dirname(metadataPath);
  files = files.map((file) => path.join(dir, file)).toList();

  return files;
}

Future<void> exportDat(String datFolder, { bool checkForNesting = false, bool overwriteOriginal = false }) async {
  var exportDir = PreferencesData().dataExportPath?.value ?? "";
  if (exportDir.isNotEmpty && !await Directory(exportDir).exists()) {
    messageLog.add("Export path does not exist: $exportDir");
    exportDir = "";
  }
  var datName = basename(datFolder);
  String datExportDir = "";
  bool recursive = false;
  // check if this DAT is inside another DAT
  if (overwriteOriginal) {
    datExportDir = dirname(dirname(datFolder));
  }
  if (checkForNesting && datExportDir.isEmpty) {
    var parentDirs = [dirname(datFolder), dirname(dirname(datFolder))];
    for (var parentDir in parentDirs) {
      if (!await Directory(parentDir).exists())
        break;
      var dirName = basename(parentDir);
      if (!dirName.contains("."))
        continue;
      var ext = extension(dirName);
      if (!datExtensions.contains(ext))
        continue;
      var exportToParent = await confirmOrCancelDialog(
        getGlobalContext(),
        title: "Export $datName to parent DAT folder?",
        body: "Parent is ...\\$dirName\\",
        yesText: "To $dirName",
        noText: exportDir.isEmpty ? "Select export path" : "To export path",
      );
      if (exportToParent == null)
        return;
      if (!exportToParent)
        break;
      datExportDir = parentDir;
      recursive = true;
    }
  }
  if (datExportDir.isEmpty) {
    // select export path
    if (exportDir.isEmpty) {
      var dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "Select DAT export folder",
      );
      if (dir == null)
        return;
      datExportDir = dir;
    }
    // export to export path from preferences
    else {
      var datSubDir = getDatFolder(datName);
      datExportDir = join(exportDir, datSubDir);
    }
  }
  var datExportPath = join(datExportDir, datName);
  try {
    await repackDat(datFolder, datExportPath);
  } catch (e) {
    messageLog.add("Failed to export $datName: $e");
    rethrow;
  }

  if (recursive)
    await exportDat(datExportDir, checkForNesting: true);
}

String pluralStr(int number, String label, [String numberSuffix = ""]) {
  if (number == 1)
    return "$number$numberSuffix $label";
  return "$number$numberSuffix ${label}s";
}

/// https://stackoverflow.com/a/60717480/9819447
extension Iterables<E> on Iterable<E> {
  Map<K, List<E>> groupBy<K>(K Function(E) keyFunction) => fold(
      <K, List<E>>{},
      (Map<K, List<E>> map, E element) =>
          map..putIfAbsent(keyFunction(element), () => <E>[]).add(element));
}

bool between(num val, num min, num max) => val >= min && val <= max;

void revealFileInExplorer(String path) {
  if (Platform.isWindows) {
    Process.run("explorer.exe", ["/select,", path]);
  } else if (Platform.isMacOS) {
    Process.run("open", ["-R", path]);
  } else if (Platform.isLinux) {
    Process.run("xdg-open", [path]);
  }
}

const datExtensions = { ".dat", ".dtt", ".evn", ".eff", ".eft" };
const bxmExtensions = { ".bxm", ".gad", ".sar", ".seq" };

bool strEndsWithDat(String str) {
  for (var ext in datExtensions) {
    if (str.endsWith(ext))
      return true;
  }
  return false;
}

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
bool get isMobile => Platform.isAndroid || Platform.isIOS;

class SizeInt {
  final int width;
  final int height;

  const SizeInt(this.width, this.height);

  @override
  String toString() => "$width x $height";
}
Future<SizeInt> getDdsFileSize(String path) async {
  var reader = await ByteDataWrapper.fromFile(path);
  reader.position = 0xc;
  var height = reader.readUint32();
  var width = reader.readUint32();
  return SizeInt(width, height);
}

num sum(Iterable<num> values) {
  num sum = 0;
  for (var value in values)
    sum += value;
  return sum;
}

num sumM<T>(Iterable<T> values, num Function(T) mapper) {
  return sum(values.map(mapper));
}

num avr(Iterable<num> values) {
  return sum(values) / values.length;
}

num avrM<T>(Iterable<T> values, num Function(T) mapper) {
  return avr(values.map(mapper));
}

bool isSubtype<S, T>() => <S>[] is List<T>;

bool isAreaProp(XmlProp prop) {
  return prop.tagName.toLowerCase().contains("area") && prop.get("size") != null;
}

List<T> spaceListWith<T>(List<T> list, T Function() generator, [bool outer = false]) {
  var newList = <T>[];
  for (var i = 0; i < list.length; i++) {
    if (i != 0 || outer)
      newList.add(generator());
    newList.add(list[i]);
  }
  if (outer)
    newList.add(generator());
  return newList;
}

Future<void> backupFile(String file) async {
  var backupName = "$file.backup";
  if (!await File(backupName).exists() && await File(file).exists())
    await File(file).copy(backupName);
}

String formatDuration(Duration duration, [bool showMs = false]) {
  var mins = duration.inMinutes.toString().padLeft(2, "0");
  var secs = (duration.inSeconds % 60).toString().padLeft(2, "0");
  if (showMs) {
    var ms = ((duration.inMilliseconds) % 1000).toInt().toString().padLeft(3, "0");
    return "$mins:$secs.$ms";
  }
  return "$mins:$secs";
}

extension StringNullTrim on String {
  String trimNull() => replaceAll(RegExp("\x00+\$"), "");
}

void openInVsCode(String path) {
  showToast("Opening in VS Code...");
  if (Platform.isWindows) {
    Process.run("code", [path], runInShell: true);
  } else if (Platform.isMacOS) {
    Process.run("open", ["-a", "Visual Studio Code", path], runInShell: true);
  } else if (Platform.isLinux) {
    Process.run("code", [path], runInShell: true);
  } else {
    throw Exception("Unsupported platform");
  }
}

void openInTextEditor(String path) async {
  if (await hasVsCode())
    openInVsCode(path);
  else if (Platform.isWindows) {
    await Process.run("notepad", [path], runInShell: true);
  } else if (Platform.isMacOS) {
    await Process.run("open", [path], runInShell: true);
  } else if (Platform.isLinux) {
    await Process.run("gedit", [path], runInShell: true);
  } else {
    showToast("Unsupported platform :(");
    throw Exception("Unsupported platform");
  }
}

Future<String?> findDttDirOfDat(String extractedDatDir) async {
  var datName = basenameWithoutExtension(extractedDatDir);
  var parentDir = dirname(extractedDatDir);
  var dttDir = join(parentDir, "$datName.dtt");
  if (!await Directory(dttDir).exists()) {
    // try finding DTT file and extract it
    var dttPath = join(dirname(parentDir), "$datName.dtt");
    if (!await File(dttPath).exists())
      return null;
    await extractDatFiles(dttPath);
    if (!await Directory(dttDir).exists())
      return null;
  }
  return dttDir;
}

int alignTo(int value, int alignment) {
  return ((value + alignment - 1) ~/ alignment) * alignment;
}

int remainingPadding(int value, int alignment) {
  return alignTo(value, alignment) - value;
}

void timeFunc(String name, void Function() func) {
  var sw = Stopwatch()..start();
  func();
  sw.stop();
  print("$name: ${sw.elapsedMilliseconds}ms");
}

Future<List<T>> futuresWaitBatched<T>(Iterable<Future<T>> futures, int batchSize) async {
  var iterator = futures.iterator;
  List<T> results = [];
  List<Future<T>> batch = [];
  while (iterator.moveNext()) {
    batch.add(iterator.current);
    if (batch.length == batchSize) {
      results.addAll(await Future.wait(batch));
      batch.clear();
    }
  }
  if (batch.isNotEmpty)
    results.addAll(await Future.wait(batch));
  return results;
}

String trimFilePath(String path, int maxLength) {
  if (path.length <= maxLength)
    return path;
  var sep = path.contains("\\") ? "\\" : "/";
  var parts = path.split(sep);
  List<String> usedParts = [];
  int usedLength = parts.last.length;
  usedParts.add(parts.last);
  parts.removeLast();
  while (parts.isNotEmpty && usedLength + parts.last.length + 1 <= maxLength) {
    usedLength += parts.last.length + 1;
    usedParts.insert(0, parts.last);
    parts.removeLast();
  }
  return "...$sep${usedParts.join(sep)}";
}

void debugOnly(void Function() func) {
  assert(() {
    func();
    return true;
  }());
}
