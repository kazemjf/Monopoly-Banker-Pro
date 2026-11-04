import 'package:flutter/foundation.dart';
import '../data/editions.dart';
import '../models/game.dart';
import 'engine.dart';

String fmtMoney(int amount, String symbol) {
  final neg = amount < 0;
  final v = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < v.length; i++) {
    if (i > 0 && (v.length - i) % 3 == 0) buf.write(',');
    buf.write(v[i]);
  }
  return '${neg ? '-' : ''}$symbol${buf}';
}

/// Outcome of a dice roll: doubles / jail interactions per official rules.
class DiceOutcome {
  final bool extraTurn; // doubles (1st/2nd): same player rolls again
  final bool sentToJail; // 3rd consecutive doubles
  final bool releasedFromJail; // doubles release, or forced release after 3rd fail
  final bool forcedFine; // 3rd failed jail attempt: auto-paid $50
  final bool stayedInJail; // failed doubles attempt, still jailed
  const DiceOutcome({
    this.extraTurn = false,
    this.sentToJail = false,
    this.releasedFromJail = false,
    this.forcedFine = false,
    this.stayedInJail = false,
  });
}

/// Outcome of advancing the turn, so the UI can notify the banker
/// about auto-paid rent, or explain why the turn did NOT advance.
class NextTurnInfo {
  final bool advanced;
  final String? blockReason; // 'unowned' | 'notMoved' | 'jail' (when !advanced)
  final bool rentPaid;
  final String playerName;
  final String ownerName;
  final String spaceName;
  final int amount;
  const NextTurnInfo({
    this.advanced = true,
    this.blockReason,
    this.rentPaid = false,
    this.playerName = '',
    this.ownerName = '',
    this.spaceName = '',
    this.amount = 0,
  });
}

/// Owns a GameState + Edition, applies banker actions, logs the ledger,
/// and persists through [save].
class GameController extends ChangeNotifier {
  GameState game;
  final Edition edition;
  final Future<void> Function(GameState) save;

  GameController({required this.game, required this.edition, required this.save});

  /// Display currency: the unit entered at game setup, or the edition's
  /// own symbol for older saves and games that kept the default.
  String get sym => game.currencySymbol ?? edition.currencySymbol;
  String money(int v) => fmtMoney(v, sym);

  PlayerState player(String id) => game.players.firstWhere((p) => p.id == id);
  String playerName(String id) => player(id).name;

  void _log(String type, String text, {int? amount, String? fromName, String? toName}) {
    game.ledger.add(TxEntry(
      id: newId('tx'),
      ts: DateTime.now().millisecondsSinceEpoch,
      type: type,
      text: text,
      amount: amount,
      fromName: fromName,
      toName: toName,
    ));
  }

  Future<void> _commit() async {
    game.updatedAt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await save(game);
  }

  // ---------- turns ----------
  /// Advances the turn, resolving the current player's landing first.
  /// The turn does NOT advance (advanced=false) when:
  ///  - the player is jailed and hasn't resolved their jail turn, or
  ///  - the player hasn't moved their token this turn (non-jailed), or
  ///  - the player is on an unowned purchasable property (buy/auction first).
  Future<NextTurnInfo> nextTurn(String locale) async {
    final p = game.currentPlayer;
    // Every turn must be played: the token has to move (jail has its own
    // rules — a failed doubles attempt counts as a resolved jail turn).
    if (!p.movedThisTurn) {
      if (p.jailed) {
        return NextTurnInfo(
            advanced: false, blockReason: 'jail', playerName: p.name);
      }
      return NextTurnInfo(
          advanced: false, blockReason: 'notMoved', playerName: p.name);
    }
    // Resolve the current player's landing BEFORE advancing the turn.
    final res = resolveLanding(game, edition, p);
    if (res.kind == LandingKind.buy && game.noBidAuctionSpaceN != p.position) {
      // Unowned purchasable space: the turn is BLOCKED until the banker
      // buys the property or auctions it. Turn stays on the same player.
      // Exception: an auction that closed with no bids on this very space
      // leaves the property unowned AND lets the turn advance.
      final space = edition.space(p.position);
      return NextTurnInfo(
        advanced: false,
        blockReason: 'unowned',
        playerName: p.name,
        spaceName: space.localizedName(locale),
        amount: res.amount,
      );
    }
    NextTurnInfo info = const NextTurnInfo();
    if (res.kind == LandingKind.rent &&
        res.ownerId != null &&
        res.ownerId != p.id) {
      // Opponent-owned space: auto-pay rent, then advance.
      final owner = player(res.ownerId!);
      final space = edition.space(p.position);
      final rent = res.amount;
      p.cash -= rent;
      owner.cash += rent;
      _log('rent',
          'Rent ${space.name}: ${p.name} → ${owner.name} ${money(rent)} (auto on next turn)',
          amount: rent, fromName: p.name, toName: owner.name);
      info = NextTurnInfo(
        rentPaid: true,
        playerName: p.name,
        ownerName: owner.name,
        spaceName: space.localizedName(locale),
        amount: rent,
      );
    }
    // Advance: reset per-turn state (consuming any no-bid auction flag).
    game.noBidAuctionSpaceN = 0;
    p.consecutiveDoubles = 0;
    game.currentPlayerIdx = (game.currentPlayerIdx + 1) % game.players.length;
    game.currentPlayer.movedThisTurn = false;
    await _commit();
    return info;
  }

  Future<void> setCurrentPlayer(int idx) async {
    game.currentPlayerIdx = idx;
    await _commit();
  }

  // ---------- money ----------
  Future<void> adjustMoney(String playerId, int delta, String note) async {
    final p = player(playerId);
    p.cash += delta;
    _log('adjust',
        '${p.name}: ${delta >= 0 ? '+' : ''}${money(delta)}${note.isNotEmpty ? ' — $note' : ''}',
        amount: delta, toName: p.name);
    await _commit();
  }

  // ---------- movement ----------
  /// Jailed players cannot be moved normally — jail turns are resolved only
  /// through [rollDice] (doubles attempt), [releaseFromJail] (pay/card).
  Future<void> setPosition(String playerId, int spaceN) async {
    final p = player(playerId);
    if (p.jailed) return;
    game.noBidAuctionSpaceN = 0;
    p.position = spaceN;
    p.hasMoved = true;
    p.movedThisTurn = true;
    _log('move', '${p.name} → ${edition.space(spaceN).name} (set by banker)', toName: p.name);
    await _commit();
  }

  /// Manual token move between spaces; banker chooses whether GO salary applies.
  /// Blocked while jailed.
  Future<void> manualMove(String playerId, int toSpaceN, {required bool goSalaryApplies}) async {
    final p = player(playerId);
    if (p.jailed) return;
    game.noBidAuctionSpaceN = 0;
    final firstMove = !p.hasMoved;
    p.position = toSpaceN;
    p.hasMoved = true;
    p.movedThisTurn = true;
    var note = 'moved by banker to ${edition.space(toSpaceN).name}';
    if (goSalaryApplies && !firstMove) {
      p.cash += game.goSalary;
      note += ' (+${money(game.goSalary)} GO)';
      _log('go', '${p.name}: GO salary ${money(game.goSalary)}', amount: game.goSalary, toName: p.name);
    } else if (firstMove) {
      note += ' (first move — no GO salary)';
    }
    _log('move', '${p.name} $note', toName: p.name);
    await _commit();
  }

  /// Shared dice-movement step (position, GO salary, flags).
  Future<void> _moveForDice(PlayerState p, int steps) async {
    game.noBidAuctionSpaceN = 0;
    final firstMove = !p.hasMoved;
    final r = moveSteps(p.position, steps);
    p.position = r.newPosition;
    p.hasMoved = true;
    p.movedThisTurn = true;
    _log('move', '${p.name} moves $steps → ${edition.space(p.position).name}', toName: p.name);
    if (r.passedGo && !firstMove) {
      p.cash += game.goSalary;
      _log('go', '${p.name}: GO salary ${money(game.goSalary)}', amount: game.goSalary, toName: p.name);
    }
    await _commit();
  }

  /// Dice move for a free player (blocked while jailed — use [rollDice]).
  Future<void> diceMove(String playerId, int steps) async {
    final p = player(playerId);
    if (p.jailed) return;
    await _moveForDice(p, steps);
  }

  /// Full dice-roll resolution entered by the banker.
  ///
  /// [wasDoubles] must be true only when the two dice showed the same value
  /// (the UI asks the banker whenever the entered total is even).
  /// Rules applied (RULE_DOUBLES, RULE_JAIL_EXIT):
  ///  - free player, doubles (1st/2nd in a row): move, then an EXTRA turn
  ///    (the turn does not advance; the player must move again);
  ///  - free player, 3rd consecutive doubles: straight to jail, turn ends
  ///    (the token is not moved for that roll);
  ///  - jailed player, doubles: released and moves with this roll, no extra
  ///    turn;
  ///  - jailed player, no doubles: stays in jail (up to 3 attempts); the 3rd
  ///    failed attempt auto-charges the $50 fine and moves with this roll.
  Future<DiceOutcome> rollDice(String playerId, int steps,
      {required bool wasDoubles}) async {
    final p = player(playerId);
    if (wasDoubles) {
      if (p.jailed) {
        p.jailed = false;
        p.jailAttempts = 0;
        p.consecutiveDoubles = 0;
        _log('jail', '${p.name} rolls doubles — released from jail', toName: p.name);
        await _moveForDice(p, steps);
        return const DiceOutcome(releasedFromJail: true);
      }
      p.consecutiveDoubles += 1;
      if (p.consecutiveDoubles >= 3) {
        // Third doubles in a row: directly to jail, turn ends, no move.
        p.consecutiveDoubles = 0;
        p.jailAttempts = 0;
        p.jailed = true;
        p.position = 11; // jail space
        p.movedThisTurn = true; // turn is over — Next may advance
        _log('jail', '${p.name} rolls 3rd consecutive doubles — sent to jail',
            toName: p.name);
        await _commit();
        return const DiceOutcome(sentToJail: true);
      }
      await _moveForDice(p, steps);
      p.movedThisTurn = false; // extra turn: the player must move again
      _log('dice', '${p.name} rolls doubles (${p.consecutiveDoubles} in a row) — extra turn',
          toName: p.name);
      await _commit();
      return const DiceOutcome(extraTurn: true);
    }
    // Not doubles.
    p.consecutiveDoubles = 0;
    if (p.jailed) {
      p.jailAttempts += 1;
      if (p.jailAttempts >= 3) {
        // Third failed attempt: must pay $50 and move with this roll.
        p.cash -= edition.jailFine;
        p.jailed = false;
        p.jailAttempts = 0;
        _log('jail',
            '${p.name} fails 3rd doubles attempt — pays ${money(edition.jailFine)} and moves $steps',
            amount: edition.jailFine, fromName: p.name);
        await _moveForDice(p, steps);
        return const DiceOutcome(releasedFromJail: true, forcedFine: true);
      }
      _log('jail',
          '${p.name} rolls no doubles (attempt ${p.jailAttempts}/3) — stays in jail',
          toName: p.name);
      p.movedThisTurn = true; // jail turn resolved without movement
      await _commit();
      return const DiceOutcome(stayedInJail: true);
    }
    await _moveForDice(p, steps);
    return const DiceOutcome();
  }

  // ---------- landing actions ----------
  Future<void> buyProperty(String playerId, int spaceN) async {
    final p = player(playerId);
    final s = edition.space(spaceN);
    game.noBidAuctionSpaceN = 0;
    p.cash -= s.price!;
    game.deeds[spaceN] = DeedState(spaceN: spaceN, ownerId: playerId);
    _log('purchase', '${p.name} buys ${s.name} for ${money(s.price!)}',
        amount: s.price!, toName: p.name);
    await _commit();
  }

  Future<void> auctionProperty(int spaceN, String winnerId, int bid) async {
    final w = player(winnerId);
    final s = edition.space(spaceN);
    game.noBidAuctionSpaceN = 0;
    w.cash -= bid;
    game.deeds[spaceN] = DeedState(spaceN: spaceN, ownerId: winnerId);
    _log('auction', '${w.name} wins auction: ${s.name} for ${money(bid)}',
        amount: bid, toName: w.name);
    await _commit();
  }

  /// Auction closed with no bids: nobody pays, nobody owns the property,
  /// and the turn may advance past this unowned space (see [nextTurn]).
  Future<void> closeAuctionNoBids(int spaceN) async {
    final s = edition.space(spaceN);
    game.noBidAuctionSpaceN = spaceN;
    _log('auction', 'Auction: ${s.name} — no bids, remains unowned');
    await _commit();
  }

  Future<void> payRent(String payerId, int spaceN,
      {bool railroadDoubled = false, int utilityDice = 0}) async {
    final payer = player(payerId);
    final s = edition.space(spaceN);
    final deed = game.deeds[spaceN]!;
    final owner = player(deed.ownerId);
    int rent;
    if (s.type == 'street') {
      rent = streetRent(game, edition, s, deed);
    } else if (s.type == 'railroad') {
      rent = railroadRent(game, edition, deed.ownerId, doubled: railroadDoubled);
    } else {
      rent = utilityRent(utilityDice, playerUtilityCount(game, edition, deed.ownerId));
    }
    payer.cash -= rent;
    owner.cash += rent;
    _log('rent',
        'Rent ${s.name}: ${payer.name} → ${owner.name} ${money(rent)}${railroadDoubled ? ' (doubled)' : ''}',
        amount: rent, fromName: payer.name, toName: owner.name);
    await _commit();
  }

  Future<void> payTax(String playerId, int spaceN) async {
    final p = player(playerId);
    final s = edition.space(spaceN);
    p.cash -= s.amount!;
    _log('tax', '${p.name} pays ${s.name} ${money(s.amount!)}', amount: s.amount!, fromName: p.name);
    await _commit();
  }

  Future<void> receiveGo(String playerId) async {
    final p = player(playerId);
    p.cash += game.goSalary;
    _log('go', '${p.name}: GO salary ${money(game.goSalary)}', amount: game.goSalary, toName: p.name);
    await _commit();
  }

  Future<void> drawCard(String playerId, String cardText) async {
    final p = player(playerId);
    _log('card', '${p.name} draws card: $cardText', toName: p.name);
    await _commit();
  }

  // ---------- jail ----------
  Future<void> sendToJail(String playerId) async {
    final p = player(playerId);
    game.noBidAuctionSpaceN = 0;
    p.jailed = true;
    p.position = 11; // jail space
    p.jailAttempts = 0;
    p.consecutiveDoubles = 0;
    _log('jail', '${p.name} sent to jail', toName: p.name);
    await _commit();
  }

  /// method: 'pay' ($50), 'doubles', 'card'
  Future<void> releaseFromJail(String playerId, String method) async {
    final p = player(playerId);
    if (method == 'pay') {
      p.cash -= edition.jailFine;
      _log('jail', '${p.name} pays ${money(edition.jailFine)} to leave jail',
          amount: edition.jailFine, fromName: p.name);
    } else if (method == 'card') {
      p.jailCards -= 1;
      _log('jail', '${p.name} uses a get-out-of-jail card', toName: p.name);
    } else {
      _log('jail', '${p.name} rolls doubles — released from jail', toName: p.name);
    }
    p.jailed = false;
    p.jailAttempts = 0;
    p.consecutiveDoubles = 0;
    // Note: movedThisTurn stays false — the freed player must still move.
    await _commit();
  }

  Future<void> giveJailCard(String playerId) async {
    final p = player(playerId);
    p.jailCards += 1;
    _log('card', '${p.name} receives a get-out-of-jail card', toName: p.name);
    await _commit();
  }

  // ---------- buildings ----------
  /// Builds one house (or a hotel at 4 houses), enforcing the official
  /// building rules via [canBuild]. Silently ignored when not allowed —
  /// the UI explains the reason through [buildBlockReason].
  Future<void> buildHouse(String playerId, int spaceN) async {
    if (!canBuild(game, edition, spaceN)) return;
    final p = player(playerId);
    final s = edition.space(spaceN);
    final deed = game.deeds[spaceN]!;
    if (deed.ownerId != playerId) return;
    final cost = s.houseCost!;
    p.cash -= cost;
    deed.houses += 1;
    final what = deed.houses >= 5 ? 'hotel' : 'house ${deed.houses}';
    _log('build', '${p.name} builds $what on ${s.name} (${money(cost)})',
        amount: cost, toName: p.name);
    await _commit();
  }

  /// Sells one building back to the bank at half cost, enforcing even
  /// selling (RULE_SELL_BUILDINGS_HALF_COST) via [canSellBuilding].
  Future<void> sellBuilding(String playerId, int spaceN) async {
    if (!canSellBuilding(game, edition, spaceN)) return;
    final p = player(playerId);
    final s = edition.space(spaceN);
    final deed = game.deeds[spaceN]!;
    if (deed.ownerId != playerId) return;
    final back = sellBuildingValue(s.houseCost!);
    p.cash += back;
    deed.houses -= 1;
    _log('sell-building', '${p.name} sells building on ${s.name} (+${money(back)})',
        amount: back, toName: p.name);
    await _commit();
  }

  Future<void> mortgage(String playerId, int spaceN) async {
    final p = player(playerId);
    final s = edition.space(spaceN);
    final deed = game.deeds[spaceN]!;
    final val = mortgageValueFor(s);
    p.cash += val;
    deed.mortgaged = true;
    _log('mortgage', '${p.name} mortgages ${s.name} (+${money(val)})',
        amount: val, toName: p.name);
    await _commit();
  }

  Future<void> unmortgage(String playerId, int spaceN) async {
    final p = player(playerId);
    final s = edition.space(spaceN);
    final deed = game.deeds[spaceN]!;
    final cost = unmortgageCostFor(s);
    p.cash -= cost;
    deed.mortgaged = false;
    _log('unmortgage', '${p.name} unmortgages ${s.name} (${money(cost)})',
        amount: cost, toName: p.name);
    await _commit();
  }

  // ---------- trade ----------
  Future<void> trade({
    required String fromId,
    required String toId,
    int cashFrom = 0,
    int cashTo = 0,
    List<int> spacesFrom = const [],
    List<int> spacesTo = const [],
    int jailCardsFrom = 0,
    int jailCardsTo = 0,
  }) async {
    final a = player(fromId);
    final b = player(toId);
    a.cash = a.cash - cashFrom + cashTo;
    b.cash = b.cash - cashTo + cashFrom;
    a.jailCards = a.jailCards - jailCardsFrom + jailCardsTo;
    b.jailCards = b.jailCards - jailCardsTo + jailCardsFrom;
    for (final n in spacesFrom) {
      game.deeds[n]!.ownerId = toId;
    }
    for (final n in spacesTo) {
      game.deeds[n]!.ownerId = fromId;
    }
    final ed = edition;
    String nm(int n) => ed.space(n).name;
    final parts = <String>[
      if (cashFrom > 0) money(cashFrom),
      ...spacesFrom.map(nm),
      if (jailCardsFrom > 0) '$jailCardsFrom jail card(s)',
      '→',
      if (cashTo > 0) money(cashTo),
      ...spacesTo.map(nm),
      if (jailCardsTo > 0) '$jailCardsTo jail card(s)',
    ];
    _log('trade', 'Trade ${a.name} ⇄ ${b.name}: ${parts.join(' ')}',
        fromName: a.name, toName: b.name);
    await _commit();
  }

  // ---------- game ----------
  Future<void> endGame() async {
    game.status = 'ended';
    _log('game', 'Game ended');
    await _commit();
  }

  Future<void> setPaused(bool paused) async {
    game.status = paused ? 'paused' : 'active';
    await _commit();
  }
}
