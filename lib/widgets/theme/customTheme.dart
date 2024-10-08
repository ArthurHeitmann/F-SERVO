
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../../stateManagement/hierarchy/types/BnkHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/DatHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/PakHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/RubyScriptHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/TmdHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/WaiHierarchyEntries.dart';
import '../../stateManagement/hierarchy/types/XmlScriptHierarchyEntry.dart';

class NierThemeExtension extends ThemeExtension<NierThemeExtension> {
  final Color? editorBackgroundColor;
  final String? editorIconPath;
  final Color? sidebarBackgroundColor;
  final Color? dividerColor;
  final Color? tabColor;
  final Color? tabSelectedColor;
  final Color? tabIconColor;
  final Color? iconColor;
  final Color? dropTargetColor;
  final Color? textColor;
  final Color? titleBarColor;
  final Color? titleBarTextColor;
  final Color? titleBarButtonDefaultColor;
  final Color? titleBarButtonPrimaryColor;
  final Color? titleBarButtonCloseColor;
  final Color? hierarchyEntryHovered;
  final Color? hierarchyEntrySelected;
  final Color? hierarchyEntrySelectedTextColor;
  final Color? hierarchyEntryClicked;
  final Color? filetypeDatColor;
  final Color? filetypePakColor;
  final Color? filetypeGroupColor;
  final Color? filetypeDocColor;
  final Color? formElementBgColor;
  final Color? actionBgColor;
  final Color? actionTypeDefaultAccent;
  final Color? actionTypeEntityAccent;
  final Color? actionTypeBlockingAccent;
  final double? actionBorderRadius;
  final ButtonStyle? dialogPrimaryButtonStyle;
  final ButtonStyle? dialogSecondaryButtonStyle;
  final Color? selectedColor;
  final TextStyle? propInputTextStyle;
  final Color? propBorderColor;
  final Color? contextMenuBgColor;
  final Color? tableBgColor;
  final Color? tableBgAltColor;
  final Color? audioColor;
  final Color? audioDisabledColor;
  final Color? audioTimelineBgColor;
  final Color? audioLabelColor;
  final Color? entryCueColor;
  final Color? exitCueColor;
  final Color? customCueColor;

  NierThemeExtension({
    this.editorBackgroundColor,
    this.editorIconPath,
    this.sidebarBackgroundColor,
    this.dividerColor,
    this.tabColor,
    this.tabSelectedColor,
    this.tabIconColor,
    this.iconColor,
    this.dropTargetColor,
    this.textColor,
    this.titleBarColor,
    this.titleBarTextColor,
    this.titleBarButtonDefaultColor,
    this.titleBarButtonPrimaryColor,
    this.titleBarButtonCloseColor,
    this.hierarchyEntryHovered,
    this.hierarchyEntrySelected,
    this.hierarchyEntrySelectedTextColor,
    this.hierarchyEntryClicked,
    this.filetypeDatColor,
    this.filetypePakColor,
    this.filetypeGroupColor,
    this.filetypeDocColor,
    this.formElementBgColor,
    this.actionBgColor,
    this.actionTypeDefaultAccent,
    this.actionTypeEntityAccent,
    this.actionTypeBlockingAccent,
    this.actionBorderRadius,
    this.dialogPrimaryButtonStyle,
    this.dialogSecondaryButtonStyle,
    this.selectedColor,
    this.propInputTextStyle,
    this.propBorderColor,
    this.contextMenuBgColor,
    this.tableBgColor,
    this.tableBgAltColor,
    this.audioColor,
    this.audioDisabledColor,
    this.audioTimelineBgColor,
    this.audioLabelColor,
    this.entryCueColor,
    this.exitCueColor,
    this.customCueColor,
  });
  
  @override
  ThemeExtension<NierThemeExtension> copyWith({
    Color? editorBackgroundColor,
    String? editorIconPath,
    Color? sidebarBackgroundColor,
    Color? dividerColor,
    Color? tabColor,
    Color? tabSelectedColor,
    Color? tabIconColor,
    Color? iconColor,
    Color? dropTargetColor,
    Color? textColor,
    Color? titleBarColor,
    Color? titleBarTextColor,
    Color? titleBarButtonDefaultColor,
    Color? titleBarButtonPrimaryColor,
    Color? titleBarButtonCloseColor,
    Color? hierarchyEntryHovered,
    Color? hierarchyEntrySelected,
    Color? hierarchyEntrySelectedTextColor,
    Color? hierarchyEntryClicked,
    Color? filetypeDatColor,
    Color? filetypePakColor,
    Color? filetypeGroupColor,
    Color? filetypeDocColor,
    Color? formElementBgColor,
    Color? actionBgColor,
    Color? actionTypeDefaultAccent,
    Color? actionTypeEntityAccent,
    Color? actionTypeBlockingAccent,
    double? actionBorderRadius,
    ButtonStyle? dialogPrimaryButtonStyle,
    ButtonStyle? dialogSecondaryButtonStyle,
    Color? selectedColor,
    TextStyle? propInputTextStyle,
    Color? propBorderColor,
    Color? contextMenuBgColor,
    Color? tableBgColor,
    Color? tableBgAltColor,
    Color? audioColor,
    Color? audioDisabledColor,
    Color? audioTimelineBgColor,
    Color? audioLabelColor,
    Color? entryCueColor,
    Color? exitCueColor,
    Color? customCueColor,
  }) {
    return NierThemeExtension(
      editorBackgroundColor: editorBackgroundColor ?? this.editorBackgroundColor,
      editorIconPath: editorIconPath ?? this.editorIconPath,
      sidebarBackgroundColor: sidebarBackgroundColor ?? this.sidebarBackgroundColor,
      dividerColor: dividerColor ?? this.dividerColor,
      tabColor: tabColor ?? this.tabColor,
      tabSelectedColor: tabSelectedColor ?? this.tabSelectedColor,
      tabIconColor: tabIconColor ?? this.tabIconColor,
      iconColor: iconColor ?? this.iconColor,
      dropTargetColor: dropTargetColor ?? this.dropTargetColor,
      textColor: textColor ?? this.textColor,
      titleBarColor: titleBarColor ?? this.titleBarColor,
      titleBarTextColor: titleBarTextColor ?? this.titleBarTextColor,
      titleBarButtonDefaultColor: titleBarButtonDefaultColor ?? this.titleBarButtonDefaultColor,
      titleBarButtonPrimaryColor: titleBarButtonPrimaryColor ?? this.titleBarButtonPrimaryColor,
      titleBarButtonCloseColor: titleBarButtonCloseColor ?? this.titleBarButtonCloseColor,
      hierarchyEntryHovered: hierarchyEntryHovered ?? this.hierarchyEntryHovered,
      hierarchyEntrySelected: hierarchyEntrySelected ?? this.hierarchyEntrySelected,
      hierarchyEntrySelectedTextColor: hierarchyEntrySelectedTextColor ?? this.hierarchyEntrySelectedTextColor,
      hierarchyEntryClicked: hierarchyEntryClicked ?? this.hierarchyEntryClicked,
      filetypeDatColor: filetypeDatColor ?? this.filetypeDatColor,
      filetypePakColor: filetypePakColor ?? this.filetypePakColor,
      filetypeGroupColor: filetypeGroupColor ?? this.filetypeGroupColor,
      filetypeDocColor: filetypeDocColor ?? this.filetypeDocColor,
      formElementBgColor: formElementBgColor ?? this.formElementBgColor,
      actionBgColor: actionBgColor ?? this.actionBgColor,
      actionTypeDefaultAccent: actionTypeDefaultAccent ?? this.actionTypeDefaultAccent,
      actionTypeEntityAccent: actionTypeEntityAccent ?? this.actionTypeEntityAccent,
      actionTypeBlockingAccent: actionTypeBlockingAccent ?? this.actionTypeBlockingAccent,
      actionBorderRadius: actionBorderRadius ?? this.actionBorderRadius,
      dialogPrimaryButtonStyle: dialogPrimaryButtonStyle ?? this.dialogPrimaryButtonStyle,
      dialogSecondaryButtonStyle: dialogSecondaryButtonStyle ?? this.dialogSecondaryButtonStyle,
      selectedColor: selectedColor ?? this.selectedColor,
      propInputTextStyle: propInputTextStyle ?? this.propInputTextStyle,
      propBorderColor: propBorderColor ?? this.propBorderColor,
      contextMenuBgColor: contextMenuBgColor ?? this.contextMenuBgColor,
      tableBgColor: tableBgColor ?? this.tableBgColor,
      tableBgAltColor: tableBgAltColor ?? this.tableBgAltColor,
      audioColor: audioColor ?? this.audioColor,
      audioDisabledColor: audioDisabledColor ?? this.audioDisabledColor,
      audioTimelineBgColor: audioTimelineBgColor ?? this.audioTimelineBgColor,
      audioLabelColor: audioLabelColor ?? this.audioLabelColor,
      entryCueColor: entryCueColor ?? this.entryCueColor,
      exitCueColor: exitCueColor ?? this.exitCueColor,
      customCueColor: customCueColor ?? this.customCueColor,
    );
  }
  
  @override
  ThemeExtension<NierThemeExtension> lerp(ThemeExtension<NierThemeExtension>? other, double t) {
    if (other == null || other is! NierThemeExtension) {
      return this;
    }
    return NierThemeExtension(
      editorBackgroundColor: Color.lerp(editorBackgroundColor, other.editorBackgroundColor, t),
      editorIconPath: t < 0.5 ? editorIconPath : other.editorIconPath,
      sidebarBackgroundColor: Color.lerp(sidebarBackgroundColor, other.sidebarBackgroundColor, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      tabColor: Color.lerp(tabColor, other.tabColor, t),
      tabSelectedColor: Color.lerp(tabSelectedColor, other.tabSelectedColor, t),
      tabIconColor: Color.lerp(tabIconColor, other.tabIconColor, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      dropTargetColor: Color.lerp(dropTargetColor, other.dropTargetColor, t),
      textColor: Color.lerp(textColor, other.textColor, t),
      titleBarColor: Color.lerp(titleBarColor, other.titleBarColor, t),
      titleBarTextColor: Color.lerp(titleBarTextColor, other.titleBarTextColor, t),
      titleBarButtonDefaultColor: Color.lerp(titleBarButtonDefaultColor, other.titleBarButtonDefaultColor, t),
      titleBarButtonPrimaryColor: Color.lerp(titleBarButtonPrimaryColor, other.titleBarButtonPrimaryColor, t),
      titleBarButtonCloseColor: Color.lerp(titleBarButtonCloseColor, other.titleBarButtonCloseColor, t),
      hierarchyEntryHovered: Color.lerp(hierarchyEntryHovered, other.hierarchyEntryHovered, t),
      hierarchyEntrySelected: Color.lerp(hierarchyEntrySelected, other.hierarchyEntrySelected, t),
      hierarchyEntrySelectedTextColor: Color.lerp(hierarchyEntrySelectedTextColor, other.hierarchyEntrySelectedTextColor, t),
      hierarchyEntryClicked: Color.lerp(hierarchyEntryClicked, other.hierarchyEntryClicked, t),
      filetypeDatColor: Color.lerp(filetypeDatColor, other.filetypeDatColor, t),
      filetypePakColor: Color.lerp(filetypePakColor, other.filetypePakColor, t),
      filetypeGroupColor: Color.lerp(filetypeGroupColor, other.filetypeGroupColor, t),
      filetypeDocColor: Color.lerp(filetypeDocColor, other.filetypeDocColor, t),
      formElementBgColor: Color.lerp(formElementBgColor, other.formElementBgColor, t),
      actionBgColor: Color.lerp(actionBgColor, other.actionBgColor, t),
      actionTypeDefaultAccent: Color.lerp(actionTypeDefaultAccent, other.actionTypeDefaultAccent, t),
      actionTypeEntityAccent: Color.lerp(actionTypeEntityAccent, other.actionTypeEntityAccent, t),
      actionTypeBlockingAccent: Color.lerp(actionTypeBlockingAccent, other.actionTypeBlockingAccent, t),
      actionBorderRadius: lerpDouble(actionBorderRadius, other.actionBorderRadius, t),
      dialogPrimaryButtonStyle: ButtonStyle.lerp(dialogPrimaryButtonStyle, other.dialogPrimaryButtonStyle, t),
      dialogSecondaryButtonStyle: ButtonStyle.lerp(dialogSecondaryButtonStyle, other.dialogSecondaryButtonStyle, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      propInputTextStyle: TextStyle.lerp(propInputTextStyle, other.propInputTextStyle, t),
      propBorderColor: Color.lerp(propBorderColor, other.propBorderColor, t),
      contextMenuBgColor: Color.lerp(contextMenuBgColor, other.contextMenuBgColor, t),
      tableBgColor: Color.lerp(tableBgColor, other.tableBgColor, t),
      tableBgAltColor: Color.lerp(tableBgAltColor, other.tableBgAltColor, t),
      audioColor: Color.lerp(audioColor, other.audioColor, t),
      audioDisabledColor: Color.lerp(audioDisabledColor, other.audioDisabledColor, t),
      audioTimelineBgColor: Color.lerp(audioTimelineBgColor, other.audioTimelineBgColor, t),
      audioLabelColor: Color.lerp(audioLabelColor, other.audioLabelColor, t),
      entryCueColor: Color.lerp(entryCueColor, other.entryCueColor, t),
      exitCueColor: Color.lerp(exitCueColor, other.exitCueColor, t),
      customCueColor: Color.lerp(customCueColor, other.customCueColor, t),
    );
  }

  Color colorOfFiletype(HierarchyEntry entry) {
    if (entry is XmlScriptHierarchyEntry || entry is RubyScriptHierarchyEntry || entry is TmdHierarchyEntry || entry is TmdHierarchyEntry)
      return filetypeDocColor!;
    if (entry is PakHierarchyEntry || entry is WspHierarchyEntry || entry is BnkHierarchyEntry)
      return filetypePakColor!;
    if (entry is DatHierarchyEntry || entry is WaiFolderHierarchyEntry)
      return filetypeDatColor!;
    if (entry is HapGroupHierarchyEntry || entry is WemHierarchyEntry)
      return filetypeGroupColor!;
    if (entry is BnkHircHierarchyEntry) {
      if (entry.type == "WEM")
        return filetypeGroupColor!;
      else if (entry.type == "Event")
        return filetypePakColor!;
      else if (entry.type == "Action")
        return titleBarButtonCloseColor!;
      else if (entry.type == "MusicPlaylist")
        return filetypePakColor!;
    }

    return textColor!;
  }
}

NierThemeExtension getTheme(context) {
  return Theme.of(context).extension<NierThemeExtension>()!;
}
