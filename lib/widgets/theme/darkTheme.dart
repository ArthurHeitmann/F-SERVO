
import 'package:flutter/material.dart';

import 'customTheme.dart';

class NierDarkThemeExtension extends NierThemeExtension {
  NierDarkThemeExtension()
    : super(
      editorBackgroundColor: const Color.fromRGBO(18, 18, 18, 1),
      editorIconPath: "assets/logo/pod_alpha.png",
      sidebarBackgroundColor: const Color.fromARGB(255, 50, 50, 50),
      dividerColor: const Color.fromRGBO(75, 75, 75, 1),
      tabColor: const Color.fromARGB(255, 59, 59, 59),
      tabSelectedColor: const Color.fromARGB(255, 36, 36, 36),
      tabIconColor: const Color.fromARGB(255, 255, 255, 255),
      dropTargetColor: Colors.black.withOpacity(0.5),
      textColor: Colors.white,
      titleBarColor: const Color.fromARGB(255, 49, 49, 49),
      titleBarTextColor: const Color.fromRGBO(200, 200, 200, 1),
      titleBarButtonDefaultColor: const Color.fromRGBO(239, 239, 239, 1),
      titleBarButtonPrimaryColor: Colors.blue,
      titleBarButtonCloseColor: Colors.redAccent,
      hierarchyEntryHovered: const Color.fromRGBO(255, 255, 255, 0.075),
      hierarchyEntrySelected: const Color.fromRGBO(255, 255, 255, 0.175),
      hierarchyEntrySelectedTextColor: Colors.white,
      hierarchyEntryClicked: const Color.fromRGBO(255, 255, 255, 0.2),
      filetypeDatColor: const Color.fromRGBO(0xfd, 0xd8, 0x35, 1),
      filetypePakColor: const Color.fromRGBO(0xff, 0x98, 0x00, 1),
      filetypeGroupColor: const Color.fromRGBO(0x00, 0xbc, 0xd4, 1),
      filetypeDocColor: const Color.fromRGBO(0xff, 0x70, 0x43, 1),
      formElementBgColor: const Color.fromRGBO(37, 37, 37, 1),
      actionBgColor: const Color.fromARGB(255, 53, 53, 53),
      actionTypeDefaultAccent: const Color.fromARGB(255, 30, 129, 209),
      actionTypeEntityAccent: const Color.fromARGB(255, 62, 145, 65),
      actionTypeBlockingAccent: const Color.fromARGB(255, 223, 134, 0),
      actionBorderRadius: 10,
      dialogPrimaryButtonStyle: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200),
        backgroundColor: MaterialStateProperty.all(Colors.blue),
        foregroundColor: MaterialStateProperty.all(Colors.white),
        overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.2)),
      ),
      dialogSecondaryButtonStyle: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200),
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        foregroundColor: MaterialStateProperty.all(Colors.white),
        overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.2)),
        shadowColor: MaterialStateProperty.all(Colors.transparent),
        side: MaterialStateProperty.all(BorderSide(color: Colors.grey.withOpacity(0.5))),
      ),
      selectedColor: Colors.blue.shade500.withOpacity(0.5),
      propInputTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFamily: "FiraCode",
        overflow: TextOverflow.ellipsis,
      ),
      propBorderColor: Colors.grey.shade700,
      contextMenuBgColor: const Color.fromARGB(255, 25, 25, 25),
      tableBgColor: const Color.fromARGB(255, 33, 33, 33),
      tableBgAltColor: const Color.fromARGB(255, 54, 54, 54),
      audioColor: const Color.fromARGB(255, 228, 162, 21),
      audioDisabledColor: const Color.fromARGB(126, 85, 63, 15),
      audioTimelineBgColor: const Color.fromARGB(255, 44, 44, 44),
      audioLabelColor: const Color.fromARGB(132, 255, 255, 255),
      entryCueColor: const Color.fromARGB(255, 66, 173, 45),
      exitCueColor: const Color.fromARGB(255, 204, 59, 43),
      customCueColor: const Color.fromARGB(255, 43, 129, 204),
    );

  static ThemeData makeTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      extensions: [NierDarkThemeExtension()],
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: "FiraCode",
        fontSizeFactor: 0.95,
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: Radius.zero,
        crossAxisMargin: 0,
        thickness: MaterialStateProperty.all(12),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color.fromARGB(255, 25, 25, 25),
      ),
      toggleableActiveColor: const Color.fromARGB(255, 228, 162, 21),
      colorScheme: const ColorScheme.dark(
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