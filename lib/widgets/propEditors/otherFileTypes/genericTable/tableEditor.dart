
import 'dart:async';

import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../misc/SmoothScrollBuilder.dart';
import '../../../theme/customTheme.dart';
import '../../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../../stateManagement/Property.dart';
import '../../../misc/nestedContextMenu.dart';
import '../../simpleProps/UnderlinePropTextField.dart';
import '../../simpleProps/propEditorFactory.dart';
import '../../simpleProps/propTextField.dart';
import '../../simpleProps/textFieldAutocomplete.dart';
import '../../simpleProps/transparentPropTextField.dart';
import 'tableExporter.dart';

abstract class CellConfig {
  Widget makeWidget();
  String toExportString();
}

class PropCellConfig extends CellConfig {
  final Prop prop;
  final bool allowMultiline;
  final FutureOr<Iterable<AutocompleteConfig>> Function()? autocompleteOptions;

  PropCellConfig({ required this.prop, this.allowMultiline = false, this.autocompleteOptions });

  @override
  Widget makeWidget() => makePropEditor<TransparentPropTextField>(
    prop,
    PropTFOptions(
      constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 30),
      isMultiline: allowMultiline,
      useIntrinsicWidth: false,
      autocompleteOptions: autocompleteOptions,
    ),
  );

  @override
  String toExportString() => prop.toString();
}

class TextCellConfig extends CellConfig {
  final String text;

  TextCellConfig(this.text);

  @override
  Widget makeWidget() => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(text),
    )
  );

  @override
  String toExportString() => text;
}

class RowConfig {
  final Key key;
  final List<CellConfig?> cells;

  RowConfig({ required this.key, required this.cells });
}
class _RowConfigIndexed {
  final int index;
  final RowConfig rowConfig;

  const _RowConfigIndexed(this.index, this.rowConfig);
}

mixin CustomTableConfig {
  late final String name;
  late final List<String> columnNames;
  late final List<int> columnFlex;
  late final NumberProp rowCount;
  bool allowRowAddRemove = true;

  RowConfig rowPropsGenerator(int index);
  void onRowAdd();
  void onRowRemove(int index);
  void updateRowWith(int index, List<String?> values);
}

class _ColumnSort {
  int index;
  bool ascending;

  _ColumnSort(this.index, this.ascending);
}

class TableEditor extends ChangeNotifierWidget {
  final CustomTableConfig config;

  TableEditor({ super.key, required this.config }) : super(notifier: config.rowCount);

  @override
  State<TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends ChangeNotifierState<TableEditor> {
  final scrollController = ScrollController();
  List<_RowConfigIndexed> rows = [];
  _ColumnSort? columnSort;
  late final List<StringProp> columnSearch;

  @override
  void initState() {
    columnSearch = List.generate(widget.config.columnNames.length, (index) {
      var prop = StringProp("");
      prop.addListener(() => setState(() {}));
      return prop;
    });
    super.initState();
  }

  @override
  void dispose() {
    for (var prop in columnSearch)
      prop.dispose();
    super.dispose();
  }

  void updateRows() {
    // generate all rows
    rows = List.generate(
      widget.config.rowCount.value as int,
      (index) => _RowConfigIndexed(index, widget.config.rowPropsGenerator(index))
    );
    // filter rows
    if (columnSearch.any((prop) => prop.value.isNotEmpty)) {
      rows = rows.where((row) {
        for (var i = 0; i < columnSearch.length; i++) {
          if (columnSearch[i].value.isEmpty)
            continue;
          var cell = row.rowConfig.cells[i];
          if (cell == null) {
            if (columnSearch[i].value.isNotEmpty)
              return false;
            continue;
          }
          var searchStr = columnSearch[i].value.toLowerCase();
          var cellValue = cell.toExportString().toLowerCase();
          if (!cellValue.contains(searchStr))
            return false;
        }
        return true;
      }).toList();
    }
    // sort rows
    if (columnSort != null) {
      rows.sort((a, b) {
        final aCell = a.rowConfig.cells[columnSort!.index];
        final bCell = b.rowConfig.cells[columnSort!.index];
        if (aCell == null && bCell == null)
          return 0;
        if (aCell == null)
          return columnSort!.ascending ? -1 : 1;
        if (bCell == null)
          return columnSort!.ascending ? 1 : -1;
        if (aCell is PropCellConfig && bCell is PropCellConfig) {
          final aProp = aCell.prop;
          final bProp = bCell.prop;
          if (aProp is NumberProp && bProp is NumberProp)
            return aProp.value.compareTo(bProp.value) * (columnSort!.ascending ? 1 : -1);
        }
        return aCell.toExportString().compareTo(bCell.toExportString()) * (columnSort!.ascending ? 1 : -1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    updateRows();
    return Padding(
      padding: const EdgeInsets.only(top: 32, right: 8, bottom: 8, left: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.config.name,
                    style: Theme.of(context).textTheme.headline6,
                  ),
                ),
              ),
              _makeExportDropdown(),
            ],
          ),
          const SizedBox(height: 8),
          _makeHeader(),
          _makeTableBody(),
        ],
      ),
    );
  }

  Widget _makeExportDropdown() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      splashRadius: 26,
      tooltip: "",
      onSelected: (String? newValue) {
        if (newValue == "E JSON")
          saveTableAsJson(widget.config);
        else if (newValue == "E CSV")
          saveTableAsCsv(widget.config);
        else if (newValue == "I JSON")
          loadTableFromJson(widget.config);
        else if (newValue == "I CSV")
          loadTableFromCsv(widget.config);
        else
          throw Exception("Unknown export type: $newValue");
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: "E JSON",
          child: ListTile(
            leading: Icon(Icons.data_object),
            title: Text("Export as JSON"),
          ),
        ),
        const PopupMenuItem(
          value: "E CSV",
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text("Export as CSV"),
          ),
        ),
        const PopupMenuItem(
          value: "I JSON",
          child: ListTile(
            leading: Icon(Icons.data_object),
            title: Text("Import from JSON"),
          ),
        ),
        const PopupMenuItem(
          value: "I CSV",
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text("Import from CSV"),
          ),
        ),
      ],
    );
  }

  Widget _makeHeader() {
    return Container(
      decoration: BoxDecoration(
        color: getTheme(context).tableBgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (int i = 0; i < widget.config.columnNames.length; i++)
            Flexible(
              flex: widget.config.columnFlex[i],
              fit: FlexFit.tight,
              child: Container(
                decoration: BoxDecoration(
                  color: getTheme(context).tableBgColor,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: i == widget.config.columnNames.length - 1 ? 0 : 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(left: 8, right: 2, top: 4, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: widget.config.columnNames[i],
                      waitDuration: const Duration(seconds: 1),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            if (columnSort != null && columnSort!.index == i) {
                              if (columnSort!.ascending)
                                columnSort!.ascending = false;
                              else
                                columnSort = null;
                            } else {
                              columnSort = _ColumnSort(i, true);
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.config.columnNames[i],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            columnSort == null || columnSort!.index != i
                              ? Icon(Icons.swap_vert, size: 17, color: Theme.of(context).colorScheme.primary.withOpacity(0.5))
                              : columnSort!.ascending
                                ? const Icon(Icons.arrow_drop_up, size: 20)
                                : const Icon(Icons.arrow_drop_down, size: 20),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, right: 6),
                      child: makePropEditor<UnderlinePropTextField>(
                        columnSearch[i],
                        const PropTFOptions(
                          constraints: BoxConstraints(maxWidth: 200),
                          useIntrinsicWidth: false,
                          hintText: "Search...",
                        )
                      ),
                    ),
                  ],
                ),
              )
            ),
        ],
      ),
    );
  }

  Widget _makeTableBody() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).tableBgColor,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            SmoothScrollBuilder(
              controller: scrollController,
              builder: (context, controller, physics) {
                return ListView.builder(
                  controller: controller,
                  physics: physics,
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _TableRow(i % 2 == 1, rows[i].index, rows[i].rowConfig, widget.config),
                );
              }
            ),
            if (widget.config.allowRowAddRemove)
              _makeAddRowButton()
          ],
        ),
      ),
    );
  }

  Widget _makeAddRowButton() {
    return Positioned(
      right: 8,
      bottom: 8,
      child: SizedBox(
        width: 40,
        height: 40,
        child: FloatingActionButton(
          onPressed: () {
            widget.config.onRowAdd();
            setState(() {});
            if (columnSort != null)
              return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            });
          },
          foregroundColor: getTheme(context).textColor,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final bool alt;
  final int index;
  final RowConfig row;
  final CustomTableConfig config;

  _TableRow(this.alt, this.index, this.row, this.config)
    : super(key: row.key);

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    var rowColor = widget.alt ? Colors.transparent : getTheme(context).tableBgAltColor;
    if (isHovered) 
      rowColor = getTheme(context).textColor!.withOpacity(0.2);
    
    return NestedContextMenu(
      clearParent: true,
      buttons: [
        if (widget.config.allowRowAddRemove)
          ContextMenuButtonConfig(
            "Remove Row",
            icon: const Icon(Icons.remove, size: 15,),
            onPressed: () => widget.config.onRowRemove(widget.index),
          ),
      ],
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: Container(
          color: rowColor,
          child: Row(
            children: [
              for (int j = 0; j < widget.config.columnNames.length; j++)
                makeCell(
                  cell: widget.row.cells[j],
                  drawBorder: j != widget.config.columnNames.length - 1,
                  flex: widget.config.columnFlex[j],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget makeCell({ required CellConfig? cell, required bool drawBorder, required int flex }) {
    return Flexible(
      fit: FlexFit.tight,
      flex: flex,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
                width: drawBorder ? 1 : 0,
              ),
            ),
          ),
          child: cell?.makeWidget(),
        ),
      ),
    );
  }
}
