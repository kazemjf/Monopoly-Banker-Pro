import '../data/editions.dart';
import '../models/game.dart';

/// Pure Monopoly rules engine. All functions are deterministic and testable.

/// Owner of the complete color group, or null.
String? fullColorOwner(GameState g, Edition e, String color) {
  final spaces = e.spacesOfColor(color);
  if (spaces.isEmpty) return null;
  String? owner;
  for (final s in spaces) {
    final d = g.deeds[s.n];
    if (d == null) return null;
    if (owner == null) {
      owner = d.ownerId;
    } else if (owner != d.ownerId) {
      return null;
    }
  }
  return owner;
}

/// Street rent for [deed] (deed.houses: 0..4, 5 = hotel).
int streetRent(GameState g, Edition e, BoardSpace space, DeedState deed) {
  final table = space.rent!;
  if (deed.houses > 0) {
    return table[deed.houses >= 5 ? 5 : deed.houses];
  }
  final owner = fullColorOwner(g, e, space.color!);
  if (owner != null && owner == deed.ownerId) return table[0] * 2;
  return table[0];
}

int railroadRent(GameState g, Edition e, String ownerId, {bool doubled = false}) {
  final owned = e.spaces
      .where((s) => s.type == 'railroad' && g.deeds[s.n]?.ownerId == ownerId)
      .length;
  if (owned == 0) return 0;
  final table = e.spaces.firstWhere((s) => s.type == 'railroad').rentByCount!;
  var rent = table[owned - 1];
  if (doubled) rent *= 2;
  return rent;
}

int utilityRent(int diceTotal, int ownedCount) =>
    diceTotal * (ownedCount >= 2 ? 10 : 4);

int unmortgageCost(int price) => (price * 0.55).ceil();
int mortgageValue(int price) => price ~/ 2;
int sellBuildingValue(int houseCost) => houseCost ~/ 2;

/// Why building on [spaceN] is currently not allowed (null = allowed).
/// Rules: RULE_COLOR_GROUP_OWNERSHIP, RULE_BUILD_HOUSES, RULE_BUILD_EVENLY,
/// RULE_BUILD_NO_MORTGAGED_GROUP, RULE_HOTEL_REQUIREMENT.
String? buildBlockReason(GameState g, Edition e, int spaceN) {
  final space = e.space(spaceN);
  if (space.type != 'street') return 'notStreet';
  final deed = g.deeds[spaceN];
  if (deed == null) return 'notOwned';
  if (deed.mortgaged) return 'mortgaged';
  if (deed.houses >= 5) return 'maxed';
  if (fullColorOwner(g, e, space.color!) != deed.ownerId) return 'noFullGroup';
  // even building: no sibling may be more than (this+1) after build
  for (final s in e.spacesOfColor(space.color!)) {
    final d = g.deeds[s.n];
    if (d == null || d.mortgaged) return 'groupMortgaged';
    if (d.houses > deed.houses + 1) return 'uneven';
  }
  return null;
}

/// Even-building rule: may build on [spaceN] if the player owns the full
/// color group, the property is not mortgaged, no property in the group has
/// more buildings than this one would have after building, and < 5 levels.
bool canBuild(GameState g, Edition e, int spaceN) =>
    buildBlockReason(g, e, spaceN) == null;

/// Even-selling rule (RULE_SELL_BUILDINGS_HALF_COST): may sell a building
/// from [spaceN] only when no sibling street has MORE houses — i.e. sell
/// from the most-developed street first, keeping the group even.
bool canSellBuilding(GameState g, Edition e, int spaceN) {
  final space = e.space(spaceN);
  if (space.type != 'street') return false;
  final deed = g.deeds[spaceN];
  if (deed == null || deed.houses <= 0) return false;
  for (final s in e.spacesOfColor(space.color!)) {
    if (s.n == spaceN) continue;
    final d = g.deeds[s.n];
    if (d != null && d.houses > deed.houses) return false;
  }
  return true;
}

/// Move result for token movement.
class MoveResult {
  final int newPosition;
  final bool passedGo;
  MoveResult(this.newPosition, this.passedGo);
}

/// Move [steps] forward from [from] (1..40). Returns new position + whether GO was passed.
MoveResult moveSteps(int from, int steps) {
  final total = from - 1 + steps;
  return MoveResult((total % 40) + 1, total >= 40);
}

/// Number of houses the bank still allows etc. — net worth helpers.
int playerPropertyCount(GameState g, String playerId) =>
    g.deeds.values.where((d) => d.ownerId == playerId).length;

int playerRailroadCount(GameState g, Edition e, String playerId) => e.spaces
    .where((s) => s.type == 'railroad' && g.deeds[s.n]?.ownerId == playerId)
    .length;

int playerUtilityCount(GameState g, Edition e, String playerId) => e.spaces
    .where((s) => s.type == 'utility' && g.deeds[s.n]?.ownerId == playerId)
    .length;

/// Landing resolution: what the rules say must happen when [player] is on [space].
enum LandingKind {
  buy, // unowned purchasable
  rent, // owned by someone else
  payBank, // tax
  receive, // GO salary
  goToJail,
  jail, // just visiting
  card, // chance / community chest (manual)
  freeParking,
  none,
}

class LandingResolution {
  final LandingKind kind;
  final int amount; // price / rent / tax / salary
  final String? ownerId;
  final String? ownerName;
  final String note;
  LandingResolution({
    required this.kind, this.amount = 0, this.ownerId, this.ownerName, this.note = '',
  });
}

LandingResolution resolveLanding(
  GameState g,
  Edition e,
  PlayerState player, {
  bool railroadDoubled = false,
  int utilityDice = 0,
}) {
  final space = e.space(player.position);
  switch (space.type) {
    case 'go':
      return LandingResolution(kind: LandingKind.receive, amount: g.goSalary);
    case 'street':
    case 'railroad':
    case 'utility':
      final deed = g.deeds[space.n];
      if (deed == null) {
        return LandingResolution(kind: LandingKind.buy, amount: space.price!);
      }
      if (deed.ownerId == player.id || deed.mortgaged) {
        return LandingResolution(kind: LandingKind.none, note: 'no-rent');
      }
      final ownerName =
          g.players.firstWhere((p) => p.id == deed.ownerId).name;
      int rent;
      if (space.type == 'street') {
        rent = streetRent(g, e, space, deed);
      } else if (space.type == 'railroad') {
        rent = railroadRent(g, e, deed.ownerId, doubled: railroadDoubled);
      } else {
        rent = utilityRent(utilityDice, playerUtilityCount(g, e, deed.ownerId));
      }
      return LandingResolution(
          kind: LandingKind.rent, amount: rent, ownerId: deed.ownerId, ownerName: ownerName);
    case 'tax':
      return LandingResolution(kind: LandingKind.payBank, amount: space.amount!);
    case 'go_to_jail':
      return LandingResolution(kind: LandingKind.goToJail);
    case 'jail':
      return LandingResolution(kind: LandingKind.jail);
    case 'chance':
    case 'community_chest':
      return LandingResolution(kind: LandingKind.card);
    case 'free_parking':
      return LandingResolution(kind: LandingKind.freeParking);
    default:
      return LandingResolution(kind: LandingKind.none);
  }
}
