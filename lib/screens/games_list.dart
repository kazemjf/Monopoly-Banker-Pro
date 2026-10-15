import 'package:flutter/material.dart';
import '../data/editions.dart';
import '../main.dart';
import '../store/game_store.dart';
import '../theme/themes.dart';
import 'game/game_screen.dart';

/// Game list with all / active / finished filters.
class GamesListScreen extends StatefulWidget {
  const GamesListScreen({super.key});
  @override
  State<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends State<GamesListScreen> {
  int _filter = 0; // 0 all, 1 active, 2 finished

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final prefs = scope.prefs;
    final games = scope.games;
    final pal = paletteOf(context);
    return ListenableBuilder(
      listenable: games,
      builder: (ctx, _) {
        var metas = games.metas;
        if (_filter == 1) metas = metas.where((m) => !m.isFinished).toList();
        if (_filter == 2) metas = metas.where((m) => m.isFinished).toList();
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(prefs.t('games.title')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prefs.t('app.tagline'),
                        style: TextStyle(color: pal.muted, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(prefs.t('app.credit'),
                        style: TextStyle(color: pal.gold, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _chip(0, prefs.t('games.filterAll'), prefs, pal),
                        const SizedBox(width: 8),
                        _chip(1, prefs.t('games.filterActive'), prefs, pal),
                        const SizedBox(width: 8),
                        _chip(2, prefs.t('games.filterFinished'), prefs, pal),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (metas.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(prefs.t('games.empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pal.muted)),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _gameRow(metas[i], prefs, games, pal),
                  childCount: metas.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }

  Widget _chip(int idx, String label, prefs, AppPalette pal) {
    final selected = _filter == idx;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: selected ? pal.goldInk : pal.fg,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
      selected: _filter == idx,
      selectedColor: pal.gold,
      backgroundColor: pal.surface,
      side: BorderSide(color: selected ? pal.gold : pal.line),
      onSelected: (_) => setState(() => _filter = idx),
    );
  }

  Widget _gameRow(GameMeta m, prefs, GameStore games, AppPalette pal) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(m.updatedAt).toLocal().toString().substring(0, 16);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: pal.surface,
      child: ListTile(
        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${prefs.t('games.players', {'count': '${m.playerCount}'})} • $date',
          style: TextStyle(color: pal.muted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: m.isFinished ? pal.surface2 : pal.felt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                m.isFinished
                    ? prefs.t('games.filterFinished')
                    : prefs.t('games.filterActive'),
                style: TextStyle(
                    fontSize: 11,
                    color: m.isFinished ? pal.muted : pal.fg,
                    fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: pal.danger),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: prefs.t('games.deleteTitle'),
                  message: m.name,
                  confirmLabel: prefs.t('games.delete'),
                  danger: true,
                );
                if (ok) await games.deleteGame(m.id);
              },
            ),
          ],
        ),
        onTap: () => _openGame(m.id),
      ),
    );
  }

  Future<void> _openGame(String id) async {
    final game = await AppScope.of(context).games.loadGame(id);
    if (game == null || !mounted) return;
    final edition = await getEdition(game.editionId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(game: game, edition: edition)),
    );
    // refresh list when returning (ListenableBuilder rebuilds automatically)
    if (mounted) AppScope.of(context).games.refresh();
  }
}
