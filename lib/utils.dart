import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:context_menus/context_menus.dart';
import 'package:crclib/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import 'fileTypeUtils/utils/ByteDataWrapper.dart';
import 'fileTypeUtils/yax/hashToStringMap.dart';
import 'fileTypeUtils/yax/japToEng.dart';
import 'main.dart';
import 'stateManagement/Property.dart';
import 'stateManagement/miscValues.dart';
import 'stateManagement/xmlProps/xmlProp.dart';

final uuidGen = Uuid();

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
  final ScrollableState? scrollState = Scrollable.of(context);
  final RenderObject? renderObject = context.findRenderObject();
  if (scrollState == null)
    return;
  if (renderObject == null)
    return;
  final RenderAbstractViewport? viewport = RenderAbstractViewport.of(renderObject);
  if (viewport == null)
    return;
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

  await position.animateTo(target, duration: duration, curve: curve);
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

Future<List<String>> getDatFiles(String extractedDir) async {
  var pakInfo = path.join(extractedDir, "dat_info.json");
  if (await File(pakInfo).exists()) {
    var datInfoJson = jsonDecode(await File(pakInfo).readAsString());
    return datInfoJson["files"].cast<String>();
  }
  var fileOrderMetadata = path.join(extractedDir, "file_order.metadata");
  if (await File(fileOrderMetadata).exists()) {
    var filesBytes = ByteDataWrapper((await File(fileOrderMetadata).readAsBytes()).buffer);
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

void showToast(String msg) {
  FToast toast = FToast();
  toast.init(getGlobalContext());
  toast.showToast(
    child: Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.all(Radius.circular(10))
      ),
      padding: const EdgeInsets.all(8),
      child: Text(
        msg,
        style: TextStyle(
          fontSize: 17,
          color: Colors.white
        ),
      ),
    )
  );
}

Future<void> copyPuidRef(String code, int id) {
  var hash = crc32(code);
  return Clipboard.setData(ClipboardData(text: 
    "<puid>\n"
      "<code str=\"$code\">0x${hash.toRadixString(16)}</code>\n"
      "<id>0x${id.toRadixString(16)}</id>\n"
    "</puid>"
    ));
}

class PuidRefData {
  final String code;
  final int codeHash;
  final int id;
 
  const PuidRefData(this.code, this.codeHash, this.id);
}

Future<PuidRefData?> getClipboardPuidRefData() async {
  var text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
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

ContextMenuButtonConfig optionalValPropButtonConfig(XmlProp parent, String tagName, int Function() getInsertPos, FutureOr<Prop> Function() makePropVal) {
  if (parent.get(tagName) == null)
    return ContextMenuButtonConfig(
      "Add $tagName prop",
      icon: Icon(Icons.add, size: 14,),
      onPressed: () async {
        var prop = await makePropVal();
        parent.insert(
          getInsertPos(),
          XmlProp(file: parent.file, tagId: crc32(tagName), tagName: tagName, value: prop, parentTags: parent.nextParents()),
        );
      },
    );
  else
    return ContextMenuButtonConfig(
      "Remove $tagName prop",
      icon: Icon(Icons.remove, size: 14,),
      onPressed: () => parent.remove(parent.get(tagName)!)
    );
}

ContextMenuButtonConfig optionalPropButtonConfig(XmlProp parent, String tagName, int Function() getInsertPos, FutureOr<List<XmlProp>> Function() makePropChildren) {
  if (parent.get(tagName) == null)
    return ContextMenuButtonConfig(
      "Add $tagName prop",
      icon: Icon(Icons.add, size: 14,),
      onPressed: () async {
        var props = await makePropChildren();
        parent.insert(
          getInsertPos(),
          XmlProp(file: parent.file, tagId: crc32(tagName), tagName: tagName, children: props, parentTags: parent.nextParents()),
        );
      },
    );
  else
    return ContextMenuButtonConfig(
      "Remove $tagName prop",
      icon: Icon(Icons.remove, size: 14,),
      onPressed: () => parent.remove(parent.get(tagName)!)
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
  await File(pakInfoPath).writeAsString(JsonEncoder.withIndent("\t").convert(pakInfoJson));
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
  await File(pakInfoPath).writeAsString(JsonEncoder.withIndent("\t").convert(pakInfoJson));
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
  await File(pakInfoPath).writeAsString(JsonEncoder.withIndent("\t").convert(pakInfoJson));
}

bool isStringAscii(String s) {
  return utf8.encode(s).every((byte) => byte < 128);
}


const _basicFolders = { "ba", "bg", "bh", "em", "et", "it", "pl", "ui", "um", "wp" };
const Map<String, String> _nameStartToFolder = {
  "q": "quest",
  "core": "core",
  "credit": "credit",
  "Debug": "debug",
  "font": "font",
  "misctex": "misctex",
  "subtitle": "subtitle",
  "txt": "txtmess",
};
String getDatFolder(String datName) {
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
  var metadataBytes = ByteDataWrapper((await File(metadataPath).readAsBytes()).buffer);
  var numFiles = metadataBytes.readUint32();
  var nameLength = metadataBytes.readUint32();
  List<String> files = [];
  for (var i = 0; i < numFiles; i++)
    files.add(metadataBytes.readString(nameLength).replaceAll("\x00", ""));
  files = files.toSet().toList();
  files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  var dir = path.dirname(metadataPath);
  files = files.map((file) => path.join(dir, file)).toList();

  return files;
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

const datExtensions = { ".dat", ".dtt", ".evn", ".eff" };

bool strEndsWithDat(String str) {
  for (var ext in datExtensions) {
    if (str.endsWith(ext))
      return true;
  }
  return false;
}

