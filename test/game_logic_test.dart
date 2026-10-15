import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly_banker_pro/data/editions.dart';
import 'package:monopoly_banker_pro/game/controller.dart';
import 'package:monopoly_banker_pro/game/engine.dart';
import 'package:monopoly_banker_pro/i18n/l10n.dart';
import 'package:monopoly_banker_pro/models/game.dart';

Edition _fakeEdition() {
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

GameController _ctl(GameState g, Edition e) =>
    GameController(game: g, edition: e, save: (_) async {});

void main() {
  group('nextTurn gating', () {
    test('blocked when the player has not moved', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      final info = await c.nextTurn('en');
      expect(info.advanced, isFalse);
      expect(info.blockReason, 'notMoved');
      expect(g.currentPlayerIdx, 0); // turn stays
    });

    test('blocked for jailed player with unresolved jail turn', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      await c.sendToJail('p1');
      g.players[0].movedThisTurn = false;
      final info = await c.nextTurn('en');
      expect(info.advanced, isFalse);
      expect(info.blockReason, 'jail');
      expect(g.currentPlayerIdx, 0);
    });

    test('BLOCKED on unowned property (no advance until buy/auction)', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      g.players[0].position = 2; // unowned street
      g.players[0].movedThisTurn = true;
      final info = await c.nextTurn('en');
      expect(info.advanced, isFalse);
      expect(info.blockReason, 'unowned');
      expect(g.currentPlayerIdx, 0);
      // resolve by buying, then the turn may advance
      await c.buyProperty('p1', 2);
      final info2 = await c.nextTurn('en');
      expect(info2.advanced, isTrue);
      expect(g.currentPlayerIdx, 1);
    });

    test('advances after a move; rent auto-paid to owner', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      g.deeds[2] = DeedState(spaceN: 2, ownerId: 'p2');
      await c.diceMove('p1', 1); // 1 -> 2
      expect(g.players[0].position, 2);
      final info = await c.nextTurn('en');
      expect(info.advanced, isTrue);
      expect(info.rentPaid, isTrue);
      expect(g.players[0].cash, 1500 - 2);
      expect(g.players[1].cash, 1500 + 2);
      expect(g.currentPlayerIdx, 1);
      expect(g.players[1].movedThisTurn, isFalse); // reset for new turn
    });

    test('no rent when landing on own / mortgaged property', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      g.deeds[2] = DeedState(spaceN: 2, ownerId: 'p1');
      await c.diceMove('p1', 1);
      final info = await c.nextTurn('en');
      expect(info.advanced, isTrue);
      expect(info.rentPaid, isFalse);
      expect(g.players[0].cash, 1500);
    });
  });

  group('doubles (RULE_DOUBLES)', () {
    test('1st/2nd doubles: extra turn, must move again', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      var o = await c.rollDice('p1', 6, wasDoubles: true);
      expect(o.extraTurn, isTrue);
      expect(g.players[0].position, 7);
      expect(g.players[0].consecutiveDoubles, 1);
      expect(g.players[0].movedThisTurn, isFalse); // must move again
      // Next is blocked until the extra-turn move happens
      var info = await c.nextTurn('en');
      expect(info.advanced, isFalse);
      expect(info.blockReason, 'notMoved');
      // second doubles
      o = await c.rollDice('p1', 4, wasDoubles: true);
      expect(o.extraTurn, isTrue);
      expect(g.players[0].consecutiveDoubles, 2);
      // non-doubles ends the streak
      o = await c.rollDice('p1', 5, wasDoubles: false);
      expect(o.extraTurn, isFalse);
      expect(g.players[0].consecutiveDoubles, 0);
      info = await c.nextTurn('en');
      expect(info.advanced, isTrue);
      expect(g.currentPlayerIdx, 1);
    });

    test('3rd consecutive doubles: straight to jail, no move, turn ends',
        () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      g.players[0].consecutiveDoubles = 2;
      g.players[0].position = 20;
      final o = await c.rollDice('p1', 6, wasDoubles: true);
      expect(o.sentToJail, isTrue);
      expect(g.players[0].jailed, isTrue);
      expect(g.players[0].position, 11); // jail, not 26
      expect(g.players[0].consecutiveDoubles, 0);
      final info = await c.nextTurn('en');
      expect(info.advanced, isTrue); // turn over
      expect(g.currentPlayerIdx, 1);
    });
  });

  group('jail (RULE_JAIL_EXIT)', () {
    test('failed doubles attempt: stays in jail, turn resolves', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      await c.sendToJail('p1');
      final o = await c.rollDice('p1', 7, wasDoubles: false);
      expect(o.stayedInJail, isTrue);
      expect(g.players[0].jailed, isTrue);
      expect(g.players[0].jailAttempts, 1);
      expect(g.players[0].position, 11); // not moved
      final info = await c.nextTurn('en');
      expect(info.advanced, isTrue);
    });

    test('3rd failed attempt: auto-pays \$50 and moves', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      await c.sendToJail('p1');
      g.players[0].jailAttempts = 2;
      final o = await c.rollDice('p1', 8, wasDoubles: false);
      expect(o.forcedFine, isTrue);
      expect(o.releasedFromJail, isTrue);
      expect(g.players[0].jailed, isFalse);
      expect(g.players[0].cash, 1500 - 50);
      expect(g.players[0].position, 19); // 11 + 8
      expect(g.players[0].jailAttempts, 0);
    });

    test('doubles releases from jail: moves, no extra turn', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      await c.sendToJail('p1');
      g.players[0].jailAttempts = 1;
      final o = await c.rollDice('p1', 6, wasDoubles: true);
      expect(o.releasedFromJail, isTrue);
      expect(o.extraTurn, isFalse);
      expect(g.players[0].jailed, isFalse);
      expect(g.players[0].position, 17);
      expect(g.players[0].jailAttempts, 0);
      final info = await c.nextTurn('en');
      expect(info.advanced, isTrue);
    });

    test('odd roll while jailed counts as a failed attempt', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      await c.sendToJail('p1');
      final o = await c.rollDice('p1', 7, wasDoubles: false);
      expect(o.stayedInJail, isTrue);
      expect(g.players[0].jailAttempts, 1);
    });
  });

  group('jailed movement restriction', () {
    test('diceMove / manualMove / setPosition blocked while jailed', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      await c.sendToJail('p1');
      await c.diceMove('p1', 5);
      expect(g.players[0].position, 11);
      await c.manualMove('p1', 20, goSalaryApplies: false);
      expect(g.players[0].position, 11);
      await c.setPosition('p1', 20);
      expect(g.players[0].position, 11);
    });

    test('pay/card release still requires a subsequent move', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      await c.sendToJail('p1');
      await c.releaseFromJail('p1', 'pay');
      expect(g.players[0].jailed, isFalse);
      expect(g.players[0].cash, 1500 - 50);
      final info = await c.nextTurn('en');
      expect(info.advanced, isFalse); // must move first
      expect(info.blockReason, 'notMoved');
    });
  });

  group('building rules', () {
    test('buildBlockReason: noFullGroup -> even -> uneven/groupMortgaged/maxed',
        () {
      final e = _fakeEdition();
      final g = _fakeGame();
      g.deeds[2] = DeedState(spaceN: 2, ownerId: 'p1');
      expect(buildBlockReason(g, e, 2), 'noFullGroup');
      expect(canBuild(g, e, 2), isFalse);
      g.deeds[4] = DeedState(spaceN: 4, ownerId: 'p1');
      expect(buildBlockReason(g, e, 2), isNull);
      expect(canBuild(g, e, 2), isTrue);
      // uneven: sibling has 2, this has 0 -> after build 1 < 2
      g.deeds[4]!.houses = 2;
      expect(buildBlockReason(g, e, 2), 'uneven');
      // even again at 2/2
      g.deeds[2]!.houses = 2;
      expect(buildBlockReason(g, e, 2), isNull);
      // mortgaged sibling blocks
      g.deeds[4]!.mortgaged = true;
      expect(buildBlockReason(g, e, 2), 'groupMortgaged');
      g.deeds[4]!.mortgaged = false;
      // hotel max
      g.deeds[2]!.houses = 5;
      expect(buildBlockReason(g, e, 2), 'maxed');
    });

    test('controller buildHouse enforces rules', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      g.deeds[2] = DeedState(spaceN: 2, ownerId: 'p1');
      g.deeds[4] = DeedState(spaceN: 4, ownerId: 'p2'); // not full group
      await c.buildHouse('p1', 2);
      expect(g.deeds[2]!.houses, 0);
      expect(g.players[0].cash, 1500);
      g.deeds[4]!.ownerId = 'p1'; // full group now
      await c.buildHouse('p1', 2);
      expect(g.deeds[2]!.houses, 1);
      expect(g.players[0].cash, 1500 - 50);
    });

    test('even selling: sell from the most-developed street first', () async {
      final e = _fakeEdition();
      final g = _fakeGame();
      final c = _ctl(g, e);
      g.deeds[2] = DeedState(spaceN: 2, ownerId: 'p1', houses: 2);
      g.deeds[4] = DeedState(spaceN: 4, ownerId: 'p1', houses: 3);
      expect(canSellBuilding(g, e, 2), isFalse); // 2 < 3
      expect(canSellBuilding(g, e, 4), isTrue);
      await c.sellBuilding('p1', 2); // blocked
      expect(g.deeds[2]!.houses, 2);
      await c.sellBuilding('p1', 4); // allowed
      expect(g.deeds[4]!.houses, 2);
      expect(g.players[0].cash, 1500 + 25); // half of 50
    });
  });

  group('persistence compat', () {
    test('old saves without new fields load with defaults', () {
      final j = {
        'id': 'p9', 'name': 'Old', 'cash': 1500, 'position': 5,
        'jailed': false, 'jailCards': 0, 'hasMoved': true, 'bankrupt': false,
      };
      final p = PlayerState.fromJson(j);
      expect(p.movedThisTurn, isFalse);
      expect(p.jailAttempts, 0);
      expect(p.consecutiveDoubles, 0);
      final rt = PlayerState.fromJson(p.toJson());
      expect(rt.movedThisTurn, isFalse);
    });
  });

  group('new i18n keys', () {
    test('placeholders consistent across locales', () {
      const keys = [
        'play.doublesExtraTurn', 'play.doublesToJail', 'play.jailForcedFine',
        'play.jailNoMove', 'play.jailReleasedDoubles', 'play.jailStayed',
        'play.jailTurnMsg', 'play.notMovedMsg', 'play.unownedBlockMsg',
        'action.yes', 'action.no',
      ];
      final ph = RegExp(r'\{\{[a-zA-Z]+\}\}');
      for (final k in keys) {
        final base = ph.allMatches(tr('en', k)).map((m) => m.group(0)).toSet();
        for (final loc in ['fa', 'de', 'fr', 'it', 'es', 'tr', 'ar', 'ko', 'he']) {
          final got = ph.allMatches(tr(loc, k)).map((m) => m.group(0)).toSet();
          expect(got, base, reason: '$loc:$k placeholders $got != $base');
        }
      }
    });
  });
}
