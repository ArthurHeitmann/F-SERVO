
import 'package:flutter/material.dart';

import 'customTheme.dart';

const _ncLight = Color.fromARGB(255, 205, 200, 176);
const _ncLight2 = Color.fromARGB(255, 218, 212, 187);
const _ncLight3 = Color.fromARGB(255, 180, 175, 154);
const _ncDark = Color.fromARGB(255, 78, 75, 61);
const _ncDark2 = Color.fromARGB(255, 99, 95, 84);
const _ncRed = Color.fromARGB(255, 184, 153, 127);
const _ncBrownLight = Color.fromARGB(255, 191, 178, 148);
const _ncBrownDark = Color.fromARGB(255, 135, 123, 100);
const _ncYellow = Color.fromARGB(255, 226, 217, 171);
const _ncWhite = Color.fromARGB(255, 234, 229, 209);
const _ncOrange = Color.fromARGB(255, 214, 100, 86);
const _ncCyan = Color.fromARGB(255, 65, 159, 143);
const _ncCyan2 = Color.fromARGB(255, 105, 181, 168);
// const _nc = Color.fromARGB(255, );
// const _nc = ;

class NierNierThemeExtension extends NierThemeExtension {
  NierNierThemeExtension()
    : super(
      editorBackgroundColor: _ncLight2,
      editorIconPath: "assets/logo/pod_logo.png",
      sidebarBackgroundColor: _ncLight,
      dividerColor: _ncLight3,
      tabColor: _ncLight,
      tabSelectedColor: _ncLight3,
      tabIconColor: _ncDark,
      dropTargetColor: _ncLight3,
      textColor: _ncDark,
      titleBarColor: _ncLight,
      titleBarTextColor: _ncDark,
      titleBarButtonDefaultColor: _ncDark,
      titleBarButtonPrimaryColor: _ncDark,
      titleBarButtonCloseColor: _ncOrange,
      hierarchyEntryHovered: _ncLight3,
      hierarchyEntrySelected: _ncDark,
      hierarchyEntrySelectedTextColor: _ncLight,
      hierarchyEntryClicked: _ncDark2,
      filetypeDatColor: _ncBrownDark,
      filetypePakColor: _ncBrownDark,
      filetypeGroupColor: _ncCyan,
      filetypeXmlColor: _ncOrange,
      formElementBgColor: _ncLight3,
      actionBgColor: _ncLight,
      actionTypeDefaultAccent: _ncBrownDark,
      actionTypeEntityAccent: _ncCyan2,
      actionTypeBlockingAccent: _ncRed,
      actionBorderRadius: 10,
      dialogPrimaryButtonStyle: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(_ncDark),
        foregroundColor: MaterialStateProperty.all(_ncLight),
      ),
      dialogSecondaryButtonStyle: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(_ncLight),
        foregroundColor: MaterialStateProperty.all(_ncDark),
        side: MaterialStateProperty.all(BorderSide(color: _ncDark)),
        shadowColor: MaterialStateProperty.all(Colors.transparent),
      ),
      selectedColor: _ncBrownDark,
      propInputTextStyle: TextStyle(
        color: _ncDark,
        fontSize: 12,
        fontFamily: "FiraCode",
        overflow: TextOverflow.ellipsis,
      ),
      propBorderColor: _ncDark2,
      contextMenuBgColor: _ncLight2,
      tableBgColor: _ncLight,
      tableBgAltColor: _ncLight2,
    );

  static ThemeData makeTheme() {
    return ThemeData(
      extensions: [NierNierThemeExtension()],
      textTheme: TextTheme(
        bodyText1: TextStyle(),
        bodyText2: TextStyle(),
      ).apply(
        bodyColor: _ncDark,
        displayColor: _ncDark,
      ),
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
          color: _ncLight3,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(
          color: _ncDark,
          fontSize: 12,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _ncLight2,
      ),
      toggleableActiveColor: _ncCyan,
      colorScheme: ColorScheme.light(
        primary: _ncCyan,
        secondary: _ncCyan,
      ),
      iconTheme: IconThemeData(
        color: _ncDark,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _ncDark,
        selectionColor: _ncBrownDark,
        selectionHandleColor: _ncBrownDark,
      ),
    );
  } 
}
