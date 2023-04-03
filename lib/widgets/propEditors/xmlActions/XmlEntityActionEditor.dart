
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/sync/syncListImplementations.dart';
import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/syncButton.dart';
import '../../theme/customTheme.dart';
import '../customXmlProps/layoutsEditor.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import 'XmlActionEditor.dart';

class XmlEntityActionEditor extends XmlActionEditor {
  XmlEntityActionEditor({ super.key,  required super.action, required super.showDetails });

  @override
  State<XmlEntityActionEditor> createState() => _XmlEntityActionEditorState();
}

class _XmlEntityActionEditorState extends XmlActionEditorState<XmlEntityActionEditor> {
  @override
  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      SyncButton(
        uuid: widget.action.uuid,
        makeSyncedObject: () => SyncedEntityAction(
          action: widget.action,
          parentUuid: "",
        ),
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }

  @override
  Widget makeInnerActionBody() {
    return EntityActionInnerEditor(
      action: widget.action,
      showDetails: widget.showDetails,
    );
  }
}

class EntityActionInnerEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlActionProp action;

  EntityActionInnerEditor({ super.key, required this.action, required this.showDetails})
    : super(notifier: action);

  @override
  State<EntityActionInnerEditor> createState() => _EntityActionInnerEditorState();
}

class _EntityActionInnerEditorState extends ChangeNotifierState<EntityActionInnerEditor> {
  @override
  Widget build(BuildContext context) {
    var layouts = widget.action.get(_layoutsTag)!;
    var areaProps = widget.action.where((e) => _areaTags.contains(e.tagName)).toList();
    var enemySetProps = widget.action.where((e) => _enemySetTags.contains(e.tagName)).toList();
    var enemySetAreaProps = widget.action.where((e) => _enemySetAreaTags.contains(e.tagName)).toList();
    bool onlyLayouts = areaProps.isEmpty && enemySetProps.isEmpty && enemySetAreaProps.isEmpty;
    
    return Column(
      children: [
        _makeGroupWrapperCustom("Spawn Entities", LayoutsEditor(prop: layouts, showDetails: widget.showDetails)),
        if (!onlyLayouts)
          _makeSeparator(),
        if (areaProps.isNotEmpty) ...[
          _makeGroupWrapperSingle("Spawn Areas", areaProps),
          if (enemySetProps.isNotEmpty || enemySetAreaProps.isNotEmpty)
            _makeSeparator(),
        ],
        if (enemySetProps.isNotEmpty) ...[
          _makeGroupWrapperSingle("Enemy Set Properties", enemySetProps),
          if (enemySetAreaProps.isNotEmpty)
            _makeSeparator(),
        ],
        if (enemySetAreaProps.isNotEmpty)
          _makeGroupWrapperSingle("Enemy Behavior Properties", enemySetAreaProps),
      ],
    );
  }

  Widget _makeGroupWrapperSingle(String title, Iterable<XmlProp> props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(title, style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        for (var prop in props)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: makeXmlPropEditor(prop, widget.showDetails),
          )
      ],
    );
  }
  Widget _makeGroupWrapperCustom(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(title, style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: child,
        ),
      ],
    );
  }
  Widget _makeSeparator() {
    return const Divider(
      height: 20,
      thickness: 1,
      indent: 10,
      endIndent: 10,
    );
  }
}

const _layoutsTag = "layouts";
const _areaTags = { "area", "resetArea", "resetType" };
const _enemySetTags = { "condition", "delay", "max", "param" };
const _enemySetAreaTags = { "searchArea", "escapeArea", "dist" };
