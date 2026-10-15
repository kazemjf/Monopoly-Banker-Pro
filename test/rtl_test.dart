import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly_banker_pro/main.dart';
import 'package:monopoly_banker_pro/store/prefs.dart';
import 'package:monopoly_banker_pro/store/game_store.dart';
import 'package:monopoly_banker_pro/screens/settings_page.dart';
import 'package:monopoly_banker_pro/screens/help_page.dart';
import 'package:monopoly_banker_pro/screens/about_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RTL (fa) regression tests for the user-reported breakage:
/// settings popups, help/about back buttons, exit confirm, wizard fields.
/// Root cause was missing flutter_localizations (no MaterialLocalizations);
/// these tests pump the REAL AppRoot to guard against regressions.
Future<(Prefs, GameStore)> bootFa() async {
  SharedPreferences.setMockInitialValues(
      {'mbp-locale': 'fa', 'mbp-locale-set': true});
  final prefs = Prefs();
  await prefs.init();
  return (prefs, GameStore());
}

Future<void> pumpApp(WidgetTester tester, Prefs prefs, GameStore games) async {
  await tester.pumpWidget(AppRoot(prefs: prefs, games: games));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('RTL fa: settings language popup opens', (tester) async {
    final (prefs, games) = await bootFa();
    await pumpApp(tester, prefs, games);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('زبان'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL fa: settings theme popup opens', (tester) async {
    final (prefs, games) = await bootFa();
    await pumpApp(tester, prefs, games);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL fa: help back button is visible and pops', (tester) async {
    final (prefs, games) = await bootFa();
    await pumpApp(tester, prefs, games);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('راهنما'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpPage), findsOneWidget);
    final back = find.byType(BackButton);
    expect(back, findsOneWidget);
    final rect = tester.getRect(back);
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(HelpPage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL fa: about back button is visible and pops', (tester) async {
    final (prefs, games) = await bootFa();
    await pumpApp(tester, prefs, games);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('درباره').first);
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL fa: exit tab shows confirm dialog', (tester) async {
    final (prefs, games) = await bootFa();
    await pumpApp(tester, prefs, games);
    await tester.tap(find.byIcon(Icons.exit_to_app));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(prefs.t('exit.message')), findsOneWidget);
    // dismiss via cancel
    await tester.tap(find.text(prefs.t('action.cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL fa: wizard name field editable + back works',
      (tester) async {
    final (prefs, games) = await bootFa();
    await pumpApp(tester, prefs, games);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    // step 0 -> step 1 (rules: name field)
    await tester.tap(find.text(prefs.t('action.confirm')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    await tester.tap(fields.first);
    await tester.pump();
    await tester.enterText(fields.first, 'بازی تست');
    await tester.pump();
    expect(find.text('بازی تست'), findsOneWidget);
    // back button visible and goes back to step 0
    final backBtn = find.text(prefs.t('action.back'));
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();
    expect(find.text(prefs.t('edition.hint')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
