import 'package:flutter/material.dart';
import '../../data/editions.dart';
import '../../game/controller.dart';
import '../../main.dart';
import '../../models/game.dart';
import '../../theme/themes.dart';
import 'tabs/players_tab.dart';
import 'tabs/board_tab.dart';
import 'tabs/deeds_tab.dart';
import 'tabs/trade_tab.dart';
import 'tabs/ledger_tab.dart';

/// Banker game screen. The main bottom nav is REPLACED here by a banker tab bar.
class GameScreen extends StatefulWidget {
  final GameState game;
  final Edition edition;
  const GameScreen({super.key, required this.game, required this.edition});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _ctl;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _ctl = GameController(
      game: widget.game,
      edition: widget.edition,
      save: (g) => AppScope.of(context).games.saveGame(g),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    return ListenableBuilder(
      listenable: _ctl,
      builder: (ctx, _) {
        final tabs = [
          PlayersTab(ctl: _ctl),
          BoardTab(ctl: _ctl),
          DeedsTab(ctl: _ctl),
          TradeTab(ctl: _ctl),
          LedgerTab(ctl: _ctl),
        ];
        final labels = [
          prefs.t('play.tabPlayers'),
          prefs.t('play.tabBoard'),
          prefs.t('play.tabDeeds'),
          prefs.t('play.tabTrade'),
          prefs.t('play.tabLedger'),
        ];
        final icons = const [
          Icons.group_outlined,
          Icons.grid_view_outlined,
          Icons.home_work_outlined,
          Icons.swap_horiz_outlined,
          Icons.receipt_long_outlined,
        ];
        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(_ctl.game.name, style: const TextStyle(fontSize: 16)),
                Text(
                  _ctl.edition.localizedName(prefs.locale),
                  style: TextStyle(fontSize: 11, color: pal.muted),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: _ctl.game.status == 'paused'
                    ? prefs.t('action.resume')
                    : prefs.t('action.pause'),
                icon: Icon(_ctl.game.status == 'paused'
                    ? Icons.play_arrow
                    : Icons.pause),
                onPressed: () =>
                    _ctl.setPaused(_ctl.game.status != 'paused'),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'end') {
                    final ok = await confirmDialog(
                      context,
                      title: prefs.t('action.end'),
                      message: _ctl.game.name,
                      danger: true,
                    );
                    if (ok) await _ctl.endGame();
                  }
                },
                itemBuilder: (c) => [
                  PopupMenuItem(
                      value: 'end', child: Text(prefs.t('action.end'))),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _CurrentPlayerStrip(ctl: _ctl),
              Expanded(
                child: IndexedStack(index: _tab, children: tabs),
              ),
            ],
          ),
          bottomNavigationBar: _BankerTabBar(
            current: _tab,
            labels: labels,
            icons: icons,
            onTap: (i) => setState(() => _tab = i),
          ),
        );
      },
    );
  }
}

/// Compact current-player strip with next-turn button.
class _CurrentPlayerStrip extends StatelessWidget {
  final GameController ctl;
  const _CurrentPlayerStrip({required this.ctl});

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final p = ctl.game.currentPlayer;
    final space = ctl.edition.space(p.position);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pal.elev,
        border: Border(bottom: BorderSide(color: pal.line)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: pal.gold,
            foregroundColor: pal.goldInk,
            child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (p.jailed) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: pal.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(prefs.t('pstatus.jailed'),
                            style: TextStyle(
                                fontSize: 10, color: pal.dangerInk)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${ctl.money(p.cash)} • ${space.localizedName(prefs.locale)}',
                  style: TextStyle(color: pal.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final info = await ctl.nextTurn(prefs.locale);
              if (!info.advanced) {
                // Turn is BLOCKED — explain why with a popup; the turn
                // stays on the same player until the banker resolves it.
                final String title;
                final String message;
                switch (info.blockReason) {
                  case 'unowned':
                    title = prefs.t('play.unownedBlockTitle');
                    message = prefs.t('play.unownedBlockMsg',
                        {'space': info.spaceName});
                    break;
                  case 'jail':
                    title = prefs.t('play.jailTurnTitle');
                    message = prefs.t('play.jailTurnMsg', {
                      'player': info.playerName,
                      'amount': ctl.money(ctl.edition.jailFine),
                    });
                    break;
                  case 'notMoved':
                  default:
                    title = prefs.t('play.notMovedTitle');
                    message = prefs.t(
                        'play.notMovedMsg', {'player': info.playerName});
                    break;
                }
                if (context.mounted) {
                  await showDialog(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: Text(title),
                      content: Text(message),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.of(dctx).pop(),
                          child: Text(prefs.t('action.confirm')),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }
              if (info.rentPaid) {
                messenger.showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(prefs.t('play.rentAutoPaid', {
                    'player': info.playerName,
                    'owner': info.ownerName,
                    'space': info.spaceName,
                    'amount': ctl.money(info.amount),
                  })),
                ));
              }
            },
            child: Text(prefs.t('action.next')),
          ),
        ],
      ),
    );
  }
}

/// Banker tab bar (replaces the main bottom nav on the game screen).
class _BankerTabBar extends StatelessWidget {
  final int current;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onTap;
  const _BankerTabBar({
    required this.current,
    required this.labels,
    required this.icons,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: pal.elev,
          border: Border(top: BorderSide(color: pal.line, width: 2)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth / labels.length;
            // In RTL the Row flips visually, so item i sits at
            // (n-1-i)*w from the left; mirror the pill offset accordingly.
            final pillOffset =
                (rtl ? labels.length - 1 - current : current) * w + 6;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: pillOffset,
                  top: 0,
                  bottom: 0,
                  width: w - 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: pal.felt.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: pal.gold.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => onTap(i),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: i == current ? 1.18 : 1.0,
                                  duration:
                                      const Duration(milliseconds: 280),
                                  child: Icon(
                                    icons[i],
                                    color: i == current
                                        ? pal.gold
                                        : pal.muted,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration:
                                      const Duration(milliseconds: 280),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: i == current
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                    color: i == current
                                        ? pal.gold
                                        : pal.muted,
                                  ),
                                  child: Text(labels[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
