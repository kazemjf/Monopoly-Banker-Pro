import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/themes.dart';

/// Help page: comprehensive Monopoly rules. Fixed app bar with back button.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _sections = [
    'help.goal',
    'help.setup',
    'help.turn',
    'help.buying',
    'help.rent',
    'help.building',
    'help.jail',
    'help.end',
  ];

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(prefs.t('help.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final key in _sections) _HelpSection(helpKey: key, palette: pal),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String helpKey;
  final AppPalette palette;
  const _HelpSection({required this.helpKey, required this.palette});

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final raw = prefs.t(helpKey);
    final parts = raw.split('\n\n');
    final title = parts.first;
    final body = parts.skip(1).join('\n\n');
    return Card(
      color: palette.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: palette.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 8),
            Text(body,
                style:
                    TextStyle(color: palette.fg, fontSize: 13.5, height: 1.55)),
          ],
        ),
      ),
    );
  }
}
