import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Farm palette: parchment, wood, grass and wheat. A "night" variant is used
/// for dark mode.
@immutable
class FarmPalette extends ThemeExtension<FarmPalette> {
  const FarmPalette({
    required this.background,
    required this.panel,
    required this.panelAlt,
    required this.wood,
    required this.woodDark,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.grass,
    required this.grassDark,
    required this.wheat,
    required this.sky,
    required this.berry,
    required this.shadow,
  });

  final Color background, panel, panelAlt, wood, woodDark, outline, text, textMuted;
  final Color grass, grassDark, wheat, sky, berry, shadow;

  static const day = FarmPalette(
    background: Color(0xFFF3E2B8),
    panel: Color(0xFFFFF4D6),
    panelAlt: Color(0xFFF8E6BC),
    wood: Color(0xFFB8763A),
    woodDark: Color(0xFF7E4B22),
    outline: Color(0xFF4A2C17),
    text: Color(0xFF3B2416),
    textMuted: Color(0xFF8A6A4A),
    grass: Color(0xFF6BAF4A),
    grassDark: Color(0xFF3F7D2A),
    wheat: Color(0xFFE9B84A),
    sky: Color(0xFF7FC4E4),
    berry: Color(0xFFC8553D),
    shadow: Color(0x664A2C17),
  );

  static const night = FarmPalette(
    background: Color(0xFF1C2421),
    panel: Color(0xFF2B3530),
    panelAlt: Color(0xFF34413A),
    wood: Color(0xFF8A5A2F),
    woodDark: Color(0xFF5C3A1C),
    outline: Color(0xFF0E1210),
    text: Color(0xFFF3E6C4),
    textMuted: Color(0xFFB4A88A),
    grass: Color(0xFF7CC25A),
    grassDark: Color(0xFF4E8F35),
    wheat: Color(0xFFF0C55C),
    sky: Color(0xFF6FA8C8),
    berry: Color(0xFFE0735A),
    shadow: Color(0x99000000),
  );

  @override
  FarmPalette copyWith() => this;

  @override
  FarmPalette lerp(FarmPalette? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension FarmPaletteX on BuildContext {
  FarmPalette get farm => Theme.of(this).extension<FarmPalette>()!;
}

/// Pixel font for the current language (see [L10n.fontFamily]).
String get pixelFont => L10n.i.fontFamily;

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? FarmPalette.day : FarmPalette.night;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.grassDark,
    onPrimary: Colors.white,
    secondary: p.wood,
    onSecondary: Colors.white,
    tertiary: p.wheat,
    onTertiary: p.text,
    error: p.berry,
    onError: Colors.white,
    surface: p.panel,
    onSurface: p.text,
    surfaceContainerHighest: p.panelAlt,
    outline: p.outline,
  );
  const square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: pixelFont,
    fontFamilyFallback: const ['Tiny5', 'Pixelify'],
    scaffoldBackgroundColor: p.background,
    extensions: [p],
  );
  return base.copyWith(
    textTheme: _noLigatures(base.textTheme.apply(bodyColor: p.text, displayColor: p.text, fontFamily: pixelFont)),
    appBarTheme: AppBarTheme(
      backgroundColor: p.wood,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFeatures: _noLiga, fontFamily: pixelFont, fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
      shape: Border(bottom: BorderSide(color: p.outline, width: 3)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.woodDark,
      indicatorColor: p.wheat,
      indicatorShape: square,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: pixelFont,
            fontSize: 12,
            color: s.contains(WidgetState.selected) ? p.wheat : Colors.white70,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.outline : Colors.white70,
          )),
    ),
    cardTheme: CardThemeData(
      color: p.panel,
      shape: RoundedRectangleBorder(side: BorderSide(color: p.outline, width: 2)),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.panel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: p.outline, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: p.outline, width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: p.grassDark, width: 3)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.grassDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(side: BorderSide(color: p.outline, width: 2)),
        textStyle: TextStyle(fontFeatures: _noLiga, fontFamily: pixelFont, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.panel,
        shape: square,
        side: BorderSide(color: p.outline, width: 2),
        textStyle: TextStyle(fontFeatures: _noLiga, fontFamily: pixelFont, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.grassDark, shape: square),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(side: BorderSide(color: p.outline, width: 1.5)),
      backgroundColor: p.panel,
      selectedColor: p.wheat,
      labelStyle: TextStyle(fontFeatures: _noLiga, fontFamily: pixelFont, color: p.text, fontSize: 13),
      side: BorderSide(color: p.outline, width: 1.5),
      showCheckmark: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.panel,
      shape: RoundedRectangleBorder(side: BorderSide(color: p.outline, width: 3)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.panel,
      shape: Border(top: BorderSide(color: p.outline, width: 3)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.outline,
      contentTextStyle: TextStyle(fontFeatures: _noLiga, fontFamily: pixelFont, color: p.wheat, fontSize: 15),
      shape: square,
      behavior: SnackBarBehavior.floating,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(),
      side: BorderSide(color: p.outline, width: 2),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.grassDark : p.panel),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.wheat : p.panel),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.grassDark : p.textMuted),
      trackOutlineColor: WidgetStatePropertyAll(p.outline),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.grassDark,
      inactiveTrackColor: p.panelAlt,
      thumbColor: p.wheat,
      trackShape: const RectangularSliderTrackShape(),
      thumbShape: const _SquareThumb(),
    ),
    dividerTheme: DividerThemeData(color: p.outline.withValues(alpha: 0.35), thickness: 1.5),
    listTileTheme: ListTileThemeData(iconColor: p.woodDark, textColor: p.text),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicator: BoxDecoration(color: p.woodDark, border: Border(bottom: BorderSide(color: p.wheat, width: 3))),
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontFeatures: _noLiga, fontFamily: pixelFont, fontSize: 15, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFeatures: _noLiga, fontFamily: pixelFont, fontSize: 15),
      dividerHeight: 0,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        side: WidgetStatePropertyAll(BorderSide(color: p.outline, width: 2)),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.wheat : p.panel),
        foregroundColor: WidgetStatePropertyAll(p.text),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.grassDark, linearTrackColor: p.panelAlt),
  );
}

/// Pixelify Sans ships an "fi" ligature that looks broken at small sizes.
const _noLiga = [FontFeature.disable('liga'), FontFeature.disable('clig')];

TextTheme _noLigatures(TextTheme t) {
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFeatures: _noLiga);
  return t.copyWith(
    displayLarge: f(t.displayLarge), displayMedium: f(t.displayMedium), displaySmall: f(t.displaySmall),
    headlineLarge: f(t.headlineLarge), headlineMedium: f(t.headlineMedium), headlineSmall: f(t.headlineSmall),
    titleLarge: f(t.titleLarge), titleMedium: f(t.titleMedium), titleSmall: f(t.titleSmall),
    bodyLarge: f(t.bodyLarge), bodyMedium: f(t.bodyMedium), bodySmall: f(t.bodySmall),
    labelLarge: f(t.labelLarge), labelMedium: f(t.labelMedium), labelSmall: f(t.labelSmall),
  );
}

class _SquareThumb extends SliderComponentShape {
  const _SquareThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(18, 18);
  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final rect = Rect.fromCenter(center: center, width: 18, height: 18);
    context.canvas.drawRect(rect, Paint()..color = sliderTheme.thumbColor ?? Colors.amber);
    context.canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF4A2C17));
  }
}
