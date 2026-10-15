import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../theme/themes.dart';

/// About page: about the app + transliterated credit + Telegram link.
/// Fixed app bar with back button.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(prefs.t('about.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Icon(Icons.account_balance, size: 72, color: pal.gold),
          const SizedBox(height: 16),
          Text(
            prefs.t('app.name'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            prefs.t('about.text'),
            style: TextStyle(color: pal.fg, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse('https://t.me/Kaz33mm');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.send),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(prefs.t('about.telegram')),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            prefs.t('app.credit'),
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.gold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
