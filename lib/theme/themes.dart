import 'package:flutter/material.dart';

/// App color palette (ported from the web app's CSS variables).
class AppPalette {
  final Color bg;
  final Color elev;
  final Color surface;
  final Color surface2;
  final Color fg;
  final Color muted;
  final Color gold;
  final Color goldInk;
  final Color felt;
  final Color ok;
  final Color danger;
  final Color dangerInk;
  final Color line;
  final bool isDark;

  const AppPalette({
    required this.bg,
    required this.elev,
    required this.surface,
    required this.surface2,
    required this.fg,
    required this.muted,
    required this.gold,
    required this.goldInk,
    required this.felt,
    required this.ok,
    required this.danger,
    required this.dangerInk,
    required this.line,
    required this.isDark,
  });
}

class AppTheme {
  final String id;
  final String nameKey; // i18n key: theme.<id>
  final AppPalette p;
  const AppTheme(this.id, this.nameKey, this.p);

  ThemeData get themeData {
    final p = this.p;
    final scheme = ColorScheme(
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      primary: p.gold,
      onPrimary: p.goldInk,
      secondary: p.felt,
      onSecondary: p.fg,
      surface: p.surface,
      onSurface: p.fg,
      surfaceContainerHighest: p.surface2,
      error: p.danger,
      onError: p.dangerInk,
      outline: p.line,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      cardColor: p.surface,
      dividerColor: p.line,
      appBarTheme: AppBarTheme(
        backgroundColor: p.elev,
        foregroundColor: p.fg,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.elev,
        selectedItemColor: p.gold,
        unselectedItemColor: p.muted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.elev,
        contentTextStyle: TextStyle(color: p.fg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.gold, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface2,
        selectedColor: p.gold,
        labelStyle: TextStyle(color: p.fg),
        secondaryLabelStyle: TextStyle(color: p.goldInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: p.fg),
        bodyMedium: TextStyle(color: p.fg),
        bodySmall: TextStyle(color: p.muted),
        titleLarge: TextStyle(color: p.fg, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: p.fg, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(color: p.fg),
      ),
      iconTheme: IconThemeData(color: p.fg),
    );
  }
}

const List<AppTheme> kThemes = [
  AppTheme(
    'dark',
    'theme.dark',
    AppPalette(
      bg: Color(0xFF10140F), elev: Color(0xFF171D15), surface: Color(0xFF1E261C),
      surface2: Color(0xFF283226), fg: Color(0xFFF4EFE4), muted: Color(0xFFB7AD98),
      gold: Color(0xFFE0B15A), goldInk: Color(0xFF2A2112), felt: Color(0xFF3F8F5B),
      ok: Color(0xFF8DCEA8), danger: Color(0xFFE07A68), dangerInk: Color(0xFF2C1410),
      line: Color(0xFF3C4636), isDark: true,
    ),
  ),
  AppTheme(
    'light',
    'theme.light',
    AppPalette(
      bg: Color(0xFFF3EEE4), elev: Color(0xFFFFFAF2), surface: Color(0xFFFFFAF2),
      surface2: Color(0xFFE7ECDF), fg: Color(0xFF1C2218), muted: Color(0xFF5C584C),
      gold: Color(0xFF8A6230), goldInk: Color(0xFFFFF8EC), felt: Color(0xFF1F6B3A),
      ok: Color(0xFF1D6B3C), danger: Color(0xFF9D3B2C), dangerInk: Color(0xFFFFF6F3),
      line: Color(0xFFDDD2C0), isDark: false,
    ),
  ),
  AppTheme(
    'midnight',
    'theme.midnight',
    AppPalette(
      bg: Color(0xFF0A0F1E), elev: Color(0xFF101828), surface: Color(0xFF141D33),
      surface2: Color(0xFF1C2742), fg: Color(0xFFE8EEFC), muted: Color(0xFF93A0C0),
      gold: Color(0xFF7AA2F7), goldInk: Color(0xFF0A0F1E), felt: Color(0xFF1D3A5F),
      ok: Color(0xFF7DDBA3), danger: Color(0xFFF08080), dangerInk: Color(0xFF1E0A0A),
      line: Color(0xFF26314D), isDark: true,
    ),
  ),
  AppTheme(
    'forest',
    'theme.forest',
    AppPalette(
      bg: Color(0xFF0D130E), elev: Color(0xFF141B15), surface: Color(0xFF1A241B),
      surface2: Color(0xFF243024), fg: Color(0xFFECF3E8), muted: Color(0xFFA3B39A),
      gold: Color(0xFFC9A44A), goldInk: Color(0xFF1A1408), felt: Color(0xFF2D5A3A),
      ok: Color(0xFF9FE0B0), danger: Color(0xFFE07A68), dangerInk: Color(0xFF200F0A),
      line: Color(0xFF33402F), isDark: true,
    ),
  ),
  AppTheme(
    'sunset',
    'theme.sunset',
    AppPalette(
      bg: Color(0xFF1C100B), elev: Color(0xFF261510), surface: Color(0xFF31201A),
      surface2: Color(0xFF40291F), fg: Color(0xFFFBEEDF), muted: Color(0xFFC4A68E),
      gold: Color(0xFFF0A35E), goldInk: Color(0xFF241105), felt: Color(0xFF7A3B1E),
      ok: Color(0xFFA8D5A2), danger: Color(0xFFEF6F6F), dangerInk: Color(0xFF260D0D),
      line: Color(0xFF4D342A), isDark: true,
    ),
  ),
  AppTheme(
    'rose',
    'theme.rose',
    AppPalette(
      bg: Color(0xFF170F16), elev: Color(0xFF201420), surface: Color(0xFF2A1A2B),
      surface2: Color(0xFF382238), fg: Color(0xFFF7E9F2), muted: Color(0xFFBD9DB8),
      gold: Color(0xFFE08BB8), goldInk: Color(0xFF220F1C), felt: Color(0xFF5F2D52),
      ok: Color(0xFFA8D5A2), danger: Color(0xFFEF6F6F), dangerInk: Color(0xFF260D12),
      line: Color(0xFF453049), isDark: true,
    ),
  ),
  AppTheme(
    'mono',
    'theme.mono',
    AppPalette(
      bg: Color(0xFF101010), elev: Color(0xFF171717), surface: Color(0xFF1E1E1E),
      surface2: Color(0xFF2A2A2A), fg: Color(0xFFEDEDED), muted: Color(0xFFA3A3A3),
      gold: Color(0xFFF5F5F5), goldInk: Color(0xFF141414), felt: Color(0xFF333333),
      ok: Color(0xFFBDBDBD), danger: Color(0xFFEF9A9A), dangerInk: Color(0xFF1C0F0F),
      line: Color(0xFF383838), isDark: true,
    ),
  ),
];

AppTheme themeById(String id) =>
    kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes[0]);

/// Easy access to the active palette from a BuildContext.
AppPalette paletteOf(BuildContext context) {
  final id = _ActiveTheme.of(context);
  return themeById(id).p;
}

class _ActiveTheme extends InheritedWidget {
  final String themeId;
  const _ActiveTheme({required this.themeId, required super.child});
  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ActiveTheme>()?.themeId ?? 'dark';
  @override
  bool updateShouldNotify(_ActiveTheme old) => old.themeId != themeId;
}

class ActiveThemeScope extends StatelessWidget {
  final String themeId;
  final Widget child;
  const ActiveThemeScope({super.key, required this.themeId, required this.child});
  @override
  Widget build(BuildContext context) =>
      _ActiveTheme(themeId: themeId, child: child);
}
