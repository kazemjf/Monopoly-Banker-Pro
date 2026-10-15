import 'strings.g.dart';

class LocaleMeta {
  final String id;
  final String label;
  final bool rtl;
  const LocaleMeta(this.id, this.label, this.rtl);
}

const List<LocaleMeta> kLocales = [
  LocaleMeta('en', 'English', false),
  LocaleMeta('fa', 'فارسی', true),
  LocaleMeta('tr', 'Türkçe', false),
  LocaleMeta('ar', 'العربية', true),
  LocaleMeta('de', 'Deutsch', false),
  LocaleMeta('fr', 'Français', false),
  LocaleMeta('it', 'Italiano', false),
  LocaleMeta('ko', '한국어', false),
  LocaleMeta('he', 'עברית', true),
  LocaleMeta('es', 'Español', false),
];

bool isLocaleId(String v) => kLocales.any((l) => l.id == v);
bool isRtl(String locale) =>
    kLocales.firstWhere((l) => l.id == locale, orElse: () => kLocales[0]).rtl;
String localeLabel(String locale) => kLocales
    .firstWhere((l) => l.id == locale, orElse: () => kLocales[0])
    .label;

/// Translate [key] in [locale], falling back to English, then the key itself.
/// Supports {{placeholder}} substitution via [params].
String tr(String locale, String key, [Map<String, String>? params]) {
  final dict = kLocaleStrings[locale] ?? kLocaleStrings['en']!;
  var s = dict[key] ?? kLocaleStrings['en']![key] ?? key;
  if (params != null) {
    params.forEach((k, v) {
      s = s.replaceAll('{{$k}}', v);
    });
  }
  return s;
}

/// Debug helper: verify every locale ships the same key set as English.
List<String> checkKeyParity() {
  final problems = <String>[];
  final base = kLocaleStrings['en']!.keys.toSet();
  for (final loc in kLocales) {
    final ks = kLocaleStrings[loc.id]!.keys.toSet();
    final missing = base.difference(ks);
    final extra = ks.difference(base);
    if (missing.isNotEmpty) problems.add('${loc.id} missing: ${missing.take(5)}');
    if (extra.isNotEmpty) problems.add('${loc.id} extra: ${extra.take(5)}');
    for (final k in base) {
      final v = kLocaleStrings[loc.id]![k]!;
      if (v.trim().isEmpty) problems.add('${loc.id}:$k empty');
    }
  }
  return problems;
}
