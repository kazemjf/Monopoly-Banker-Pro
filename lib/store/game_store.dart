import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/game.dart';

class GameMeta {
  final String id;
  final String name;
  final String editionId;
  final String status;
  final int createdAt;
  final int updatedAt;
  final int playerCount;
  GameMeta({required this.id, required this.name, required this.editionId,
    required this.status, required this.createdAt, required this.updatedAt,
    required this.playerCount});
  bool get isFinished => status == 'ended';
}

/// Games persisted as one JSON file per game in the app documents directory.
class GameStore extends ChangeNotifier {
  Directory? _dir;
  final List<GameMeta> _metas = [];
  List<GameMeta> get metas => List.unmodifiable(_metas);

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory('${docs.path}/games');
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
    await refresh();
  }

  Future<void> refresh() async {
    _metas.clear();
    if (_dir == null) return;
    await for (final e in _dir!.list()) {
      if (e is File && e.path.endsWith('.json')) {
        try {
          final j = json.decode(await e.readAsString()) as Map<String, dynamic>;
          _metas.add(GameMeta(
            id: j['id'] as String,
            name: j['name'] as String? ?? 'Game',
            editionId: j['editionId'] as String? ?? 'london',
            status: j['status'] as String? ?? 'active',
            createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
            updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
            playerCount: (j['players'] as List? ?? []).length,
          ));
        } catch (_) {/* skip corrupt files */}
      }
    }
    _metas.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  Future<void> saveGame(GameState game) async {
    final f = File('${_dir!.path}/${game.id}.json');
    await f.writeAsString(json.encode(game.toJson()));
    await refresh();
  }

  Future<GameState?> loadGame(String id) async {
    final f = File('${_dir!.path}/$id.json');
    if (!await f.exists()) return null;
    try {
      return GameState.fromJson(json.decode(await f.readAsString()));
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteGame(String id) async {
    final f = File('${_dir!.path}/$id.json');
    if (await f.exists()) await f.delete();
    await refresh();
  }

  Future<GameState> createGame({
    required String name,
    required String editionId,
    required int startCash,
    required int goSalary,
    required List<String> playerNames,
    required int startingPlayerIdx,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final players = <PlayerState>[];
    for (var i = 0; i < playerNames.length; i++) {
      players.add(PlayerState(
        id: newId('p'),
        name: playerNames[i].trim().isEmpty ? 'Player ${i + 1}' : playerNames[i].trim(),
        cash: startCash,
      ));
    }
    final game = GameState(
      id: newId('g'),
      name: name.trim().isEmpty ? 'Game' : name.trim(),
      editionId: editionId,
      createdAt: now,
      updatedAt: now,
      startCash: startCash,
      goSalary: goSalary,
      currentPlayerIdx: startingPlayerIdx.clamp(0, players.length - 1),
      players: players,
    );
    game.ledger.add(TxEntry(
      id: newId('tx'), ts: now, type: 'game',
      text: 'Game created — ${players.length} players, ${startCash} starting cash',
    ));
    await saveGame(game);
    return game;
  }
}
