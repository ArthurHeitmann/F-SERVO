
import 'dart:async';
import 'dart:math';

import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';
import 'package:path/path.dart';

import '../../background/IdsIndexer.dart';
import '../../background/searchService.dart';
import '../../stateManagement/Property.dart';
import '../../stateManagement/events/jumpToEvents.dart';
import '../../stateManagement/events/searchPanelEvents.dart';
import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../../stateManagement/listNotifier.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/utils.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/RowSeparated.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../misc/nestedContextMenu.dart';
import '../propEditors/boolPropCheckbox.dart';
import '../propEditors/boolPropIcon.dart';
import '../propEditors/propEditorFactory.dart';
import '../propEditors/propTextField.dart';
import '../theme/customTheme.dart';

enum _SearchType { text, id, est }

class _SearchResultsFileGroup {
  final String filePath;
  final List<SearchResult> results;

  _SearchResultsFileGroup(this.filePath, this.results);
}

class SearchPanel extends StatefulWidget {
  const SearchPanel({super.key});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  _SearchType searchType = _SearchType.text;
  SearchService? searchService;
  Stream<SearchResult>? searchStream;
  StreamSubscription<String>? onSearchPathChangeSubscription;
  final ValueListNotifier<SearchResult> searchResults = ValueListNotifier([], fileId: null);
  final isSearching = ValueNotifier(false);
  final Mutex cancelMutex = Mutex();
  final scrollController = ScrollController();
  late final void Function() updateSearchStream;
  Set<String> prevOpenFileUuids = {};
  // common options
  final StringProp extensions = StringProp("", fileId: null);
  final StringProp path = StringProp("", fileId: null);
  // text search options
  final StringProp query = StringProp("", fileId: null);
  final BoolProp isRegex = BoolProp(false, fileId: null);
  final BoolProp isCaseSensitive = BoolProp(false, fileId: null);
  // id search options
  final HexProp id = HexProp(0, fileId: null);
  final BoolProp useIndexedData = BoolProp(true, fileId: null);
  // est search options
  final textureFileId = (BoolProp(false, fileId: null), NumberProp(0, true, fileId: null));
  final textureIndex = (BoolProp(false, fileId: null), NumberProp(0, true, fileId: null));
  final meshId = (BoolProp(false, fileId: null), HexProp(0, fileId: null));
  final importedEstId = (BoolProp(false, fileId: null), NumberProp(0, true, fileId: null));
  List<(BoolProp, Prop)> get estOptions => [textureFileId, textureIndex, meshId, importedEstId];
  List<(String, BoolProp, Prop)> get estOptionsNamed => [
    ("Texture file ID", textureFileId.$1, textureFileId.$2),
    ("Texture index", textureIndex.$1, textureIndex.$2),
    ("Mesh ID", meshId.$1, meshId.$2),
    ("Imported EST ID", importedEstId.$1, importedEstId.$2),
  ];


  @override
  void initState() {
    updateSearchStream = debounce(_updateSearchStream, 750);
    openHierarchyManager.children.addListener(_onHierarchyChange);
    onSearchPathChangeSubscription = onSearchPathChange.listen(_onSearchPathChange);
    prevOpenFileUuids = openHierarchyManager.children.map((e) => e.uuid).toSet();
    extensions.addListener(updateSearchStream);
    path.addListener(updateSearchStream);
    path.addListener(_saveLastPath);
    query.addListener(updateSearchStream);
    isRegex.addListener(updateSearchStream);
    isCaseSensitive.addListener(updateSearchStream);
    id.addListener(updateSearchStream);
    useIndexedData.addListener(updateSearchStream);
    for (var (boolProp, numberProp) in estOptions) {
      boolProp.addListener(updateSearchStream);
      numberProp.addListener(updateSearchStream);
    }
    var prefs = PreferencesData();
    if (prefs.lastSearchDir != null)
      path.value = prefs.lastSearchDir!.value;
    super.initState();
  }

  @override
  void dispose() {
    openHierarchyManager.children.removeListener(_onHierarchyChange);
    onSearchPathChangeSubscription?.cancel();
    extensions.dispose();
    path.dispose();
    query.dispose();
    isRegex.dispose();
    isCaseSensitive.dispose();
    id.dispose();
    useIndexedData.dispose();
    for (var (boolProp, numberProp) in estOptions) {
      boolProp.dispose();
      numberProp.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _makeSearchTypeRow(context),
          _makeIsSearchingIndicator(),
          const SizedBox(height: 4),
          if (searchType == _SearchType.text)
            _makeTextSearchOptions(),
          if (searchType == _SearchType.id)
            _makeIdSearchOptions(),
          if (searchType == _SearchType.est)
            _makeEstSearchOptions(),
          _makeSearchResults(),
        ],
      ),
    );
  }

  Future<void> resetSearch() async {
    if (searchService == null)
      return;
    await searchService?.cancel();
    searchService = null;
    searchStream = null;
    searchResults.clear();
  }

  bool areAllFieldsFilled() {
    if (searchType == _SearchType.text &&
      (query.value.isEmpty || path.value.isEmpty || extensions.value.isEmpty)) {
      return false;
    }
    if (searchType == _SearchType.id &&
      (id.value == 0 || path.value.isEmpty && !useIndexedData.value)
    ) {
      return false;
    }
    if (searchType == _SearchType.est && (
        path.value.isEmpty || estOptions.every((opt) => !opt.$1.value)
    )) {
      return false;
    }
    return true;
  }

  void _saveLastPath() {
    var prefs = PreferencesData();
    if (prefs.lastSearchDir != null)
      prefs.lastSearchDir!.value = path.value;
  }

  void _updateSearchStream() async {
    await cancelMutex.protect<void>(() => resetSearch());

    if (!areAllFieldsFilled())
      return;
    if (searchType == _SearchType.text && isRegex.value) {
      try {
        RegExp(query.value);
      } catch (e) {
        showToast("Invalid regex");
        return;
      }
    }

    SearchOptions options;
    List<String> fileExtensions;
    if (searchType == _SearchType.id)
      fileExtensions = [".xml"];
    if (searchType == _SearchType.est)
      fileExtensions = [".est", ".sst"];
    else if (extensions.value.isNotEmpty)
      fileExtensions = extensions.value.split(",")
        .map((e) => e.trim())
        .toList();
    else
      fileExtensions = [];
    if (searchType == _SearchType.text) {
      options = SearchOptionsText(
        path.value,
        fileExtensions,
        query.value,
        isRegex.value,
        isCaseSensitive.value,
        query.value.contains("\n"),
      );
    } else if (searchType == _SearchType.id) {
      options = SearchOptionsId(
        path.value,
        fileExtensions,
        id.value,
        useIndexedData.value,
      );
    } else if (searchType == _SearchType.est) {
      options = SearchOptionsEst(
        path.value,
        fileExtensions,
        textureFileId.$1.value ? textureFileId.$2.value.toInt() : null,
        textureIndex.$1.value ? textureIndex.$2.value.toInt() : null,
        meshId.$1.value ? meshId.$2.value.toInt() : null,
        importedEstId.$1.value ? importedEstId.$2.value.toInt() : null,
      );
    } else {
      throw "Unknown search type";
    }

    searchService = SearchService(isSearching: isSearching);
    searchStream = searchService!.search(options);
    searchResults.clear();
    searchStream!.listen((result) {
      searchResults.add(result);
    });

    setState(() {});
  }

  Widget _makeIsSearchingIndicator() {
    return ChangeNotifierBuilder(
      notifier: isSearching,
      builder: (context) {
        return Opacity(
          opacity: isSearching.value ? 1 : 0,
          child: const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent,),
        );
      },
    );
  }

  Widget _makeSearchTypeRow(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _makeSearchTypeButton(context, _SearchType.text, "Text Search"),
          _makeSearchTypeButton(context, _SearchType.id, "ID Lookup"),
          _makeSearchTypeButton(context, _SearchType.est, "EST Search"),
        ],
      ),
    );
  }

  Widget _makeSearchTypeButton(BuildContext context, _SearchType type, String text) {
    return Expanded(
      child: TextButton(
        onPressed: () {
          if (searchType == type)
            return;
          setState(() => searchType = type);
          updateSearchStream();
        },
        style: ButtonStyle(
          backgroundColor: searchType == type
            ? MaterialStateProperty.all(getTheme(context).textColor!.withOpacity(0.1))
            : MaterialStateProperty.all(Colors.transparent),
          foregroundColor: searchType == type
            ? MaterialStateProperty.all(getTheme(context).textColor)
            : MaterialStateProperty.all(getTheme(context).textColor!.withOpacity(0.5)),
        ),
        child: Text(
          text,
          textScaleFactor: 1.125,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _makeTextSearchOptions() {
    return Column(
      children: [
        RowSeparated(
          crossAxisAlignment: CrossAxisAlignment.center,
          separatorWidth: 5,
          children: [
            Expanded(
              child: makePropEditor(query, const PropTFOptions(hintText: "Search", useIntrinsicWidth: false, isMultiline: true))
            ),
            BoolPropIconButton(
              prop: isCaseSensitive,
              icon: Icons.text_fields,
              tooltip: "Case Sensitive"
            ),
            BoolPropIconButton(
              prop: isRegex,
              icon: Icons.auto_awesome,
              tooltip: "Regex"
            ),
            const SizedBox()
          ],
        ),
        makePropEditor(path, const PropTFOptions(hintText: "Path", useIntrinsicWidth: false)),
        makePropEditor(extensions, const PropTFOptions(hintText: "Extensions (.xml, .rb, ...)", useIntrinsicWidth: false)),
      ].map((e) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        child: e,
      )).toList(),
    );
  }

  Widget _makeIdSearchOptions() {
    return ChangeNotifierBuilder(
      notifier: useIndexedData,
      builder: (context) {
        return Column(
          children: [
            RowSeparated(
              crossAxisAlignment: CrossAxisAlignment.center,
              separatorWidth: 5,
              children: [
                Expanded(
                  child: makePropEditor(id, const PropTFOptions(hintText: "ID", useIntrinsicWidth: false))
                ),
                BoolPropIconButton(
                  prop: useIndexedData,
                  icon: Icons.list,
                  tooltip: "Use indexed data"
                ),
                const SizedBox()
              ],
            ),
            if (!useIndexedData.value) ...[
              makePropEditor(path, const PropTFOptions(hintText: "Path", useIntrinsicWidth: false)),
            ]
          ].map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            child: e,
          )).toList(),
        );
      }
    );
  }

  Widget _makeEstSearchOptions() {
    return Column(
      children: [
        makePropEditor(path, const PropTFOptions(hintText: "Path", useIntrinsicWidth: false)),
        ...estOptionsNamed.map((opt) => RowSeparated(
          crossAxisAlignment: CrossAxisAlignment.center,
          separatorWidth: 5,
          children: [
            Expanded(child: Text(opt.$1)),
            BoolPropCheckbox(
              prop: opt.$2,
            ),
            Flexible(
              child: ChangeNotifierBuilder(
                notifier: opt.$2,
                builder: (context) {
                  return AnimatedOpacity(
                    opacity: opt.$2.value ? 1 : 0.33,
                    duration: const Duration(milliseconds: 100),
                    child: makePropEditor(
                      opt.$3,
                      PropTFOptions(
                        hintText: opt.$1,
                        useIntrinsicWidth: false,
                        constraints: const BoxConstraints(maxWidth: 80)
                      )
                    ),
                  );
                }
              )
            ),
            const SizedBox()
          ],
        )),
      ].map((e) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        child: e,
      )).toList(),
    );
  }

  Widget _makeSearchResults() {
    return Expanded(
      child: ChangeNotifierBuilder(
        notifiers: [searchResults, isSearching],
        builder: (context) {
          String? errorText;
          String? infoText;
          if (!areAllFieldsFilled())
            errorText = "Fill all fields to start search";
          if (searchResults.isEmpty) {
            if (isSearching.value)
              errorText = "Searching...";
            else
              errorText = "No results";
          }
          var results = searchResults.toList();
          var optP = "";
          if (searchResults.length >= 1000) {
            results = results.sublist(0, 1000);
            infoText = "Stopped at 1000 results";
            optP = "+";
          }

          var resultsFilesCount = searchResults.map((e) => e.filePath).toSet().length;
          var infoStyle = TextStyle(
            color: getTheme(context).textColor!.withOpacity(0.5),
            fontSize: 12,
          );
          var fileGroups = results
            .groupBy((e) => e.filePath)
            .entries
            .map((kv) => _SearchResultsFileGroup(kv.key, kv.value,))
            .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                child: Text(
                  errorText ?? "Found ${pluralStr(searchResults.length, "result", optP)} in ${pluralStr(resultsFilesCount, "file", optP)}",
                  style: infoStyle,
                ),
              ),
              if (infoText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Text(infoText, style: infoStyle),
                ),
              const SizedBox(height: 5),
              const Divider(height: 1,),
              if (errorText == null)
                Expanded(
                  child: SmoothSingleChildScrollView(
                    controller: scrollController,
                    duration: const Duration(milliseconds: 100),
                    stepSize: 40,
                    child: Column(
                      children: fileGroups.map((fg) => 
                        _SearchGroupResult(
                          fg,
                          isRegex.value,
                          isCaseSensitive.value,
                          query.value,
                        ),
                      ).toList(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _onHierarchyChange() {
    // auto fill search path with opened file
    if (path.value.isNotEmpty || query.value.isNotEmpty && extensions.value.isNotEmpty)
      return;
    var curOpenFileUuids = openHierarchyManager.children.map((e) => e.uuid).toSet();
    var newlyAddedUuids = curOpenFileUuids.difference(prevOpenFileUuids);
    for (var newUuid in newlyAddedUuids) {
      var entry = openHierarchyManager.children.firstWhere((e) => e.uuid == newUuid);
      if (entry is! ExtractableHierarchyEntry)
        continue;
      path.value = entry.extractedPath;
      break;
    }
    prevOpenFileUuids = curOpenFileUuids;
  }

  void _onSearchPathChange(String newFolder) {
    if (newFolder.isEmpty)
      return;
    path.value = newFolder;
  }
}

class _SearchGroupResult extends StatefulWidget {
  final _SearchResultsFileGroup group;
  final bool isRegex;
  final bool isCaseSensitive;
  final String query;

 _SearchGroupResult(this.group, this.isRegex, this.isCaseSensitive, this.query)
    : super(key: Key(group.filePath));

  @override
  State<_SearchGroupResult> createState() => _SearchGroupResultState();
}

class _SearchGroupResultState extends State<_SearchGroupResult> {
  bool isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return NestedContextMenu(
      buttons: [
        ContextMenuButtonConfig(
          "Open in File Explorer",
          icon: const Icon(Icons.drive_file_move, size: 15,),
          onPressed: () => openHierarchyManager.openFile(widget.group.filePath),
        ),
        ContextMenuButtonConfig(
          "Reveal in Windows Explorer",
          icon: const Icon(Icons.folder_open, size: 15,),
          onPressed: () => revealFileInExplorer(widget.group.filePath),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 25,
            child: InkWell(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Transform.rotate(
                    angle: isExpanded ? 0 : -pi / 2,
                    child: const Icon(Icons.expand_more, size: 18)
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.description, color: getTheme(context).filetypeDocColor, size: 18,),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.group.filePath.length > 40
                        ? ".../${basename(dirname(widget.group.filePath))}/${basename(widget.group.filePath)}"
                        : widget.group.filePath,
                      style: const TextStyle(
                        fontSize: 13,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    widget.group.results.length.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: getTheme(context).textColor!.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          if (isExpanded)
            ...widget.group.results
              .map((result) => _makeSearchResult(context, result))
        ],
      ),
    );
  }

  Widget _makeSearchResult(BuildContext context, SearchResult result) {
    Widget resultWidget;
    if (result is SearchResultText)
      resultWidget = _makeSearchResultText(context, result);
    else if (result is SearchResultId)
      resultWidget = _makeSearchResultId(context, result);
    else if (result is SearchResultEst)
      resultWidget = _makeSearchResultEst(context, result);
    else
      throw "Unknown search result type";
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 25),
      child: InkWell(
        onTap: () async {
          var file = areasManager.openFile(result.filePath);
          if (result is SearchResultText) {
            await file.load();
            jumpToStream.add(JumpToLineEvent(file, result.lineNum));
          }
          else if (result is SearchResultId) {
            await file.load();
            jumpToStream.add(JumpToIdEvent(file, result.idData.id));
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 40.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: resultWidget
          ),
        ),
      ),
    );
  }

  Widget _makeSearchResultText(BuildContext context, SearchResultText result) {
    String text = result.line;
    List<TextSpan> textSpans;
    List<String> fillStrings;
    RegExp regex;
    if (widget.isRegex) {
      try {
        regex = RegExp(widget.query, caseSensitive: widget.isCaseSensitive);
      } catch (e) {
        regex = RegExp(RegExp.escape(widget.query), caseSensitive: widget.isCaseSensitive);
      }
      textSpans = text.split(regex)
        .map((e) => TextSpan(
          text: e.replaceAll("\t", "  "),
          style: const TextStyle(
            fontSize: 13,
          ),
        ))
        .toList();
    }
    else {
      try {
        regex = RegExp(RegExp.escape(widget.query), caseSensitive: widget.isCaseSensitive);
      } catch (e) {
        regex = RegExp(widget.query, caseSensitive: widget.isCaseSensitive);
      }
      textSpans = text.split(regex)
        .map((e) => TextSpan(
          text: e.replaceAll("\t", "  "),
          style: TextStyle(
            color: getTheme(context).textColor,
            fontSize: 13,
          ),
        ))
        .toList();
    }
    fillStrings = regex.allMatches(text)
      .map((e) => e.group(0)!)
      .toList();
    // insert colored spans of query between all text spans
    for (int i = 1; i < textSpans.length; i += 2) {
      textSpans.insert(i, TextSpan(
        text: fillStrings[(i - 1) ~/ 2].replaceAll("\t", "  "),
        style: TextStyle(
          color: getTheme(context).textColor,
          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.35),
        ),
      ));
    }
    return Row(
      children: [
        Text(
          result.lineNum.toString().padLeft(4),
          style: TextStyle(
            fontSize: 11,
            color: getTheme(context).textColor!.withOpacity(0.5),
            fontFamily: "FiraCode",
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: textSpans,
              style: const TextStyle(
                fontFamily: "FiraCode",
              ),
            ),
            textScaleFactor: 0.9,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _makeSearchResultId(BuildContext context, SearchResultId result) {
    var idData = result.idData;
    String title = idData.type;
    if (idData is IndexedActionIdData)
      title = "Action: ${idData.actionName}";
    else if (idData is IndexedEntityIdData) {
      title = "Entity: ${idData.objId}";
      if (idData.name != null)
        title += " (${idData.name})";
      if (idData.level != null)
        title += " [lvl ${idData.level}]";
    }

    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
      ),
      maxLines: 1,
    );
  }

  Widget _makeSearchResultEst(BuildContext context, SearchResultEst result) {
    return Text(
      "In ${pluralStr(result.records.length, "record")}: ${result.records.join(", ")}",
      style: const TextStyle(
        fontSize: 14,
      ),
      maxLines: 1,
    );
  }
  
}
