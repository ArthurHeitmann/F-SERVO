
import 'package:flutter/material.dart';

import '../../background/IdsIndexer.dart';
import '../../background/searchService.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/Property.dart';
import '../../stateManagement/nestedNotifier.dart';
import '../../stateManagement/openFilesManager.dart';
import '../misc/RowSeparated.dart';
import '../propEditors/simpleProps/boolPropIcon.dart';
import '../propEditors/simpleProps/propEditorFactory.dart';
import '../propEditors/simpleProps/propTextField.dart';
import '../theme/customTheme.dart';

enum _SearchType { text, id }

class SearchPanel extends StatefulWidget {
  const SearchPanel({super.key});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  _SearchType searchType = _SearchType.text;
  SearchService? searchService;
  Stream<SearchResult>? searchStream;
  ValueNestedNotifier<SearchResult> searchResults = ValueNestedNotifier([]);
  BoolProp isSearching = BoolProp(false);
  // common options
  StringProp extensions = StringProp("");
  StringProp path = StringProp("");
  // text search options
  StringProp query = StringProp("");
  BoolProp isRegex = BoolProp(false);
  BoolProp isCaseSensitive = BoolProp(false);
  // id search options
  HexProp id = HexProp(0);
  BoolProp useIndexedData = BoolProp(true);

  @override
  void initState() {
    extensions.addListener(updateSearchStream);
    path.addListener(updateSearchStream);
    query.addListener(updateSearchStream);
    isRegex.addListener(updateSearchStream);
    isCaseSensitive.addListener(updateSearchStream);
    id.addListener(updateSearchStream);
    useIndexedData.addListener(updateSearchStream);
    super.initState();
  }

  @override
  void dispose() {
    extensions.dispose();
    path.dispose();
    query.dispose();
    isRegex.dispose();
    isCaseSensitive.dispose();
    id.dispose();
    useIndexedData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _makeSearchTypeRow(),
        _makeIsSearchingIndicator(),
        SizedBox(height: 4),
        if (searchType == _SearchType.text)
          _makeTextSearchOptions(),
        if (searchType == _SearchType.id)
          _makeIdSearchOptions(),
        _makeSearchResults(),
      ],
    );
  }

  void resetSearch() {
    searchService?.cancel();
    searchService = null;
    searchStream = null;
    searchResults.clear();
    print("#########");
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
    return true;
  }

  void updateSearchStream() {
    resetSearch();
    if (!areAllFieldsFilled())
      return;

    SearchOptions options;
    List<String> fileExtensions;
    if (searchType == _SearchType.id)
      fileExtensions = [".xml"];
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
      );
    } else if (searchType == _SearchType.id) {
      options = SearchOptionsId(
        path.value,
        fileExtensions,
        id.value,
        useIndexedData.value,
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
          child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent,),
        );
      },
    );
  }

  Widget _makeSearchTypeRow() {
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _makeSearchTypeButton(_SearchType.text, "Text Search"),
          _makeSearchTypeButton(_SearchType.id, "ID Lookup"),
        ],
      ),
    );
  }

  Widget _makeSearchTypeButton(_SearchType type, String text) {
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
          textScaleFactor: 1.25,
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
              child: makePropEditor(query, PropTFOptions(hintText: "Search", useIntrinsicWidth: false, isMultiline: true))
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
            SizedBox()
          ],
        ),
        makePropEditor(path, PropTFOptions(hintText: "Path", useIntrinsicWidth: false)),
        makePropEditor(extensions, PropTFOptions(hintText: "Extensions (.xml, .rb, ...)", useIntrinsicWidth: false)),
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
                  child: makePropEditor(id, PropTFOptions(hintText: "ID", useIntrinsicWidth: false))
                ),
                BoolPropIconButton(
                  prop: useIndexedData,
                  icon: Icons.list,
                  tooltip: "Use indexed data"
                ),
                SizedBox()
              ],
            ),
            if (!useIndexedData.value) ...[
              makePropEditor(path, PropTFOptions(hintText: "Path", useIntrinsicWidth: false)),
            ]
          ].map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            child: e,
          )).toList(),
        );
      }
    );
  }

  Widget _makeSearchResults() {
    return Expanded(
      child: ChangeNotifierBuilder(
        notifier: searchResults,
        builder: (context) {
          if (!areAllFieldsFilled())
            return Center(child: Text("Fill all fields to start search"));
          if (searchResults.isEmpty) {
            if (isSearching.value)
              return Center(child: Text("Searching..."));
            else
              return Center(child: Text("No results"));
          }
          return ListView.builder(
          itemCount: searchResults.length,
          itemBuilder: (context, index) => _makeSearchResult(searchResults[index]),
        );
        },
      )
    );
  }

  Widget _makeSearchResult(SearchResult result) {
    Widget resultWidget;
    if (result is SearchResultText)
      resultWidget = _makeSearchResultText(result);
    else if (result is SearchResultId)
      resultWidget = _makeSearchResultId(result);
    else
      throw "Unknown search result type";
    return InkWell(
      onTap: () => areasManager.openFile(result.filePath),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: resultWidget,
      ),
    );
  }

  Widget _makeSearchResultText(SearchResultText result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.line,
          style: TextStyle(
            fontSize: 14,
          ),
          maxLines: 1,
        ),
        Tooltip(
          message: result.filePath,
          waitDuration: const Duration(milliseconds: 750),
          child: Text(
            result.filePath,
            style: TextStyle(
              fontSize: 12,
              color: getTheme(context).textColor!.withOpacity(0.5),
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _makeSearchResultId(SearchResultId result) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
          ),
          maxLines: 1,
        ),
        Tooltip(
          message: result.filePath,
          waitDuration: const Duration(milliseconds: 750),
          child: Text(
            result.filePath,
            style: TextStyle(
              fontSize: 12,
              color: getTheme(context).textColor!.withOpacity(0.5),
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
  
  bool get wantKeepAlive => true;
}
