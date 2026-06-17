import 'package:flutter/material.dart';

class AppColors {
  static const background  = Color(0xFF09090B); // zinc-950
  static const surface     = Color(0xFF18181B); // zinc-900
  static const surfaceAlt  = Color(0xFF27272A); // zinc-800
  static const border      = Color(0xFF3F3F46); // zinc-700
  static const textPrimary = Color(0xFFF4F4F5); // zinc-100
  static const textSecond  = Color(0xFFA1A1AA); // zinc-400
  static const textMuted   = Color(0xFF71717A); // zinc-500
  static const emerald     = Color(0xFF10B981); // emerald-500
  static const emeraldDim  = Color(0xFF059669); // emerald-600
  static const red         = Color(0xFFEF4444); // red-500
  static const orange      = Color(0xFFF97316); // orange-500
}

final appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    surface:   AppColors.surface,
    primary:   AppColors.emerald,
    secondary: AppColors.emerald,
    error:     AppColors.red,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: AppColors.textPrimary),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.emerald,
    unselectedItemColor: AppColors.textMuted,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.surfaceAlt),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceAlt,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.emerald),
    ),
    hintStyle: const TextStyle(color: AppColors.textMuted),
    labelStyle: const TextStyle(color: AppColors.textSecond),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(color: AppColors.textPrimary),
    bodyMedium: TextStyle(color: AppColors.textSecond),
    bodySmall: TextStyle(color: AppColors.textMuted),
    labelLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.surfaceAlt,
    thickness: 1,
  ),
);
