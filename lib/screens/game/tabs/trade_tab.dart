import 'package:flutter/material.dart';
import '../../../game/controller.dart';
import '../../../main.dart';
import '../../../models/game.dart';
import '../../../theme/themes.dart';

/// Trade tab: build a trade between two players (cash + properties + jail cards).
class TradeTab extends StatefulWidget {
  final GameController ctl;
  const TradeTab({super.key, required this.ctl});
  @override
  State<TradeTab> createState() => _TradeTabState();
}

class _TradeTabState extends State<TradeTab> {
  String? _fromId;
  String? _toId;
  final _cashFromCtrl = TextEditingController();
  final _cashToCtrl = TextEditingController();
  final Set<int> _spacesFrom = {};
  final Set<int> _spacesTo = {};
  int _cardsFrom = 0;
  int _cardsTo = 0;

  @override
  void dispose() {
    _cashFromCtrl.dispose();
    _cashToCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final ctl = widget.ctl;
    final players = ctl.game.players;
    _fromId ??= players.first.id;
    _toId ??= players.length > 1 ? players[1].id : players.first.id;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(child: _playerDrop(prefs, players, _fromId, (v) => setState(() {
              _fromId = v;
              _spacesFrom.clear();
            }), prefs.t('play.from'))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.swap_horiz, color: pal.gold),
            ),
            Expanded(child: _playerDrop(prefs, players, _toId, (v) => setState(() {
              _toId = v;
              _spacesTo.clear();
            }), prefs.t('play.tradeWith'))),
          ],
        ),
        const SizedBox(height: 12),
        _SideCard(
          title: _name(_fromId),
          cashCtrl: _cashFromCtrl,
          spaces: _spacesFrom,
          cards: _cardsFrom,
          onCards: (d) => setState(() => _cardsFrom = (_cardsFrom + d).clamp(0, 9)),
          onSpacesChanged: () => setState(() {}),
          ctl: ctl,
          playerId: _fromId!,
          prefs: prefs,
        ),
        const SizedBox(height: 12),
        _SideCard(
          title: _name(_toId),
          cashCtrl: _cashToCtrl,
          spaces: _spacesTo,
          cards: _cardsTo,
          onCards: (d) => setState(() => _cardsTo = (_cardsTo + d).clamp(0, 9)),
          onSpacesChanged: () => setState(() {}),
          ctl: ctl,
          playerId: _toId!,
          prefs: prefs,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _fromId == _toId
              ? null
              : () async {
                  await ctl.trade(
                    fromId: _fromId!,
                    toId: _toId!,
                    cashFrom: int.tryParse(_cashFromCtrl.text) ?? 0,
                    cashTo: int.tryParse(_cashToCtrl.text) ?? 0,
                    spacesFrom: _spacesFrom.toList(),
                    spacesTo: _spacesTo.toList(),
                    jailCardsFrom: _cardsFrom,
                    jailCardsTo: _cardsTo,
                  );
                  if (mounted) {
                    setState(() {
                      _cashFromCtrl.clear();
                      _cashToCtrl.clear();
                      _spacesFrom.clear();
                      _spacesTo.clear();
                      _cardsFrom = 0;
                      _cardsTo = 0;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(prefs.t('play.executeTrade'))),
                    );
                  }
                },
          icon: const Icon(Icons.check),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(prefs.t('play.executeTrade')),
          ),
        ),
      ],
    );
  }

  String _name(String? id) {
    try {
      return widget.ctl.playerName(id!);
    } catch (_) {
      return '';
    }
  }

  Widget _playerDrop(prefs, List<PlayerState> players, String? value,
      ValueChanged<String?> onChanged, String label) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final p in players)
          DropdownMenuItem(value: p.id, child: Text(p.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _SideCard extends StatelessWidget {
  final String title;
  final TextEditingController cashCtrl;
  final Set<int> spaces;
  final int cards;
  final ValueChanged<int> onCards;
  final VoidCallback onSpacesChanged;
  final GameController ctl;
  final String playerId;
  final dynamic prefs;
  const _SideCard({
    required this.title,
    required this.cashCtrl,
    required this.spaces,
    required this.cards,
    required this.onCards,
    required this.onSpacesChanged,
    required this.ctl,
    required this.playerId,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    final deeds = ctl.game.deeds.values
        .where((d) => d.ownerId == playerId)
        .toList()
      ..sort((a, b) => a.spaceN.compareTo(b.spaceN));
    return Card(
      color: pal.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: prefs.t('play.cashGive'),
                prefixText: '${ctl.sym} ',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(prefs.t('play.propsGive'),
                style: TextStyle(color: pal.muted, fontSize: 12)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in deeds)
                  FilterChip(
                    label: Text(
                      '#${d.spaceN} ${ctl.edition.space(d.spaceN).localizedName(prefs.locale)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: spaces.contains(d.spaceN),
                    onSelected: (v) {
                      if (v) {
                        spaces.add(d.spaceN);
                      } else {
                        spaces.remove(d.spaceN);
                      }
                      onSpacesChanged();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(prefs.t('play.cardJailCard'),
                    style: TextStyle(color: pal.muted, fontSize: 12)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => onCards(-1),
                ),
                Text('$cards', style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => onCards(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
