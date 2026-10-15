import 'package:flutter/material.dart';
import '../../../game/controller.dart';
import '../../../main.dart';
import '../../../theme/themes.dart';

/// Ledger tab: full immutable transaction history (newest first).
class LedgerTab extends StatelessWidget {
  final GameController ctl;
  const LedgerTab({super.key, required this.ctl});

  IconData _icon(String type) {
    switch (type) {
      case 'purchase':
      case 'auction':
        return Icons.shopping_cart_outlined;
      case 'rent':
        return Icons.payments_outlined;
      case 'mortgage':
      case 'unmortgage':
        return Icons.account_balance_outlined;
      case 'build':
      case 'sell-building':
        return Icons.home_work_outlined;
      case 'trade':
        return Icons.swap_horiz;
      case 'tax':
      case 'fine':
        return Icons.receipt_outlined;
      case 'jail':
        return Icons.lock_outline;
      case 'card':
        return Icons.style_outlined;
      case 'go':
        return Icons.flag_outlined;
      case 'move':
        return Icons.place_outlined;
      case 'adjust':
        return Icons.tune_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final entries = ctl.game.ledger.reversed.toList();
    if (entries.isEmpty) {
      return Center(
        child: Text(prefs.t('play.noTx'),
            style: TextStyle(color: pal.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final e = entries[i];
        final time =
            DateTime.fromMillisecondsSinceEpoch(e.ts).toLocal().toString().substring(5, 16);
        return Card(
          color: pal.surface,
          margin: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            leading: Icon(_icon(e.type), color: pal.gold, size: 20),
            title: Text(e.text, style: const TextStyle(fontSize: 13)),
            subtitle: Text(time, style: TextStyle(color: pal.muted, fontSize: 11)),
            trailing: e.amount != null
                ? Text(
                    '${e.amount! >= 0 ? '+' : ''}${ctl.money(e.amount!)}',
                    style: TextStyle(
                      color: e.amount! >= 0 ? pal.ok : pal.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
