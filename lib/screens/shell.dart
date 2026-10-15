import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme/themes.dart';
import 'games_list.dart';
import 'new_game_wizard.dart';
import 'settings_page.dart';

/// Main shell: persistent animated bottom nav (Games / New game / Settings / Exit).
class Shell extends StatefulWidget {
  final int initialTab;
  const Shell({super.key, this.initialTab = 0});
  @override
  State<Shell> createState() => ShellState();

  static ShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<ShellState>();
}

class ShellState extends State<Shell> {
  int _tab = 0;

  void goToTab(int i) => setState(() => _tab = i);

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  Future<void> _onExitTap() async {
    final prefs = AppScope.of(context).prefs;
    final ok = await confirmDialog(
      context,
      title: prefs.t('exit.title'),
      message: prefs.t('exit.message'),
      confirmLabel: prefs.t('exit.confirm'),
      danger: true,
    );
    if (ok) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final bodies = [
      const GamesListScreen(),
      const NewGameWizardScreen(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: bodies),
      ),
      bottomNavigationBar: _AnimatedBottomBar(
        current: _tab,
        onTap: (i) {
          if (i == 3) {
            _onExitTap();
          } else {
            setState(() => _tab = i);
          }
        },
        items: [
          _BarItem(Icons.list_alt, prefs.t('nav.games')),
          _BarItem(Icons.add_circle_outline, prefs.t('nav.newGame')),
          _BarItem(Icons.settings_outlined, prefs.t('nav.settings')),
          _BarItem(Icons.exit_to_app, prefs.t('nav.exit')),
        ],
        palette: pal,
      ),
    );
  }
}

class _BarItem {
  final IconData icon;
  final String label;
  _BarItem(this.icon, this.label);
}

/// Custom bottom bar with a sliding animated pill behind the active tab.
class _AnimatedBottomBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  final List<_BarItem> items;
  final AppPalette palette;
  const _AnimatedBottomBar({
    required this.current,
    required this.onTap,
    required this.items,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final pal = palette;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: pal.elev,
          border: Border(top: BorderSide(color: pal.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final w = constraints.maxWidth / items.length;
            // In RTL the Row flips visually, so item i sits at
            // (n-1-i)*w from the left; mirror the pill offset accordingly.
            final pillOffset =
                (rtl ? items.length - 1 - current : current) * w + 8;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: pillOffset,
                  top: 0,
                  bottom: 0,
                  width: w - 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: pal.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: pal.gold.withValues(alpha: 0.45)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _BarButton(
                          item: items[i],
                          active: i == current,
                          palette: pal,
                          onTap: () => onTap(i),
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

class _BarButton extends StatelessWidget {
  final _BarItem item;
  final bool active;
  final AppPalette palette;
  final VoidCallback onTap;
  const _BarButton({
    required this.item,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              child: Icon(
                item.icon,
                color: active ? pal.gold : pal.muted,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 280),
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                color: active ? pal.gold : pal.muted,
              ),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
