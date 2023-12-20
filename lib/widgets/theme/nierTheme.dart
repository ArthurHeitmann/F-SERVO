
// ignore_for_file: unused_element

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
      filetypeDocColor: _ncOrange,
      formElementBgColor: _ncLight3,
      actionBgColor: _ncLight,
      actionTypeDefaultAccent: _ncBrownDark,
      actionTypeEntityAccent: _ncCyan2,
      actionTypeBlockingAccent: _ncRed,
      actionBorderRadius: 10,
      dialogPrimaryButtonStyle: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200),
        backgroundColor: MaterialStateProperty.all(_ncDark),
        foregroundColor: MaterialStateProperty.all(_ncLight),
        overlayColor: MaterialStateProperty.all(_ncLight.withOpacity(0.2)),
      ),
      dialogSecondaryButtonStyle: ButtonStyle(
        animationDuration: const Duration(milliseconds: 200),
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        foregroundColor: MaterialStateProperty.all(_ncDark),
        overlayColor: MaterialStateProperty.all(_ncDark.withOpacity(0.2)),
        shadowColor: MaterialStateProperty.all(Colors.transparent),
        side: MaterialStateProperty.all(const BorderSide(color: _ncDark)),
      ),
      selectedColor: _ncBrownDark,
      propInputTextStyle: const TextStyle(
        color: _ncDark,
        fontSize: 12,
        fontFamily: "FiraCode",
        overflow: TextOverflow.ellipsis,
      ),
      propBorderColor: _ncDark2,
      contextMenuBgColor: _ncLight2,
      tableBgColor: _ncLight,
      tableBgAltColor: _ncLight2,
      audioColor: _ncDark,
      audioDisabledColor: _ncBrownDark.withOpacity(0.5),
      audioTimelineBgColor: _ncLight,
      audioLabelColor: _ncBrownDark,
      entryCueColor: _ncCyan,
      exitCueColor: _ncOrange,
      customCueColor: _ncRed,
    );

  static ThemeData makeTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: false,
      extensions: [NierNierThemeExtension()],
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: "FiraCode",
        fontSizeFactor: 0.95,
        bodyColor: _ncDark,
        displayColor: _ncDark,
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
          color: _ncLight3,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(
          color: _ncDark,
          fontSize: 12,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: _ncLight2,
      ),
      toggleableActiveColor: _ncCyan,
      colorScheme: const ColorScheme.light(
        primary: _ncCyan,
        secondary: _ncCyan,
      ),
      iconTheme: const IconThemeData(
        color: _ncDark,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: _ncDark,
        selectionColor: _ncRed,
        selectionHandleColor: _ncRed,
      ),
    );
  } 
}


class NierOverlayPainter extends CustomPainter {
  final bool vignette;

  const NierOverlayPainter({this.vignette = true});

  @override
  void paint(Canvas canvas, Size size) {
    // grid
    const gridSize = 10;
    const gridColor = Color.fromARGB(10, 133, 125, 65);
    const lineW = 3.0;

    final paint = Paint()
      ..color = gridColor;

    for (double x = 0; x < size.width; x += gridSize)
      canvas.drawRect(Rect.fromLTWH(x, 0, lineW, size.height), paint);
    for (double y = 0; y < size.height; y += gridSize)
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, lineW), paint);

    // vignette
    if (vignette) {
      final vignettePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withOpacity(0.0),
            Colors.black.withOpacity(0.2),
          ],
          stops: const [0.7, 5.0],
          center: Alignment.center,
          radius: 1.0,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}