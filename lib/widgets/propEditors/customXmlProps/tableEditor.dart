
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/transparentPropTextField.dart';

class CellConfig {
  final Prop prop;

  CellConfig({ required this.prop });
}

class RowConfig {
  final Key key;
  final List<CellConfig?> cells;

  RowConfig({ required this.key, required this.cells });
}

mixin CustomTableConfig {
  late final String name;
  late final List<String> columnNames;
  late final NumberProp rowCount;

  RowConfig rowPropsGenerator(int index);
  void onRowAdd();
  void onRowRemove(int index);
}

class TableEditor extends ChangeNotifierWidget {
  final CustomTableConfig config;

  TableEditor({ super.key, required this.config }) : super(notifier: config.rowCount);

  @override
  State<TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends ChangeNotifierState<TableEditor> {
  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                widget.config.name,
                style: Theme.of(context).textTheme.headline6,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _makeHeader(),
          _makeTableBody(),
        ],
      ),
    );
  }

  Widget _makeHeader() {
    return Container(
      decoration: BoxDecoration(
        color: getTheme(context).tableBgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (int i = 0; i < widget.config.columnNames.length; i++)
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: getTheme(context).tableBgColor,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: i == widget.config.columnNames.length - 1 ? 0 : 1,
                    ),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      widget.config.columnNames[i],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            ListView.builder(
              controller: scrollController,
              itemCount: widget.config.rowCount.value as int,
              itemBuilder: (context, i) => _TableRow(index: i, config: widget.config),
            ),
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
        child: Material(
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            onPressed: () {
              widget.config.onRowAdd();
              setState(() {});
              WidgetsBinding.instance.addPostFrameCallback((_) {
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              });
            },
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final int index;
  final CustomTableConfig config;

  const _TableRow({ required this.index, required this.config });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    var rowColor = widget.index % 2 == 1 ? Colors.transparent : getTheme(context).tableBgAltColor;
    if (isHovered) 
      rowColor = getTheme(context).textColor!.withOpacity(0.2);
    
    return NestedContextMenu(
      key: widget.config.rowPropsGenerator(widget.index).key,
      clearParent: true,
      buttons: [
        ContextMenuButtonConfig(
          "Remove Row",
          icon: Icon(Icons.remove, size: 15,),
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
                makeCell(cell: widget.config.rowPropsGenerator(widget.index).cells[j], drawBorder: j != widget.config.columnNames.length - 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget makeCell({ required CellConfig? cell, required bool drawBorder }) {
    return Expanded(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 40),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
                width: drawBorder ? 1 : 0,
              ),
            ),
          ),
          child: cell != null ? makePropEditor<TransparentPropTextField>(
            cell.prop,
            BoxConstraints(minWidth: double.infinity, minHeight: 30),
          ) : null,
        ),
      ),
    );
  }
}
