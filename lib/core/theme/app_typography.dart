import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle get displayHeader => GoogleFonts.playfairDisplay(
    color: AppColors.textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static TextStyle get titleMedium => GoogleFonts.playfairDisplay(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get bodyPrimary => GoogleFonts.dmSans(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static TextStyle get bodySecondary => GoogleFonts.dmSans(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static TextStyle get labelChip => GoogleFonts.dmSans(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  static TextStyle get buttonText => GoogleFonts.dmSans(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static TextTheme get textTheme => TextTheme(
    displayLarge: GoogleFonts.playfairDisplay(
      color: AppColors.textPrimary,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: GoogleFonts.playfairDisplay(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: GoogleFonts.dmSans(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    bodyMedium: GoogleFonts.dmSans(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    labelLarge: GoogleFonts.dmSans(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
  );
}
