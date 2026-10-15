import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../i18n/l10n.dart';
import '../theme/themes.dart';

/// App preferences backed by SharedPreferences.
class Prefs extends ChangeNotifier {
  static const _kLocale = 'mbp-locale';
  static const _kLocaleSet = 'mbp-locale-set';
  static const _kTheme = 'mbp-theme';

  late SharedPreferences _sp;
  String locale = 'en';
  bool localeChosen = false;
  String themeId = 'dark';

  Prefs();

  Future<void> init() async {
    _sp = await SharedPreferences.getInstance();
    final rawLocale = _sp.getString(_kLocale) ?? 'en';
    locale = isLocaleId(rawLocale) ? rawLocale : 'en';
    localeChosen = _sp.getBool(_kLocaleSet) ?? false;
    final rawTheme = _sp.getString(_kTheme) ?? 'dark';
    themeId = kThemes.any((t) => t.id == rawTheme) ? rawTheme : 'dark';
  }

  Future<void> setLocale(String id) async {
    locale = id;
    localeChosen = true;
    await _sp.setString(_kLocale, id);
    await _sp.setBool(_kLocaleSet, true);
    notifyListeners();
  }

  Future<void> setTheme(String id) async {
    themeId = id;
    await _sp.setString(_kTheme, id);
    notifyListeners();
  }

  String t(String key, [Map<String, String>? params]) => tr(locale, key, params);
  bool get rtl => isRtl(locale);
}
