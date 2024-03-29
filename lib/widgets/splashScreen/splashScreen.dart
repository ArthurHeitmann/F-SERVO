
import 'dart:math';

import 'package:flutter/material.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  Offset? mousePos;
  late Image image;

  void onMouseMove(PointerEvent event) {
    mousePos = event.position;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var screenCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        mousePos ??= screenCenter + const Offset(0, 50);
        var angle = atan2(mousePos!.dy - screenCenter.dy, mousePos!.dx - screenCenter.dx) - pi / 2;
        return Listener(
          onPointerMove: onMouseMove,
          onPointerHover: onMouseMove,
          child: Container(
            color: const Color.fromRGBO(45, 43, 34, 1),
            child: Center(
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200, minWidth: 200),
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(129, 125, 111, 1),
                        spreadRadius: 20,
                        blurRadius: 100,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.asset("assets/logo/pod_logo.png")
                ),
              )
            )
          ),
        );
      }
    );
  }
}
