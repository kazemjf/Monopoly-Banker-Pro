import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly_banker_pro/data/editions.dart';
import 'package:monopoly_banker_pro/game/engine.dart';
import 'package:monopoly_banker_pro/i18n/l10n.dart';
import 'package:monopoly_banker_pro/models/game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly_banker_pro/main.dart';
import 'package:monopoly_banker_pro/store/prefs.dart';
import 'package:monopoly_banker_pro/store/game_store.dart';
import 'package:monopoly_banker_pro/theme/themes.dart';
import 'package:monopoly_banker_pro/screens/language_picker.dart';
import 'package:monopoly_banker_pro/screens/shell.dart';

Edition _fakeEdition() {
  // Minimal 40-space board built from the real London asset shape.
  final spaces = <BoardSpace>[];
  for (var n = 1; n <= 40; n++) {
    spaces.add(BoardSpace(n: n, name: 'Space $n', nameFa: 'خانه $n', type: 'free_parking'));
  }
  spaces[0] = BoardSpace(n: 1, name: 'GO', nameFa: 'شروع', type: 'go');
  spaces[1] = BoardSpace(
    n: 2, name: 'Test St', nameFa: 'تست', type: 'street', color: 'brown',
    price: 60, mortgage: 30, rent: const [2, 10, 30, 90, 160, 250], houseCost: 50,
  );
  spaces[3] = BoardSpace(
    n: 4, name: 'Test St 2', nameFa: 'تست ۲', type: 'street', color: 'brown',
    price: 60, mortgage: 30, rent: const [4, 20, 60, 180, 320, 450], houseCost: 50,
  );
  spaces[5] = BoardSpace(
    n: 6, name: 'RR', nameFa: 'راه', type: 'railroad', price: 200, mortgage: 100,
    rentByCount: const [25, 50, 100, 200],
  );
  return Edition(
    id: 'test', nameEn: 'Test', nameFa: 'تست',
    currencySymbol: '\$', currencyCode: 'USD',
    goSalary: 200, jailFine: 50,
    buildingCostsByColor: const {'brown': 50},
    spaces: spaces,
  );
}

GameState _fakeGame() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return GameState(
    id: 'g1', name: 'Test game', editionId: 'test',
    createdAt: now, updatedAt: now, startCash: 1500, goSalary: 200,
    players: [
      PlayerState(id: 'p1', name: 'Ava', cash: 1500),
      PlayerState(id: 'p2', name: 'Ben', cash: 1500),
    ],
  );
}

void main() {
  test('i18n key parity across all locales', () {
    final problems = checkKeyParity();
    expect(problems, isEmpty, reason: problems.take(5).join('\n'));
  });

  test('moveSteps wraps and detects GO pass', () {
    final r1 = moveSteps(39, 4);
    expect(r1.newPosition, 3);
    expect(r1.passedGo, true);
    final r2 = moveSteps(5, 3);
    expect(r2.newPosition, 8);
    expect(r2.passedGo, false);
  });

  test('street rent: base, doubled on full group, houses', () {
    final e = _fakeEdition();
    final g = _fakeGame();
    final space = e.space(2);
    // single ownership -> base rent
    g.deeds[2] = DeedState(spaceN: 2, ownerId: 'p1');
    expect(streetRent(g, e, space, g.deeds[2]!), 2);
    // full group -> doubled
    g.deeds[4] = DeedState(spaceN: 4, ownerId: 'p1');
    expect(streetRent(g, e, space, g.deeds[2]!), 4);
    // houses use table
    g.deeds[2]!.houses = 3;
    expect(streetRent(g, e, space, g.deeds[2]!), 90);
  });

  test('railroad rent by owned count + double toggle', () {
    final e = _fakeEdition();
    final g = _fakeGame();
    g.deeds[6] = DeedState(spaceN: 6, ownerId: 'p1');
    expect(railroadRent(g, e, 'p1'), 25);
    expect(railroadRent(g, e, 'p1', doubled: true), 50);
  });

  test('even-building rule', () {
    final e = _fakeEdition();
    final g = _fakeGame();
    g.deeds[2] = DeedState(spaceN: 2, ownerId: 'p1');
    // incomplete group -> cannot build
    expect(canBuild(g, e, 2), false);
    g.deeds[4] = DeedState(spaceN: 4, ownerId: 'p1');
    // complete group, even -> can build
    expect(canBuild(g, e, 2), true);
    // uneven (sibling at 2, this at 0 -> after build 1, sibling 2 > 1+... check)
    g.deeds[4]!.houses = 2;
    expect(canBuild(g, e, 2), false);
  });

  test('game JSON round-trip', () {
    final g = _fakeGame();
    g.deeds[2] = DeedState(spaceN: 2, ownerId: 'p1', houses: 2);
    final rt = GameState.fromJson(g.toJson());
    expect(rt.players.length, 2);
    expect(rt.deeds[2]!.houses, 2);
    expect(rt.name, 'Test game');
  });

  testWidgets('language picker two-step: tap selects pending, confirm applies',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Prefs();
    await prefs.init();
    final games = GameStore();
    // GameStore.init needs path_provider; skip it — picker doesn't need games.
    await tester.pumpWidget(
      AppScope(
        prefs: prefs,
        games: games,
        child: ActiveThemeScope(
          themeId: 'dark',
          child: MaterialApp(
            home: const LanguagePickerScreen(firstLaunch: false),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.ltr,
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('فارسی'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget);
    // scroll to German and tap it — should only mark pending, not apply
    await tester.scrollUntilVisible(
      find.text('Deutsch'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('Deutsch'));
    await tester.pump();
    expect(prefs.locale, 'en'); // not applied yet
    // confirm via the confirm button
    await tester.tap(find.text(prefs.t('action.confirm')));
    await tester.pump();
    expect(prefs.locale, 'de');
    expect(prefs.localeChosen, isTrue);
  });

  testWidgets('RTL (fa): language picker + shell render without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Prefs();
    await prefs.init();
    await prefs.setLocale('fa');
    final games = GameStore();
    await tester.pumpWidget(
      AppScope(
        prefs: prefs,
        games: games,
        child: ActiveThemeScope(
          themeId: 'dark',
          child: MaterialApp(
            home: const LanguagePickerScreen(firstLaunch: true),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // key picker widgets present in RTL
    expect(find.text('فارسی'), findsOneWidget);
    expect(find.text(prefs.t('lang.title')), findsOneWidget);
    expect(find.text(prefs.t('action.confirm')), findsOneWidget);

    // Now pump the shell (bottom nav + tabs) in RTL.
    await tester.pumpWidget(
      AppScope(
        prefs: prefs,
        games: games,
        child: ActiveThemeScope(
          themeId: 'dark',
          child: MaterialApp(
            home: const Shell(),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // all four bottom-nav tabs visible (labels may also appear as screen
    // titles, so accept multiple matches)
    expect(find.text(prefs.t('nav.games')), findsWidgets);
    expect(find.text(prefs.t('nav.newGame')), findsWidgets);
    expect(find.text(prefs.t('nav.settings')), findsWidgets);
    expect(find.text(prefs.t('nav.exit')), findsWidgets);
    // switch to settings tab and check rows render in RTL
    await tester.tap(find.text(prefs.t('nav.settings')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(prefs.t('settings.language')), findsOneWidget);
  });
}
