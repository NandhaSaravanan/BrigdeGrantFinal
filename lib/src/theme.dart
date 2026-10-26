import 'package:flutter/material.dart';

/// Brand colors. The hero gradient uses fixed colors with white text so it
/// reads the same in light and dark mode.
class Brand {
  static const navy = Color(0xFF12355B);
  static const teal = Color(0xFF0E7C86);
  static const amber = Color(0xFFE0A33A);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D2A4A), navy, teal],
    stops: [0, 0.55, 1],
  );

  /// Accent colors for avatars and stat icons, chosen by index or hash.
  static const accents = [
    Color(0xFF1F6FB2),
    Color(0xFF0E8A7E),
    Color(0xFFB7701C),
    Color(0xFF7A4FB5),
    Color(0xFFB8445A),
    Color(0xFF3F7D3A),
  ];

  static Color accentFor(String key) =>
      accents[key.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff) %
          accents.length];
}

/// Design-specific brand surfaces read by shared widgets.
@immutable
class BrandStyle extends ThemeExtension<BrandStyle> {
  const BrandStyle({
    required this.heroGradient,
    required this.heroShadow,
    this.heroInk = Colors.white,
    this.heroPillBg = const Color(0x24FFFFFF),
    this.heroPillBorder = const Color(0x38FFFFFF),
    this.heroOrbAlphaScale = 1,
    required this.heroButtonBg,
    required this.heroButtonInk,
    required this.badgeGradient,
    this.badgeInk = Colors.white,
    required this.chartBar,
    required this.chartSelected,
    this.heroBorder,
    this.heroRadius = 24,
    this.flat = false,
  });

  /// Fill for hero banners; [heroInk] must contrast with every stop.
  final Gradient heroGradient;
  final Color heroShadow;
  final Color heroInk;
  final Color heroPillBg;
  final Color heroPillBorder;

  /// Multiplier for the decorative white circles in hero banners.
  final double heroOrbAlphaScale;
  final Color heroButtonBg;
  final Color heroButtonInk;

  /// Fill for rank badges and step numbers, with [badgeInk] text.
  final Gradient badgeGradient;
  final Color badgeInk;

  /// Bar and selected-bar colors for the Places chart. Each pair was checked
  /// for colorblind separation and 3:1 contrast on the card surface.
  final Color chartBar;
  final Color chartSelected;

  /// Hairline around hero banners; null for none.
  final Color? heroBorder;
  final double heroRadius;

  /// Metric-grid styling: stat tiles and section cards drop their icon
  /// badges, and stat values use the primary color.
  final bool flat;

  static const classic = BrandStyle(
    heroGradient: Brand.heroGradient,
    heroShadow: Brand.navy,
    heroButtonBg: Colors.white,
    heroButtonInk: Brand.navy,
    badgeGradient: Brand.heroGradient,
    chartBar: Color(0xFF4F8EF7),
    chartSelected: Color(0xFFE05A9A),
  );

  /// Matches the website's Mint design: light mint hero with dark text.
  static const mint = BrandStyle(
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD9F5EA), Color(0xFFC6EFE0), Color(0xFFE6F7D9)],
      stops: [0, 0.55, 1],
    ),
    heroShadow: Color(0xFF0D7A5F),
    heroInk: Mint.ink,
    heroPillBg: Color(0xB3FFFFFF),
    heroPillBorder: Color(0x260D7A5F),
    heroOrbAlphaScale: 6,
    heroButtonBg: Mint.emerald,
    heroButtonInk: Colors.white,
    badgeGradient: LinearGradient(colors: [Mint.emerald, Mint.emerald]),
    chartBar: Color(0xFF14A37F),
    chartSelected: Color(0xFFE8684A),
  );

  /// Light mode: Mint colors with a white summary card and a hairline
  /// border instead of a gradient banner.
  static const flatMint = BrandStyle(
    heroGradient: LinearGradient(colors: [Colors.white, Colors.white]),
    heroShadow: Color(0xFF143C2D),
    heroInk: Mint.ink,
    heroPillBg: Mint.emeraldSoft,
    heroPillBorder: Color(0x00000000),
    heroOrbAlphaScale: 0,
    heroButtonBg: Mint.emerald,
    heroButtonInk: Colors.white,
    badgeGradient: LinearGradient(colors: [Mint.emerald, Mint.emerald]),
    chartBar: Color(0xFF14A37F),
    chartSelected: Color(0xFFE8684A),
    heroBorder: Mint.line,
    heroRadius: 16,
    flat: true,
  );

  static BrandStyle of(BuildContext context) =>
      Theme.of(context).extension<BrandStyle>() ?? classic;

  @override
  BrandStyle copyWith() => this;

  @override
  BrandStyle lerp(BrandStyle? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.navy,
    brightness: brightness,
    secondary: dark ? const Color(0xFF6FD3D9) : Brand.teal,
    tertiary: dark ? const Color(0xFFF2C774) : const Color(0xFF8A5A00),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme;
  final radius = BorderRadius.circular(18);

  return base.copyWith(
    extensions: const [BrandStyle.classic],
    scaffoldBackgroundColor: dark
        ? scheme.surface
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.035),
            const Color(0xFFF7F8FA),
          ),
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? scheme.surfaceContainer : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: dark ? 0.4 : 0.6),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainerHigh : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        backgroundColor: dark ? scheme.surfaceContainerHigh : Colors.white,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? scheme.surfaceContainer : Colors.white,
      indicatorColor: scheme.primaryContainer,
      elevation: 3,
      shadowColor: Colors.black26,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? scheme.surfaceContainer : Colors.white,
      indicatorColor: scheme.primaryContainer,
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

/// Colors for the Mint theme, matching the website's Mint design.
class Mint {
  static const background = Color(0xFFEEF7F3);
  static const emerald = Color(0xFF0D7A5F);
  static const emeraldSoft = Color(0xFFDFF3EA);
  static const coral = Color(0xFFE8684A);
  static const ink = Color(0xFF14261F);
  static const muted = Color(0xFF5F7169);
  static const line = Color(0xFFDCEBE4);
}

/// Palette for the light, card-based Mint theme.
class _Pastel {
  const _Pastel({
    required this.background,
    required this.primary,
    required this.primarySoft,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.tertiary,
    required this.ink,
    required this.muted,
    required this.line,
    required this.cardShadow,
    required this.brand,
  });

  final Color background;
  final Color primary;
  final Color primarySoft;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color tertiary;
  final Color ink;
  final Color muted;
  final Color line;
  final Color cardShadow;
  final BrandStyle brand;
}

/// Mint and white with emerald and coral accents, like the website.
ThemeData buildMintTheme() => _buildPastelTheme(
  const _Pastel(
    background: Mint.background,
    primary: Mint.emerald,
    primarySoft: Mint.emeraldSoft,
    onPrimaryContainer: Color(0xFF0B4D3C),
    secondary: Color(0xFF5FD0AE),
    tertiary: Mint.coral,
    ink: Mint.ink,
    muted: Mint.muted,
    line: Mint.line,
    cardShadow: Color(0xFF143C2D),
    brand: BrandStyle.mint,
  ),
);

ThemeData _buildPastelTheme(_Pastel p) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: Brightness.light,
    primary: p.primary,
    onPrimary: Colors.white,
    primaryContainer: p.primarySoft,
    onPrimaryContainer: p.onPrimaryContainer,
    secondary: p.secondary,
    tertiary: p.tertiary,
    surface: Colors.white,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    outlineVariant: p.line,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);
  final radius = BorderRadius.circular(22);

  return base.copyWith(
    extensions: [p.brand],
    scaffoldBackgroundColor: p.background,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -1.2,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: p.ink,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: p.ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: p.cardShadow.withValues(alpha: 0.25),
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: p.primary,
        selectedForegroundColor: Colors.white,
        backgroundColor: Colors.white,
        foregroundColor: p.muted,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: p.primarySoft,
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: p.primarySoft,
      elevation: 3,
      shadowColor: Colors.black26,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: p.primarySoft,
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: p.primary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

/// Light mode: Mint colors in the flat, iOS-style metric-grid layout.
ThemeData buildLightTheme() => _flatten(
  buildMintTheme(),
  brand: BrandStyle.flatMint,
  surface: Colors.white,
  line: Mint.line,
  track: const Color(0xFFE2EFE9),
  ink: Mint.ink,
  muted: Mint.muted,
  selectedChip: Mint.emeraldSoft,
);

/// Dark mode: the dark navy colors in the same flat metric-grid layout.
ThemeData buildDarkTheme() {
  final base = buildTheme(Brightness.dark);
  final scheme = base.colorScheme;
  final line = scheme.outlineVariant.withValues(alpha: 0.5);
  return _flatten(
    base,
    brand: BrandStyle(
      heroGradient: LinearGradient(
        colors: [scheme.surfaceContainer, scheme.surfaceContainer],
      ),
      heroShadow: Colors.black,
      heroInk: scheme.onSurface,
      heroPillBg: scheme.primaryContainer,
      heroPillBorder: Colors.transparent,
      heroOrbAlphaScale: 0,
      heroButtonBg: scheme.primary,
      heroButtonInk: scheme.onPrimary,
      badgeGradient: LinearGradient(colors: [scheme.primary, scheme.primary]),
      badgeInk: scheme.onPrimary,
      chartBar: BrandStyle.classic.chartBar,
      chartSelected: BrandStyle.classic.chartSelected,
      heroBorder: line,
      heroRadius: 16,
      flat: true,
    ),
    surface: scheme.surfaceContainer,
    line: line,
    track: scheme.surfaceContainerHighest,
    ink: scheme.onSurface,
    muted: scheme.onSurfaceVariant,
    selectedChip: scheme.primaryContainer,
  );
}

/// Restyles [base] as a flat, iOS-style metric grid: hairline cards, 12px
/// corners, a segmented track, and a tab bar without indicators.
ThemeData _flatten(
  ThemeData base, {
  required BrandStyle brand,
  required Color surface,
  required Color line,
  required Color track,
  required Color ink,
  required Color muted,
  required Color selectedChip,
}) {
  final scheme = base.colorScheme;
  final text = base.textTheme;
  final hairline = BorderSide(color: line);
  final corner = BorderRadius.circular(12);
  Color tab(Set<WidgetState> s) =>
      s.contains(WidgetState.selected) ? scheme.primary : muted;

  return base.copyWith(
    extensions: [brand],
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      toolbarHeight: 72,
      foregroundColor: ink,
      titleTextStyle: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: hairline,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: corner, borderSide: hairline),
      enabledBorder: OutlineInputBorder(
        borderRadius: corner,
        borderSide: hairline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: corner,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: corner),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        backgroundColor: surface,
        foregroundColor: ink,
        side: hairline,
        shape: RoundedRectangleBorder(borderRadius: corner),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: track,
        foregroundColor: muted,
        selectedBackgroundColor: surface,
        selectedForegroundColor: scheme.primary,
        side: BorderSide(color: track, width: 3),
        shape: RoundedRectangleBorder(borderRadius: corner),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surface,
      selectedColor: selectedChip,
      side: hairline,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: tab(s)),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall?.copyWith(
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: tab(s),
        ),
      ),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: surface,
      indicatorColor: selectedChip,
    ),
  );
}
