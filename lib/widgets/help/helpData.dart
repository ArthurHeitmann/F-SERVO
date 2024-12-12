
import 'package:flutter/services.dart';

class HelpPage {
  final String title;
  final String content;

  HelpPage({required this.title, required this.content});
}

const _pages = [
  ("Welcome", "assets/help/intro.md"),
  ("BNK/Audio", "assets/help/bnk.md"),
  ("BXM", "assets/help/bxm.md"),
  ("CPK", "assets/help/cpk.md"),
  ("DAT", "assets/help/dat.md"),
  ("EST/Effects", "assets/help/est.md"),
  ("MCD", "assets/help/mcd.md"),
  ("WTA/WTB/WTP", "assets/help/wta.md"),
];

Future<List<HelpPage>> loadHelpData() {
  return Future.wait(
    _pages.map((e) async => HelpPage(title: e.$1, content: await rootBundle.loadString(e.$2)))
  );
}
