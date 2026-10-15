import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'i18n/l10n.dart';
import 'store/prefs.dart';
import 'store/game_store.dart';
import 'theme/themes.dart';
import 'screens/language_picker.dart';
import 'screens/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = Prefs();
  await prefs.init();
  final games = GameStore();
  await games.init();
  runApp(AppRoot(prefs: prefs, games: games));
}

/// Provides Prefs + GameStore to the whole tree.
class AppScope extends InheritedWidget {
  final Prefs prefs;
  final GameStore games;
  const AppScope({super.key, required this.prefs, required this.games, required super.child});

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => false;
}

class AppRoot extends StatefulWidget {
  final Prefs prefs;
  final GameStore games;
  const AppRoot({super.key, required this.prefs, required this.games});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    widget.prefs.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.prefs.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final prefs = widget.prefs;
    final theme = themeById(prefs.themeId);
    return AppScope(
      prefs: prefs,
      games: widget.games,
      child: ActiveThemeScope(
        themeId: prefs.themeId,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Monopoly Banker Pro',
          theme: theme.themeData,
          locale: Locale(prefs.locale),
          supportedLocales: kLocales.map((l) => Locale(l.id)),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: prefs.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
          home: prefs.localeChosen ? const Shell() : const LanguagePickerScreen(firstLaunch: true),
        ),
      ),
    );
  }
}

/// Yes/No question dialog.
Future<bool> askYesNo(BuildContext context,
    {required String title, required String message}) async {
  final prefs = AppScope.of(context).prefs;
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(prefs.t('action.no')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(prefs.t('action.yes')),
        ),
      ],
    ),
  );
  return res == true;
}

/// Reusable confirm dialog.
Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String? confirmLabel, bool danger = false}) async {
  final prefs = AppScope.of(context).prefs;
  final pal = paletteOf(context);
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(prefs.t('action.cancel')),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: pal.danger, foregroundColor: pal.dangerInk)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? prefs.t('action.confirm')),
        ),
      ],
    ),
  );
  return res == true;
}

/// Small helper for section headers.
class SectionHeader extends StatelessWidget {
  final String text;
  const SectionHeader(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text,
          style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

/// Amount input dialog returning an int, or null if cancelled.
Future<int?> amountDialog(BuildContext context,
    {required String title, int initial = 0, String? hint}) async {
  final prefs = AppScope.of(context).prefs;
  final ctrl = TextEditingController(text: initial == 0 ? '' : '$initial');
  final res = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]*'))],
        decoration: InputDecoration(hintText: hint ?? '0'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(prefs.t('action.cancel')),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(ctrl.text.trim());
            Navigator.of(ctx).pop(v);
          },
          child: Text(prefs.t('action.confirm')),
        ),
      ],
    ),
  );
  return res;
}
