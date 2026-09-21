import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static const heading = TextStyle(fontSize: 36, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: AppColors.text);
  static const title = TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.text);
  static const section = TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w700, color: AppColors.text);
  static const body = TextStyle(fontSize: 15, height: 1.45, color: AppColors.secondaryText);
  static const label = TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: AppColors.text);
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryLavender, brightness: Brightness.light).copyWith(
      primary: AppColors.primaryLavender,
      onPrimary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.text,
    ),
    textTheme: const TextTheme(
      headlineMedium: AppTypography.heading,
      titleLarge: AppTypography.title,
      titleMedium: AppTypography.section,
      bodyMedium: AppTypography.body,
      labelLarge: AppTypography.button,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.softGray)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.softGray)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.primaryLavender, width: 1.5)),
    ),
  );
}
