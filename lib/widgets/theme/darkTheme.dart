
import 'package:flutter/material.dart';

import 'customTheme.dart';

class NierDarkThemeExtension extends NierThemeExtension {
  NierDarkThemeExtension()
    : super(
      editorBackgroundColor: const Color.fromRGBO(18, 18, 18, 1),
      editorIconPath: "assets/logo/pod_alpha.png",
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
      hierarchyEntrySelectedTextColor: Colors.white,
      hierarchyEntryClicked: Color.fromRGBO(255, 255, 255, 0.2),
      filetypeDatColor: Color.fromRGBO(0xfd, 0xd8, 0x35, 1),
      filetypePakColor: Color.fromRGBO(0xff, 0x98, 0x00, 1),
      filetypeGroupColor: Color.fromRGBO(0x00, 0xbc, 0xd4, 1),
      filetypeXmlColor: Color.fromRGBO(0xff, 0x70, 0x43, 1),
      formElementBgColor: Color.fromRGBO(37, 37, 37, 1),
      actionBgColor: Color.fromARGB(255, 53, 53, 53),
      actionTypeDefaultAccent: Color.fromARGB(255, 30, 129, 209),
      actionTypeEntityAccent: Color.fromARGB(255, 62, 145, 65),
      actionTypeBlockingAccent: Color.fromARGB(255, 223, 134, 0),
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
      contextMenuBgColor: Color.fromARGB(255, 25, 25, 25),
      tableBgColor: Color.fromARGB(255, 33, 33, 33),
      tableBgAltColor: Color.fromARGB(255, 54, 54, 54),
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
      popupMenuTheme: PopupMenuThemeData(
        color: Color.fromARGB(255, 25, 25, 25),
      ),
      toggleableActiveColor: Color.fromARGB(255, 228, 162, 21),
      colorScheme: ColorScheme.dark(
        primary: Color.fromARGB(255, 228, 162, 21),
        secondary: Color.fromARGB(255, 228, 162, 21),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Colors.white.withOpacity(0.25),
        selectionHandleColor: Colors.white,
      ),
    );
  } 
}