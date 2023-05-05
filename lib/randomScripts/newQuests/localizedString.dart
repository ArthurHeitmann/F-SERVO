
class LocalizedString {
  final String jp;
  final String de;
  final String es;
  final String fr;
  final String it;
  final String us;

  const LocalizedString({ required this.jp, required this.de, required this.es, required this.fr, required this.it, required this.us });
  const LocalizedString.all(String value) : this(jp: value, de: value, es: value, fr: value, it: value, us: value);
  const LocalizedString.us(String us, [String fallaback = "?"]) : this(jp: fallaback, de: fallaback, es: fallaback, fr: fallaback, it: fallaback, us: us);

  String getFromFileSuffix(String suffix) {
    switch (suffix) {
      case "": return jp;
      case "_de": return de;
      case "_es": return es;
      case "_fr": return fr;
      case "_it": return it;
      case "_us": return us;
      default: throw Exception("Unknown suffix: $suffix");
    }
  }
}
