import 'package:flutter/material.dart';
import '../../../data/editions.dart';
import '../../../game/controller.dart';
import '../../../game/engine.dart';
import '../../../main.dart';
import '../../../models/game.dart';
import '../../../theme/themes.dart';

/// Deeds tab: landing resolver for the current player + per-player property management.
class DeedsTab extends StatefulWidget {
  final GameController ctl;
  const DeedsTab({super.key, required this.ctl});
  @override
  State<DeedsTab> createState() => _DeedsTabState();
}

class _DeedsTabState extends State<DeedsTab> {
  bool _railroadDoubled = false;
  final _diceCtrl = TextEditingController();

  @override
  void dispose() {
    _diceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final ctl = widget.ctl;
    final p = ctl.game.currentPlayer;
    final res = resolveLanding(
      ctl.game, ctl.edition, p,
      railroadDoubled: _railroadDoubled,
      utilityDice: int.tryParse(_diceCtrl.text) ?? 0,
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _resolverCard(prefs, pal, ctl, p, res),
        const SizedBox(height: 8),
        SectionHeader(prefs.t('play.properties')),
        for (final pl in ctl.game.players) _playerDeeds(prefs, pal, ctl, pl),
        const SizedBox(height: 8),
        _assetsCard(prefs, pal, ctl),
      ],
    );
  }

  // ---------- landing resolver ----------
  Widget _resolverCard(prefs, AppPalette pal, GameController ctl, PlayerState p, LandingResolution res) {
    final space = ctl.edition.space(p.position);
    return Card(
      color: pal.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${p.name} → #${space.n} ${space.localizedName(prefs.locale)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => setState(() {}),
                  child: Text(prefs.t('play.resolve')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _resolutionBody(prefs, pal, ctl, p, space, res),
          ],
        ),
      ),
    );
  }

  Widget _resolutionBody(prefs, AppPalette pal, GameController ctl, PlayerState p,
      BoardSpace space, LandingResolution res) {
    switch (res.kind) {
      case LandingKind.buy:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${prefs.t('play.unowned')} • ${prefs.t('play.price')}: ${ctl.money(res.amount)}',
                style: TextStyle(color: pal.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => ctl.buyProperty(p.id, space.n),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: Text('${prefs.t('play.buy')} ${ctl.money(res.amount)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _auctionSheet(context, space),
                  icon: const Icon(Icons.gavel_outlined, size: 18),
                  label: Text(prefs.t('play.auction')),
                ),
              ],
            ),
          ],
        );
      case LandingKind.rent:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${prefs.t('play.payRent')}: ${p.name} → ${res.ownerName}  ${ctl.money(res.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (space.type == 'railroad') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _railroadDoubled,
                    onChanged: (v) => setState(() => _railroadDoubled = v ?? false),
                  ),
                  Flexible(child: Text(prefs.t('play.doubleRent'), style: const TextStyle(fontSize: 13))),
                ],
              ),
            ],
            if (space.type == 'utility') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _diceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: prefs.t('nav.dice'),
                    hintText: '2–12',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ctl.payRent(p.id, space.n,
                  railroadDoubled: _railroadDoubled,
                  utilityDice: int.tryParse(_diceCtrl.text) ?? 0),
              child: Text('${prefs.t('play.payRent')} ${ctl.money(res.amount)}'),
            ),
          ],
        );
      case LandingKind.payBank:
        return Row(
          children: [
            Expanded(
              child: Text('${prefs.t('play.payBank')}: ${ctl.money(res.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              onPressed: () => ctl.payTax(p.id, space.n),
              child: Text(prefs.t('play.pay')),
            ),
          ],
        );
      case LandingKind.receive:
        return Row(
          children: [
            Expanded(
              child: Text(
                '${prefs.t('play.collectGo')}: ${ctl.money(res.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              onPressed: () => ctl.receiveGo(p.id),
              child: Text(prefs.t('play.collectGo')),
            ),
          ],
        );
      case LandingKind.goToJail:
        return Row(
          children: [
            Expanded(child: Text(prefs.t('play.cardGoToJail'),
                style: const TextStyle(fontWeight: FontWeight.w600))),
            FilledButton(
              onPressed: () => ctl.sendToJail(p.id),
              child: Text(prefs.t('play.sendToJail')),
            ),
          ],
        );
      case LandingKind.card:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(space.type == 'chance' ? prefs.t('board.type.chance') : prefs.t('board.type.community'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _CardLogger(ctl: ctl, player: p),
          ],
        );
      case LandingKind.jail:
        return Text(prefs.t('play.justVisiting'), style: TextStyle(color: pal.muted));
      case LandingKind.freeParking:
        return Text(prefs.t('play.freeParking'), style: TextStyle(color: pal.muted));
      case LandingKind.none:
        return Text('—', style: TextStyle(color: pal.muted));
    }
  }

  void _auctionSheet(BuildContext context, BoardSpace space) {
    final ctl = widget.ctl;
    final prefs = AppScope.of(context).prefs;
    String? winnerId = ctl.game.currentPlayer.id;
    final bidCtrl = TextEditingController(text: '1');
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(prefs.t('play.auctionTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 4),
              Text(space.localizedName(prefs.locale),
                  style: TextStyle(color: paletteOf(context).muted)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: winnerId,
                decoration: InputDecoration(labelText: prefs.t('play.auctionWinner')),
                items: [
                  for (final pl in ctl.game.players)
                    DropdownMenuItem(value: pl.id, child: Text(pl.name)),
                ],
                onChanged: (v) => winnerId = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bidCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: prefs.t('play.bid')),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final bid = int.tryParse(bidCtrl.text) ?? 0;
                  if (winnerId != null && bid > 0) {
                    await ctl.auctionProperty(space.n, winnerId!, bid);
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(prefs.t('play.placeBid')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- per-player deeds ----------
  Widget _playerDeeds(prefs, AppPalette pal, GameController ctl, PlayerState pl) {
    final deeds = ctl.game.deeds.values
        .where((d) => d.ownerId == pl.id)
        .toList()
      ..sort((a, b) => a.spaceN.compareTo(b.spaceN));
    return Card(
      color: pal.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(pl.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${prefs.t('play.cash')}: ${ctl.money(pl.cash)} • ${deeds.length} ${prefs.t('play.properties').toLowerCase()}',
          style: TextStyle(color: pal.muted, fontSize: 12),
        ),
        children: [
          if (deeds.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(prefs.t('play.noProps'),
                  style: TextStyle(color: pal.muted)),
            ),
          for (final d in deeds) _deedRow(prefs, pal, ctl, pl, d),
        ],
      ),
    );
  }

  Widget _deedRow(prefs, AppPalette pal, GameController ctl, PlayerState pl, DeedState d) {
    final s = ctl.edition.space(d.spaceN);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${s.n} ${s.localizedName(prefs.locale)}'
                  '${d.mortgaged ? ' (M)' : ''}'
                  '${d.houses > 0 ? (d.houses >= 5 ? ' 🏨' : ' 🏠×${d.houses}') : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (s.type == 'street' && !d.mortgaged && d.houses < 5)
                _buildChip(prefs, pal, ctl, pl, d, s),
              if (d.houses > 0)
                _sellChip(prefs, pal, ctl, pl, d),
              if (!d.mortgaged && d.houses == 0)
                _mini(prefs.t('play.mortgage'), true, () => ctl.mortgage(pl.id, d.spaceN), pal),
              if (d.mortgaged)
                _mini('${prefs.t('play.unmortgage')} (${ctl.money(unmortgageCost(s.price!))})', true,
                    () => ctl.unmortgage(pl.id, d.spaceN), pal),
            ],
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }

  /// Build chip: always tappable — builds when allowed, otherwise explains
  /// exactly why building is blocked (full group? even building? mortgaged?).
  Widget _buildChip(prefs, AppPalette pal, GameController ctl, PlayerState pl,
      DeedState d, BoardSpace s) {
    final reason = buildBlockReason(ctl.game, ctl.edition, d.spaceN);
    final canB = reason == null;
    final isHotel = d.houses >= 4;
    return ActionChip(
      avatar: canB
          ? Icon(Icons.add_home_outlined, size: 14, color: pal.gold)
          : Icon(Icons.info_outline, size: 14, color: pal.muted),
      label: Text(
        '${prefs.t(isHotel ? 'play.buildHotel' : 'play.buildHouse')} (${ctl.money(s.houseCost!)})',
        style: TextStyle(fontSize: 11, color: canB ? pal.fg : pal.muted),
      ),
      backgroundColor: pal.surface2,
      side: BorderSide(
          color: canB ? pal.gold.withValues(alpha: 0.55) : pal.line),
      onPressed: () {
        if (canB) {
          ctl.buildHouse(pl.id, d.spaceN);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(_buildWhyText(prefs, reason)),
          ));
        }
      },
    );
  }

  String _buildWhyText(prefs, String? reason) {
    switch (reason) {
      case 'groupMortgaged':
        return prefs.t('play.buildWhy.groupMortgaged');
      case 'uneven':
        return prefs.t('play.buildWhy.uneven');
      case 'maxed':
        return prefs.t('play.buildWhy.maxed');
      case 'mortgaged':
        return prefs.t('play.buildWhy.mortgaged');
      case 'noFullGroup':
      default:
        return prefs.t('play.buildWhy.noFullGroup');
    }
  }

  /// Sell chip: enforces even selling — explains why when blocked.
  Widget _sellChip(prefs, AppPalette pal, GameController ctl, PlayerState pl,
      DeedState d) {
    final canS = canSellBuilding(ctl.game, ctl.edition, d.spaceN);
    return ActionChip(
      label: Text(
        prefs.t(d.houses >= 5 ? 'play.sellHotel' : 'play.sellHouse'),
        style: TextStyle(fontSize: 11, color: canS ? pal.fg : pal.muted),
      ),
      backgroundColor: pal.surface2,
      side: BorderSide(color: pal.line),
      onPressed: () {
        if (canS) {
          ctl.sellBuilding(pl.id, d.spaceN);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(prefs.t('play.sellWhy.uneven')),
          ));
        }
      },
    );
  }

  Widget _mini(String label, bool enabled, VoidCallback onTap, AppPalette pal) =>
      ActionChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: enabled ? pal.fg : pal.muted)),
        backgroundColor: pal.surface2,
        side: BorderSide(color: pal.line),
        onPressed: enabled ? onTap : null,
      );

  // ---------- assets ----------
  Widget _assetsCard(prefs, AppPalette pal, GameController ctl) {
    return Card(
      color: pal.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prefs.t('play.assets'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            for (final pl in ctl.game.players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(pl.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${prefs.t('play.netWorth')}: ${ctl.money(_netWorth(ctl, pl))}',
                      style: TextStyle(color: pal.gold, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _netWorth(GameController ctl, PlayerState pl) {
    var total = pl.cash;
    for (final d in ctl.game.deeds.values.where((d) => d.ownerId == pl.id)) {
      final s = ctl.edition.space(d.spaceN);
      total += s.price ?? 0;
      total += d.houses * (s.houseCost ?? 0);
    }
    return total;
  }
}

/// Manual card logger (chance / community chest are resolved by the banker).
class _CardLogger extends StatefulWidget {
  final GameController ctl;
  final PlayerState player;
  const _CardLogger({required this.ctl, required this.player});
  @override
  State<_CardLogger> createState() => _CardLoggerState();
}

class _CardLoggerState extends State<_CardLogger> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: prefs.t('play.recordCard'),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: () async {
            final t = _ctrl.text.trim();
            if (t.isEmpty) return;
            final low = t.toLowerCase();
            if (low.contains('jail') ||
                t.contains('زندان') ||
                t.contains('سجن') ||
                t.contains(' prison')) {
              await widget.ctl.giveJailCard(widget.player.id);
            }
            await widget.ctl.drawCard(widget.player.id, t);
            _ctrl.clear();
            if (mounted) setState(() {});
          },
          child: Text(prefs.t('play.recordCard')),
        ),
      ],
    );
  }
}
