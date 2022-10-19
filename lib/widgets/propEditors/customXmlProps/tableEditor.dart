
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/Property.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/transparentPropTextField.dart';

class CellConfig {
  final Prop prop;

  CellConfig({ required this.prop });
}

mixin XmlTableConfig {
  late final List<String> columnNames;
  
  int get rowCount;

  List<CellConfig?> rowPropsGenerator(int index);
}

class TableEditor extends StatefulWidget {
  final XmlTableConfig config;

  const TableEditor({ super.key, required this.config });

  @override
  State<TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<TableEditor> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 750,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 750),
        child: Column(
          children: [
            Row(
              children: [
                for (var name in widget.config.columnNames)
                  Expanded(child: Text(name, overflow: TextOverflow.ellipsis,)),
              ],
            ),
            Expanded(
              child: ListView.builder(
                
                // border: TableBorder.all(
                //   color: getTheme(context).textColor!.withOpacity(0.5),
                // ),
                // itemCount: widget.config.rowCount * widget.config.columnNames.length,
                itemCount: widget.config.rowCount,
                itemExtent: 40,
                  
                // gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                //   crossAxisCount: widget.config.columnNames.length,
                //   mainAxisExtent: 50
                //   // childAspectRatio: 3,
                // ),
                itemBuilder: (context, i) =>
                  Row(
                    children: widget.config.rowPropsGenerator(i).map((cell) => 
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: cell != null ? makeCell(cell: cell) : null
                        ),
                      ),
                    ).toList(),
                  ),
                // children: [
                //   for (var i = 0; i < widget.config.rowCount; i++)
                //     TableRow(
                //       children: widget.config.rowPropsGenerator(i).map((cell) => 
                //         SizedBox(
                //           height: 40,
                //           child: cell != null ? makeCell(cell: cell) : null
                //         ),
                //       ).toList(),
                //     )
                // ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget makeCell({ required CellConfig cell }) {
    return makePropEditor<TransparentPropTextField>(
      cell.prop,
      // BoxConstraints(minWidth: double.infinity),
    );
  }
}
