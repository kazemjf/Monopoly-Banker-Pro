import 'dart:math';

String newId(String prefix) =>
    '$prefix${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(1 << 20)}';

/// Game status: active (setup/active/paused all count as in-progress), ended.
class PlayerState {
  String id;
  String name;
  int cash;
  int position; // 1..40
  bool jailed;
  int jailCards;
  bool hasMoved; // first-move tracking: no GO salary on the very first move
  bool bankrupt;
  bool movedThisTurn; // set by any token move; reset when the turn advances
  int jailAttempts; // failed doubles attempts while jailed (0..2, 3rd forces $50)
  int consecutiveDoubles; // doubles streak within the current turn sequence

  PlayerState({
    required this.id, required this.name, required this.cash,
    this.position = 1, this.jailed = false, this.jailCards = 0,
    this.hasMoved = false, this.bankrupt = false,
    this.movedThisTurn = false, this.jailAttempts = 0,
    this.consecutiveDoubles = 0,
  });

  factory PlayerState.fromJson(Map<String, dynamic> j) => PlayerState(
        id: j['id'] as String,
        name: j['name'] as String,
        cash: (j['cash'] as num).toInt(),
        position: (j['position'] as num?)?.toInt() ?? 1,
        jailed: j['jailed'] == true,
        jailCards: (j['jailCards'] as num?)?.toInt() ?? 0,
        hasMoved: j['hasMoved'] == true,
        bankrupt: j['bankrupt'] == true,
        movedThisTurn: j['movedThisTurn'] == true,
        jailAttempts: (j['jailAttempts'] as num?)?.toInt() ?? 0,
        consecutiveDoubles: (j['consecutiveDoubles'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'cash': cash, 'position': position,
        'jailed': jailed, 'jailCards': jailCards, 'hasMoved': hasMoved,
        'bankrupt': bankrupt, 'movedThisTurn': movedThisTurn,
        'jailAttempts': jailAttempts,
        'consecutiveDoubles': consecutiveDoubles,
      };
}

class DeedState {
  int spaceN;
  String ownerId;
  int houses; // 0..4 houses, 5 = hotel
  bool mortgaged;

  DeedState({required this.spaceN, required this.ownerId, this.houses = 0, this.mortgaged = false});

  factory DeedState.fromJson(Map<String, dynamic> j) => DeedState(
        spaceN: (j['spaceN'] as num).toInt(),
        ownerId: j['ownerId'] as String,
        houses: (j['houses'] as num?)?.toInt() ?? 0,
        mortgaged: j['mortgaged'] == true,
      );

  Map<String, dynamic> toJson() =>
      {'spaceN': spaceN, 'ownerId': ownerId, 'houses': houses, 'mortgaged': mortgaged};

  bool get hasHotel => houses >= 5;
  int get houseCount => houses >= 5 ? 0 : houses;
}

class TxEntry {
  String id;
  int ts;
  String type; // purchase, rent, mortgage, unmortgage, build, sell-building, auction, trade, tax, fine, custom, jail, card, go, transfer, adjust
  String text;
  int? amount;
  String? fromName;
  String? toName;

  TxEntry({required this.id, required this.ts, required this.type, required this.text,
    this.amount, this.fromName, this.toName});

  factory TxEntry.fromJson(Map<String, dynamic> j) => TxEntry(
        id: j['id'] as String, ts: (j['ts'] as num).toInt(),
        type: j['type'] as String, text: j['text'] as String,
        amount: (j['amount'] as num?)?.toInt(),
        fromName: j['fromName'] as String?, toName: j['toName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'ts': ts, 'type': type, 'text': text,
        'amount': amount, 'fromName': fromName, 'toName': toName,
      };
}

class GameState {
  String id;
  String name;
  String editionId;
  String status; // active | paused | ended
  int createdAt;
  int updatedAt;
  int startCash;
  int goSalary;
  int currentPlayerIdx;
  List<PlayerState> players;
  Map<int, DeedState> deeds; // spaceN -> deed
  List<TxEntry> ledger;

  GameState({
    required this.id, required this.name, required this.editionId,
    this.status = 'active', required this.createdAt, required this.updatedAt,
    required this.startCash, required this.goSalary, this.currentPlayerIdx = 0,
    required this.players, Map<int, DeedState>? deeds, List<TxEntry>? ledger,
  })  : deeds = deeds ?? {},
        ledger = ledger ?? [];

  bool get isFinished => status == 'ended';
  bool get isActive => !isFinished;

  PlayerState get currentPlayer => players[currentPlayerIdx];

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
        id: j['id'] as String,
        name: j['name'] as String,
        editionId: j['editionId'] as String,
        status: j['status'] as String? ?? 'active',
        createdAt: (j['createdAt'] as num).toInt(),
        updatedAt: (j['updatedAt'] as num).toInt(),
        startCash: (j['startCash'] as num).toInt(),
        goSalary: (j['goSalary'] as num).toInt(),
        currentPlayerIdx: (j['currentPlayerIdx'] as num?)?.toInt() ?? 0,
        players: (j['players'] as List)
            .map((e) => PlayerState.fromJson(e as Map<String, dynamic>))
            .toList(),
        deeds: {
          for (final raw in (j['deeds'] as List? ?? []))
            ((raw as Map<String, dynamic>)['spaceN'] as num).toInt():
                DeedState.fromJson(raw)
        },
        ledger: (j['ledger'] as List? ?? [])
            .map((e) => TxEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'editionId': editionId, 'status': status,
        'createdAt': createdAt, 'updatedAt': updatedAt,
        'startCash': startCash, 'goSalary': goSalary,
        'currentPlayerIdx': currentPlayerIdx,
        'players': players.map((p) => p.toJson()).toList(),
        'deeds': deeds.values.map((d) => d.toJson()).toList(),
        'ledger': ledger.map((t) => t.toJson()).toList(),
      };

  /// Net worth = cash + property prices + buildings value.
  int netWorth(PlayerState p, Map<int, BoardSpaceLite> priceOf) {
    var total = p.cash;
    for (final d in deeds.values.where((d) => d.ownerId == p.id)) {
      final info = priceOf[d.spaceN];
      if (info == null) continue;
      total += info.price;
      total += d.houses * info.houseCost;
    }
    return total;
  }
}

/// Minimal price info for net-worth calc (avoids importing editions in model).
class BoardSpaceLite {
  final int price;
  final int houseCost;
  BoardSpaceLite(this.price, this.houseCost);
}
