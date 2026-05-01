import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nextone/constants/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.primary,
        onBackground: AppColors.primary,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final defaultTextTheme =
        GoogleFonts.interTextTheme(baseTheme.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return baseTheme.copyWith(
      textTheme: defaultTextTheme.copyWith(
        displayLarge: defaultTextTheme.displayLarge?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        displayMedium: defaultTextTheme.displayMedium?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        displaySmall: defaultTextTheme.displaySmall?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        headlineLarge: defaultTextTheme.headlineLarge?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        headlineMedium: defaultTextTheme.headlineMedium?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        headlineSmall: defaultTextTheme.headlineSmall?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        titleLarge: defaultTextTheme.titleLarge?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        titleMedium: defaultTextTheme.titleMedium?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        titleSmall: defaultTextTheme.titleSmall?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        bodyMedium: defaultTextTheme.bodyMedium?.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
          color: Colors.grey[700],
        ),
        bodySmall: defaultTextTheme.bodySmall?.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
          color: Colors.grey[600],
        ),
        labelLarge: defaultTextTheme.labelLarge?.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 1.2,
          color: Colors.grey[600],
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleTextStyle: defaultTextTheme.titleLarge?.copyWith(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        prefixIconColor: Colors.grey[600],
        suffixIconColor: Colors.grey[600],
        hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
