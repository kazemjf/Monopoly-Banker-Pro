import 'package:flutter/material.dart';
import '../../../data/editions.dart';
import '../../../game/controller.dart';
import '../../../game/engine.dart';
import '../../../main.dart';
import '../../../models/game.dart';
import '../../../theme/themes.dart';

/// Board tab: 40-space grid; tap a space for the inspector + manual moves.
class BoardTab extends StatelessWidget {
  final GameController ctl;
  const BoardTab({super.key, required this.ctl});

  String _typeKey(BoardSpace s) {
    switch (s.type) {
      case 'community_chest':
        return 'board.type.community';
      case 'free_parking':
        return 'board.type.free';
      default:
        return 'board.type.${s.type}';
    }
  }

  Color _typeColor(BoardSpace s, AppPalette pal) {
    switch (s.type) {
      case 'street':
        return _colorGroup(s.color!, pal);
      case 'railroad':
        return pal.muted;
      case 'utility':
        return pal.ok;
      case 'tax':
        return pal.danger;
      case 'chance':
      case 'community_chest':
        return pal.gold;
      case 'go':
        return pal.felt;
      case 'go_to_jail':
        return pal.danger;
      default:
        return pal.surface2;
    }
  }

  Color _colorGroup(String color, AppPalette pal) {
    switch (color) {
      case 'brown':
        return const Color(0xFF8B5A2B);
      case 'lightBlue':
        return const Color(0xFF7EC8E3);
      case 'pink':
        return const Color(0xFFE08BB8);
      case 'orange':
        return const Color(0xFFF0A35E);
      case 'red':
        return const Color(0xFFE05A5A);
      case 'yellow':
        return const Color(0xFFE8C547);
      case 'green':
        return const Color(0xFF3FA34D);
      case 'darkBlue':
        return const Color(0xFF3B5BFD);
      default:
        return pal.surface2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.92,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: 40,
      itemBuilder: (ctx, i) {
        final s = ctl.edition.space(i + 1);
        final deed = ctl.game.deeds[s.n];
        final playersHere = ctl.game.players
            .where((p) => p.position == s.n)
            .map((p) => p.name.isEmpty ? '?' : p.name[0].toUpperCase())
            .toList();
        final c = _typeColor(s, pal);
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _inspect(context, s),
          child: Container(
            decoration: BoxDecoration(
              color: pal.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pal.line),
            ),
            child: Column(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(9)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${s.n}',
                            style: TextStyle(
                                fontSize: 10,
                                color: pal.muted,
                                fontWeight: FontWeight.w700)),
                        Flexible(
                          child: Text(
                            s.localizedName(prefs.locale),
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (playersHere.isNotEmpty)
                          Wrap(
                            spacing: 2,
                            children: [
                              for (final t in playersHere.take(4))
                                Container(
                                  width: 14,
                                  height: 14,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: pal.gold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(t,
                                      style: TextStyle(
                                          fontSize: 8,
                                          color: pal.goldInk,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        if (deed != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (deed.mortgaged)
                                const Text('M', style: TextStyle(fontSize: 9)),
                              if (deed.houses > 0)
                                Text(
                                    deed.houses >= 5
                                        ? '🏨'
                                        : '🏠' * deed.houses,
                                    style: const TextStyle(fontSize: 8)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _inspect(BuildContext context, BoardSpace s) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final deed = ctl.game.deeds[s.n];
    final ownerName =
        deed == null ? null : ctl.playerName(deed.ownerId);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      width: 14,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _typeColor(s, pal),
                        borderRadius: BorderRadius.circular(4),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${s.n} ${s.localizedName(prefs.locale)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17)),
                        Text(prefs.t(_typeKey(s)),
                            style:
                                TextStyle(color: pal.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (s.isProperty) ...[
                _kv(prefs.t('play.price'), ctl.money(s.price!), pal),
                _kv(
                    prefs.t('play.owner'),
                    deed == null
                        ? prefs.t('play.unowned')
                        : ownerName!,
                    pal),
                if (deed != null) ...[
                  if (s.type == 'street')
                    _kv(
                        prefs.t('play.rent'),
                        ctl.money(streetRent(
                            ctl.game, ctl.edition, s, deed)),
                        pal),
                  _kv(
                      prefs.t('play.mortgaged'),
                      deed.mortgaged ? '✓' : '—',
                      pal),
                  if (deed.houses > 0)
                    _kv(
                        prefs.t('play.houses'),
                        deed.houses >= 5
                            ? prefs.t('play.hotel')
                            : '${deed.houses}',
                        pal),
                ],
              ],
              if (s.type == 'tax')
                _kv(prefs.t('play.payBank'), ctl.money(s.amount!), pal),
              const SizedBox(height: 16),
              _moveControls(context, prefs, pal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, AppPalette pal) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: TextStyle(color: pal.muted, fontSize: 13)),
            Text(v,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  /// Manual token move: pick player + destination + GO-salary choice.
  Widget _moveControls(BuildContext context, prefs, AppPalette pal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(prefs.t('play.movePlayer'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in ctl.game.players)
              _MoveChip(
                label: p.name,
                onTap: () => _pickDestination(context, p),
              ),
          ],
        ),
      ],
    );
  }

  void _pickDestination(BuildContext context, PlayerState p) {
    final prefs = AppScope.of(context).prefs;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${prefs.t('play.moveTo')}: ${p.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: 40,
                itemBuilder: (c, i) => InkWell(
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final goApplies = await _askGoSalary(context);
                    if (goApplies == null) return;
                    await ctl.manualMove(p.id, i + 1,
                        goSalaryApplies: goApplies);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: paletteOf(context).surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: paletteOf(context).line),
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _askGoSalary(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prefs.t('play.passGo')),
        content: Text(prefs.t('play.firstMoveNote')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(prefs.t('action.decline')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(prefs.t('action.confirm')),
          ),
        ],
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MoveChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    return ActionChip(
      label: Text(label, style: TextStyle(color: pal.fg, fontSize: 12)),
      backgroundColor: pal.surface2,
      side: BorderSide(color: pal.line),
      onPressed: onTap,
    );
  }
}
