import 'package:flutter/material.dart';
import '../../../game/controller.dart';
import '../../../main.dart';
import '../../../models/game.dart';
import '../../../theme/themes.dart';

/// Players tab: cards with cash/position/jail; tap for the action sheet.
class PlayersTab extends StatelessWidget {
  final GameController ctl;
  const PlayersTab({super.key, required this.ctl});

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final game = ctl.game;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: game.players.length,
      itemBuilder: (ctx, i) {
        final p = game.players[i];
        final isCurrent = i == game.currentPlayerIdx;
        final space = ctl.edition.space(p.position);
        return Card(
          color: isCurrent ? pal.gold.withValues(alpha: 0.12) : pal.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: isCurrent ? pal.gold : pal.line,
                width: isCurrent ? 2 : 1),
          ),
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _playerSheet(context, p),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isCurrent ? pal.gold : pal.surface2,
                    foregroundColor: isCurrent ? pal.goldInk : pal.fg,
                    child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (p.jailed) ...[
                              const SizedBox(width: 6),
                              _badge(prefs.t('pstatus.jailed'), pal.danger, pal.dangerInk),
                            ],
                            if (!p.hasMoved) ...[
                              const SizedBox(width: 6),
                              _badge(prefs.t('play.firstMoveNote').split('.').first,
                                  pal.surface2, pal.muted),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ctl.money(p.cash)} • ${space.localizedName(prefs.locale)} (#${space.n})',
                          style: TextStyle(color: pal.muted, fontSize: 12),
                        ),
                        if (p.jailCards > 0)
                          Text(prefs.t('play.jailCards', {'count': '${p.jailCards}'}),
                              style: TextStyle(color: pal.gold, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    color: pal.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 10, color: fg)),
      );

  void _playerSheet(BuildContext context, PlayerState p) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              const SizedBox(height: 4),
              Center(
                  child: Text(ctl.money(p.cash),
                      style: TextStyle(color: pal.gold, fontSize: 16))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActBtn(Icons.add, prefs.t('action.add'), () async {
                    final v = await amountDialog(context,
                        title: '${p.name} +');
                    if (v != null && v != 0) {
                      await ctl.adjustMoney(p.id, v.abs(), 'manual');
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }
                  }),
                  _ActBtn(Icons.remove, prefs.t('action.remove'), () async {
                    final v = await amountDialog(context,
                        title: '${p.name} −');
                    if (v != null && v != 0) {
                      await ctl.adjustMoney(p.id, -v.abs(), 'manual');
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }
                  }),
                  _ActBtn(Icons.place_outlined, prefs.t('play.setPosition'), () {
                    if (p.jailed) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(prefs.t('play.jailNoMove',
                            {'amount': ctl.money(ctl.edition.jailFine)})),
                      ));
                      return;
                    }
                    Navigator.of(ctx).pop();
                    _spacePicker(context, p, (n) => ctl.setPosition(p.id, n));
                  }),
                  _ActBtn(Icons.casino_outlined, prefs.t('nav.dice'), () async {
                    final v = await amountDialog(context,
                        title: prefs.t('nav.dice'), hint: '2–12');
                    if (v == null || v <= 0) return;
                    // Doubles totals are always even: ask the banker.
                    var wasDoubles = false;
                    if (v.isEven) {
                      wasDoubles = await askYesNo(context,
                          title: prefs.t('play.doublesTitle'),
                          message: prefs.t('play.doublesAsk'));
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    final outcome =
                        await ctl.rollDice(p.id, v, wasDoubles: wasDoubles);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    final String? msg = outcome.extraTurn
                        ? prefs.t('play.doublesExtraTurn', {'player': p.name})
                        : outcome.sentToJail
                            ? prefs.t('play.doublesToJail', {'player': p.name})
                            : outcome.forcedFine
                                ? prefs.t('play.jailForcedFine', {
                                    'player': p.name,
                                    'amount':
                                        ctl.money(ctl.edition.jailFine),
                                    'steps': '$v',
                                  })
                                : outcome.releasedFromJail
                                    ? prefs.t('play.jailReleasedDoubles',
                                        {'player': p.name})
                                    : outcome.stayedInJail
                                        ? prefs.t('play.jailStayed', {
                                            'player': p.name,
                                            'n': '${p.jailAttempts}',
                                          })
                                        : null;
                    if (msg != null) {
                      messenger.showSnackBar(SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(msg),
                      ));
                    }
                  }),
                  if (!p.jailed)
                    _ActBtn(Icons.lock_outline, prefs.t('play.sendToJail'),
                        () async {
                      await ctl.sendToJail(p.id);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }),
                  if (p.jailed) ...[
                    _ActBtn(Icons.payments_outlined,
                        '${prefs.t('play.jailReleaseTitle')} (${ctl.money(ctl.edition.jailFine)})',
                        () async {
                      await ctl.releaseFromJail(p.id, 'pay');
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }),
                    if (p.jailCards > 0)
                      _ActBtn(Icons.card_membership_outlined,
                          prefs.t('play.cardJailCard'), () async {
                        await ctl.releaseFromJail(p.id, 'card');
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      }),
                  ],
                  _ActBtn(Icons.card_giftcard_outlined,
                      '+ ${prefs.t('play.cardJailCard')}', () async {
                    await ctl.giveJailCard(p.id);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  }),
                  _ActBtn(Icons.swap_horiz, prefs.t('action.next'), () async {
                    final idx = ctl.game.players.indexOf(p);
                    await ctl.setCurrentPlayer(idx);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _spacePicker(
      BuildContext context, PlayerState p, Future<void> Function(int) onPick) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final spaces = ctl.edition.spaces;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(prefs.t('play.selectSpace'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: spaces.length,
                itemBuilder: (c, i) {
                  final s = spaces[i];
                  final sel = p.position == s.n;
                  return Card(
                    color: sel ? pal.gold.withValues(alpha: 0.22) : pal.surface,
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _spaceDotColor(s.color),
                          shape: BoxShape.circle,
                          border: Border.all(color: pal.line),
                        ),
                      ),
                      title: Text(
                        s.localizedName(prefs.locale),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: sel ? pal.goldInk : pal.fg,
                        ),
                      ),
                      trailing: Text(
                        '#${s.n}',
                        style: TextStyle(color: pal.muted, fontSize: 12),
                      ),
                      onTap: () async {
                        await onPick(s.n);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps a board color-group name to a dot color; neutral for non-streets.
  Color _spaceDotColor(String? colorName) {
    switch (colorName) {
      case 'brown':
        return const Color(0xFF8B5A2B);
      case 'lightBlue':
        return const Color(0xFF6EC6E8);
      case 'pink':
        return const Color(0xFFE75480);
      case 'orange':
        return const Color(0xFFFF8C42);
      case 'red':
        return const Color(0xFFE53935);
      case 'yellow':
        return const Color(0xFFFFD54F);
      case 'green':
        return const Color(0xFF43A047);
      case 'darkBlue':
        return const Color(0xFF283593);
      default:
        return Colors.grey;
    }
  }
}

class _ActBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActBtn(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    return ActionChip(
      avatar: Icon(icon, size: 16, color: pal.gold),
      label: Text(label, style: TextStyle(color: pal.fg, fontSize: 12)),
      backgroundColor: pal.surface2,
      side: BorderSide(color: pal.line),
      onPressed: onTap,
    );
  }
}
