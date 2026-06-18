import 'package:flutter/material.dart';

/// Extensão de tema com cores para dark e light mode.
/// Uso: `context.colors.surface`
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecond;
  final Color textMuted;
  final Color emerald;
  final Color emeraldDim;
  final Color red;
  final Color orange;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecond,
    required this.textMuted,
    required this.emerald,
    required this.emeraldDim,
    required this.red,
    required this.orange,
  });

  factory AppThemeColors.dark() => const AppThemeColors(
        background:  Color(0xFF09090B),
        surface:     Color(0xFF18181B),
        surfaceAlt:  Color(0xFF27272A),
        border:      Color(0xFF3F3F46),
        textPrimary: Color(0xFFF4F4F5),
        textSecond:  Color(0xFFA1A1AA),
        textMuted:   Color(0xFF71717A),
        emerald:     Color(0xFF10B981),
        emeraldDim:  Color(0xFF059669),
        red:         Color(0xFFEF4444),
        orange:      Color(0xFFF97316),
      );

  factory AppThemeColors.light() => const AppThemeColors(
        background:  Color(0xFFF9FAFB),
        surface:     Color(0xFFFFFFFF),
        surfaceAlt:  Color(0xFFF3F4F6),
        border:      Color(0xFFE5E7EB),
        textPrimary: Color(0xFF111827),
        textSecond:  Color(0xFF4B5563),
        textMuted:   Color(0xFF9CA3AF),
        emerald:     Color(0xFF059669),
        emeraldDim:  Color(0xFF047857),
        red:         Color(0xFFDC2626),
        orange:      Color(0xFFEA580C),
      );

  @override
  AppThemeColors copyWith({
    Color? background, Color? surface, Color? surfaceAlt, Color? border,
    Color? textPrimary, Color? textSecond, Color? textMuted,
    Color? emerald, Color? emeraldDim, Color? red, Color? orange,
  }) =>
      AppThemeColors(
        background:  background  ?? this.background,
        surface:     surface     ?? this.surface,
        surfaceAlt:  surfaceAlt  ?? this.surfaceAlt,
        border:      border      ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecond:  textSecond  ?? this.textSecond,
        textMuted:   textMuted   ?? this.textMuted,
        emerald:     emerald     ?? this.emerald,
        emeraldDim:  emeraldDim  ?? this.emeraldDim,
        red:         red         ?? this.red,
        orange:      orange      ?? this.orange,
      );

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      background:  Color.lerp(background,  other.background,  t)!,
      surface:     Color.lerp(surface,     other.surface,     t)!,
      surfaceAlt:  Color.lerp(surfaceAlt,  other.surfaceAlt,  t)!,
      border:      Color.lerp(border,      other.border,      t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecond:  Color.lerp(textSecond,  other.textSecond,  t)!,
      textMuted:   Color.lerp(textMuted,   other.textMuted,   t)!,
      emerald:     Color.lerp(emerald,     other.emerald,     t)!,
      emeraldDim:  Color.lerp(emeraldDim,  other.emeraldDim,  t)!,
      red:         Color.lerp(red,         other.red,         t)!,
      orange:      Color.lerp(orange,      other.orange,      t)!,
    );
  }
}

extension AppThemeColorsX on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.dark();
}
