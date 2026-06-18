import 'package:flutter/material.dart';
import 'app_theme_colors.dart';
export 'app_theme_colors.dart';

// ── Legacy static refs (dark only) — use context.colors in widgets ───────────
class AppColors {
  static const background  = Color(0xFF09090B);
  static const surface     = Color(0xFF18181B);
  static const surfaceAlt  = Color(0xFF27272A);
  static const border      = Color(0xFF3F3F46);
  static const textPrimary = Color(0xFFF4F4F5);
  static const textSecond  = Color(0xFFA1A1AA);
  static const textMuted   = Color(0xFF71717A);
  static const emerald     = Color(0xFF10B981);
  static const emeraldDim  = Color(0xFF059669);
  static const red         = Color(0xFFEF4444);
  static const orange      = Color(0xFFF97316);
}

// ── Dark theme ────────────────────────────────────────────────────────────────

final appTheme = _buildTheme(AppThemeColors.dark(), Brightness.dark);

// ── Light theme ───────────────────────────────────────────────────────────────

final appLightTheme = _buildTheme(AppThemeColors.light(), Brightness.light);

// ── Builder ───────────────────────────────────────────────────────────────────

ThemeData _buildTheme(AppThemeColors c, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    extensions: [c],
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary:          c.emerald,
      onPrimary:        Colors.white,
      secondary:        c.emerald,
      onSecondary:      Colors.white,
      error:            c.red,
      onError:          Colors.white,
      surface:          c.surface,
      onSurface:        c.textPrimary,
      surfaceContainerHigh: c.surfaceAlt,
      outline:          c.textMuted,
      outlineVariant:   c.border,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: c.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.surface,
      selectedItemColor: c.emerald,
      unselectedItemColor: c.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: c.surfaceAlt,
      thickness: 1,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.surfaceAlt),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.emerald),
      ),
      hintStyle: TextStyle(color: c.textMuted),
      labelStyle: TextStyle(color: c.textSecond),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: c.emerald,
      labelColor: c.emerald,
      unselectedLabelColor: c.textMuted,
      dividerColor: c.surfaceAlt,
    ),
    textTheme: TextTheme(
      headlineLarge:  TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
      titleLarge:     TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
      titleMedium:    TextStyle(color: c.textPrimary, fontWeight: FontWeight.w500),
      bodyLarge:      TextStyle(color: c.textPrimary),
      bodyMedium:     TextStyle(color: c.textSecond),
      bodySmall:      TextStyle(color: c.textMuted),
      labelLarge:     TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.emerald,
      foregroundColor: Colors.white,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: isDark ? c.surface : Colors.white,
    ),
  );
}
