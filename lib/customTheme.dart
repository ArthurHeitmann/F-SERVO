
import 'dart:ui';

import 'package:flutter/material.dart';

class NierThemeExtension extends ThemeExtension<NierThemeExtension> {
  final Color? editorBackgroundColor;
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
  final Color? hierarchyEntryClicked;
  final Color? formElementBgColor;
  final Color? actionBgColor;
  final double? actionBorderRadius;
  final ButtonStyle? dialogPrimaryButtonStyle;
  final ButtonStyle? dialogSecondaryButtonStyle;
  final Color? selectedColor;
  final TextStyle? propInputTextStyle;
  final Color? propBorderColor;
  final Color? contextMenuBgColor;

  NierThemeExtension({
    this.editorBackgroundColor,
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
    this.hierarchyEntryClicked,
    this.formElementBgColor,
    this.actionBgColor,
    this.actionBorderRadius,
    this.dialogPrimaryButtonStyle,
    this.dialogSecondaryButtonStyle,
    this.selectedColor,
    this.propInputTextStyle,
    this.propBorderColor,
    this.contextMenuBgColor,
  });
  
  @override
  ThemeExtension<NierThemeExtension> copyWith({
    Color? editorBackgroundColor,
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
    Color? hierarchyEntryClicked,
    Color? formElementBgColor,
    Color? actionBgColor,
    double? actionBorderRadius,
    ButtonStyle? dialogPrimaryButtonStyle,
    ButtonStyle? dialogSecondaryButtonStyle,
    Color? selectedColor,
    TextStyle? propInputTextStyle,
    Color? propBorderColor,
    Color? contextMenuBgColor,
  }) {
    return NierThemeExtension(
      editorBackgroundColor: editorBackgroundColor ?? this.editorBackgroundColor,
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
      hierarchyEntryClicked: hierarchyEntryClicked ?? this.hierarchyEntryClicked,
      formElementBgColor: formElementBgColor ?? this.formElementBgColor,
      actionBgColor: actionBgColor ?? this.actionBgColor,
      actionBorderRadius: actionBorderRadius ?? this.actionBorderRadius,
      dialogPrimaryButtonStyle: dialogPrimaryButtonStyle ?? this.dialogPrimaryButtonStyle,
      dialogSecondaryButtonStyle: dialogSecondaryButtonStyle ?? this.dialogSecondaryButtonStyle,
      selectedColor: selectedColor ?? this.selectedColor,
      propInputTextStyle: propInputTextStyle ?? this.propInputTextStyle,
      propBorderColor: propBorderColor ?? this.propBorderColor,
      contextMenuBgColor: contextMenuBgColor ?? this.contextMenuBgColor,
    );
  }
  
  @override
  ThemeExtension<NierThemeExtension> lerp(ThemeExtension<NierThemeExtension>? other, double t) {
    if (other == null || other is! NierThemeExtension) {
      return this;
    }
    return NierThemeExtension(
      editorBackgroundColor: Color.lerp(editorBackgroundColor, other.editorBackgroundColor, t),
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
      hierarchyEntryClicked: Color.lerp(hierarchyEntryClicked, other.hierarchyEntryClicked, t),
      formElementBgColor: Color.lerp(formElementBgColor, other.formElementBgColor, t),
      actionBgColor: Color.lerp(actionBgColor, other.actionBgColor, t),
      actionBorderRadius: lerpDouble(actionBorderRadius, other.actionBorderRadius, t),
      dialogPrimaryButtonStyle: ButtonStyle.lerp(dialogPrimaryButtonStyle, other.dialogPrimaryButtonStyle, t),
      dialogSecondaryButtonStyle: ButtonStyle.lerp(dialogSecondaryButtonStyle, other.dialogSecondaryButtonStyle, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      propInputTextStyle: TextStyle.lerp(propInputTextStyle, other.propInputTextStyle, t),
      propBorderColor: Color.lerp(propBorderColor, other.propBorderColor, t),
      contextMenuBgColor: Color.lerp(contextMenuBgColor, other.contextMenuBgColor, t),
    );
  }
}

class NierDarkThemeExtension extends NierThemeExtension {
  NierDarkThemeExtension()
    : super(
      editorBackgroundColor: const Color.fromRGBO(18, 18, 18, 1),
      sidebarBackgroundColor: Color.fromARGB(255, 50, 50, 50),
      dividerColor: Color.fromRGBO(255, 255, 255, 0.1),
      tabColor: Color.fromARGB(255, 59, 59, 59),
      tabSelectedColor: Color.fromARGB(255, 36, 36, 36),
      tabIconColor: Color.fromARGB(255, 255, 255, 255),
      dropTargetColor: Colors.black.withOpacity(0.5),
      textColor: Colors.white,
      titleBarColor: Color.fromARGB(255, 49, 49, 49),
      titleBarTextColor: Color.fromRGBO(200, 200, 200, 1),
      titleBarButtonDefaultColor: Color.fromRGBO(239, 239, 239, 1),
      titleBarButtonPrimaryColor: Colors.blue,
      titleBarButtonCloseColor: Colors.redAccent,
      hierarchyEntryHovered: Color.fromRGBO(255, 255, 255, 0.075),
      hierarchyEntrySelected: Color.fromRGBO(255, 255, 255, 0.175),
      hierarchyEntryClicked: Color.fromRGBO(255, 255, 255, 0.2),
      formElementBgColor: Color.fromRGBO(37, 37, 37, 1),
      actionBgColor: Color.fromARGB(255, 53, 53, 53),
      actionBorderRadius: 10,
      dialogPrimaryButtonStyle: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(Colors.blue),
        foregroundColor: MaterialStateProperty.all(Colors.white),
      ),
      dialogSecondaryButtonStyle: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        foregroundColor: MaterialStateProperty.all(Colors.white),
        side: MaterialStateProperty.all(BorderSide(color: Colors.grey)),
        shadowColor: MaterialStateProperty.all(Colors.transparent),
      ),
      selectedColor: Colors.blue.shade500.withOpacity(0.5),
      propInputTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFamily: "FiraCode",
        overflow: TextOverflow.ellipsis,
      ),
      propBorderColor: Colors.grey.shade700,
      contextMenuBgColor: Color.fromARGB(255, 65, 65, 65),
    );

  static ThemeData makeTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      extensions: [NierDarkThemeExtension()],
      scrollbarTheme: ScrollbarThemeData(
        radius: Radius.zero,
        crossAxisMargin: 0,
        thickness: MaterialStateProperty.all(12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  } 
}

NierThemeExtension getTheme(context) {
  return Theme.of(context).extension<NierThemeExtension>()!;
}
