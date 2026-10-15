import 'package:flutter/material.dart';
import '../i18n/l10n.dart';
import '../main.dart';
import '../theme/themes.dart';
import 'shell.dart';

/// Full-screen language picker with a two-step flow: tapping a row only
/// marks it as pending-selected; the confirm button applies it.
/// On first launch it routes to [Shell] afterwards.
class LanguagePickerScreen extends StatefulWidget {
  final bool firstLaunch;
  const LanguagePickerScreen({super.key, this.firstLaunch = false});

  @override
  State<LanguagePickerScreen> createState() => _LanguagePickerScreenState();
}

class _LanguagePickerScreenState extends State<LanguagePickerScreen> {
  /// Pending selection; null means "keep the currently active locale".
  String? _pendingId;

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    final effectiveId = _pendingId ?? prefs.locale;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(Icons.account_balance, size: 64, color: pal.gold),
              const SizedBox(height: 16),
              Text(
                prefs.t('app.name'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                prefs.t('lang.title'),
                textAlign: TextAlign.center,
                style: TextStyle(color: pal.muted, fontSize: 16),
              ),
              Text(
                prefs.t('lang.subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(color: pal.muted, fontSize: 12),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: kLocales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final loc = kLocales[i];
                    final selected = effectiveId == loc.id;
                    return Card(
                      color: selected ? pal.gold : pal.surface,
                      child: ListTile(
                        title: Text(
                          loc.label,
                          style: TextStyle(
                            color: selected ? pal.goldInk : pal.fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check_circle, color: pal.goldInk)
                            : null,
                        onTap: () => setState(() => _pendingId = loc.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await prefs.setLocale(effectiveId);
                  if (!mounted) return;
                  if (widget.firstLaunch) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const Shell()),
                    );
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(prefs.t('action.confirm')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
