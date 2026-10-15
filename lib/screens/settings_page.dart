import 'package:flutter/material.dart';
import '../i18n/l10n.dart';
import '../main.dart';
import '../theme/themes.dart';
import 'help_page.dart';
import 'about_page.dart';

/// Settings as a FULL PAGE (bottom nav stays visible).
/// Language & theme open as popups; help & about open as pages with a fixed back button.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(prefs.t('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Row(
            icon: Icons.language,
            title: prefs.t('settings.language'),
            subtitle: localeLabel(prefs.locale),
            onTap: () => _languagePopup(context),
          ),
          _Row(
            icon: Icons.palette_outlined,
            title: prefs.t('settings.theme'),
            subtitle: prefs.t(themeById(prefs.themeId).nameKey),
            onTap: () => _themePopup(context),
          ),
          _Row(
            icon: Icons.help_outline,
            title: prefs.t('settings.help'),
            subtitle: prefs.t('help.title'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpPage()),
            ),
          ),
          _Row(
            icon: Icons.info_outline,
            title: prefs.t('settings.about'),
            subtitle: prefs.t('about.title'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              prefs.t('app.credit'),
              style: TextStyle(color: pal.gold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              prefs.t('settings.note'),
              textAlign: TextAlign.center,
              style: TextStyle(color: pal.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _languagePopup(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: pal.line, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Text(prefs.t('settings.language'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: kLocales.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final loc = kLocales[i];
                    final selected = prefs.locale == loc.id;
                    return ListTile(
                      title: Text(loc.label,
                          style: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected ? pal.gold : pal.fg)),
                      trailing: selected
                          ? Icon(Icons.check, color: pal.gold)
                          : null,
                      onTap: () async {
                        await prefs.setLocale(loc.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _themePopup(BuildContext context) {
    final prefs = AppScope.of(context).prefs;
    final pal = paletteOf(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: pal.line, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Text(prefs.t('settings.theme'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: kThemes.length,
                  itemBuilder: (c, i) {
                    final th = kThemes[i];
                    final selected = prefs.themeId == th.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await prefs.setTheme(th.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: th.p.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? th.p.gold : th.p.line,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: th.p.gold,
                                shape: BoxShape.circle,
                                border: Border.all(color: th.p.line),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                prefs.t(th.nameKey),
                                style: TextStyle(
                                    color: th.p.fg,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selected)
                              Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(start: 4),
                                child: Icon(Icons.check,
                                    color: th.p.gold, size: 18),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Row({
    required this.icon, required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = paletteOf(context);
    return Card(
      color: pal.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: pal.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: pal.gold),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: pal.muted, fontSize: 12)),
        trailing: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left
              : Icons.chevron_right,
          color: pal.muted,
        ),
        onTap: onTap,
      ),
    );
  }
}
