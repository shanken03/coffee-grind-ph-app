import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized Typography System for Coffee Grind PH.
///
/// Designed with a clean, modern, premium coffee-shop aesthetic:
/// - Headings, Page Titles, Section Headings, Card Titles & Statistics: **Oswald** (Bold, Semi-bold, condensed)
/// - Large Display Titles / Banners: **Bebas Neue** / **Oswald**
/// - Body Text: **Roboto** (clean & readable)
/// - UI Elements (Tabs, Buttons, Forms, Tables, Badges, Labels, Subtitles): **Inter** (Regular, Medium, Semi-bold)
class AppTextStyles {
  AppTextStyles._();

  // ===========================================================================
  // 1. HEADINGS & TITLES (Oswald - Bold & Condensed)
  // ===========================================================================

  /// Large display / hero title (e.g. Brand Banner "COFFEE GRIND PH")
  static TextStyle displayTitle({
    Color color = AppColors.darkCoffee,
    double fontSize = 24,
    double letterSpacing = 1.8,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Alternative Bebas Neue for large dashboard display titles
  static TextStyle bebasDisplay({
    Color color = AppColors.darkCoffee,
    double fontSize = 28,
    double letterSpacing = 1.2,
    FontWeight? fontWeight,
  }) {
    return GoogleFonts.bebasNeue(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Primary Page Titles (Oswald Bold, large, slightly condensed)
  static TextStyle pageTitle({
    Color color = AppColors.darkCoffee,
    double fontSize = 22,
    double letterSpacing = 0.2,
    FontWeight fontWeight = FontWeight.w700,
    double height = 1.2,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Section Headings (Oswald Semi-Bold)
  static TextStyle sectionHeading({
    Color color = AppColors.darkCoffee,
    double fontSize = 17,
    double letterSpacing = 0.2,
    FontWeight fontWeight = FontWeight.w600,
    double height = 1.25,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Card Titles (Oswald Bold, medium-sized)
  static TextStyle cardTitle({
    Color color = AppColors.darkCoffee,
    double fontSize = 15,
    double letterSpacing = 0.1,
    FontWeight fontWeight = FontWeight.w700,
    double height = 1.25,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Dialog Titles (Oswald Bold)
  static TextStyle dialogTitle({
    Color color = AppColors.darkCoffee,
    double fontSize = 18,
    double letterSpacing = 0.2,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // ===========================================================================
  // 2. DASHBOARD NUMBERS & STATISTICS (Oswald Bold - Prominent & Strong)
  // ===========================================================================

  /// Large statistic / KPI number (e.g. "₱12,450.00", "84%")
  static TextStyle statNumberLarge({
    Color color = AppColors.darkCoffee,
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -0.3,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Medium dashboard statistic / overview card metric
  static TextStyle statNumber({
    Color color = AppColors.darkCoffee,
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -0.2,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Product price tag / unit price (Oswald Bold)
  static TextStyle price({
    Color color = AppColors.darkCoffee,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0.1,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // ===========================================================================
  // 3. BODY TEXT (Roboto - Clean & Readable)
  // ===========================================================================

  /// Standard readable body text
  static TextStyle body({
    Color color = AppColors.darkCoffee,
    double fontSize = 14,
    double height = 1.45,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.roboto(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  /// Large body text
  static TextStyle bodyLarge({
    Color color = AppColors.darkCoffee,
    double fontSize = 16,
    double height = 1.5,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.roboto(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  /// Small body text
  static TextStyle bodySmall({
    Color color = AppColors.textSecondary,
    double fontSize = 12,
    double height = 1.4,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.roboto(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  // ===========================================================================
  // 4. UI ELEMENTS, CONTROLS, LABELS & TABLES (Inter)
  // ===========================================================================

  /// Navigation bar & tab labels (Inter Medium)
  static TextStyle navLabel({
    Color color = AppColors.textSecondary,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Selected navigation tab label (Inter Semi-Bold)
  static TextStyle navLabelSelected({
    Color color = AppColors.forestGreen,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Primary button text (Inter Semi-Bold)
  static TextStyle button({
    Color color = Colors.white,
    double fontSize = 14,
    double letterSpacing = 0.2,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Small action button text (Inter Semi-Bold)
  static TextStyle buttonSmall({
    Color color = Colors.white,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.2,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Subtitles, descriptions & explanatory notes (Inter Regular)
  static TextStyle subtitle({
    Color color = AppColors.textSecondary,
    double fontSize = 13,
    double height = 1.35,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Captions, metadata, timestamps (Inter Regular)
  static TextStyle caption({
    Color color = AppColors.textSecondary,
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Form field label (Inter Medium)
  static TextStyle formLabel({
    Color color = AppColors.textPrimary,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Form input text (Inter Medium)
  static TextStyle inputField({
    Color color = AppColors.textPrimary,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Form input hint text (Inter Regular)
  static TextStyle inputHint({
    Color color = AppColors.textSecondary,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Table headers & column titles (Inter Semi-Bold)
  static TextStyle tableHeader({
    Color color = AppColors.darkCoffee,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Table cells & inventory data (Inter Regular / Medium)
  static TextStyle tableCell({
    Color color = AppColors.darkCoffee,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Status badge & chip text (Inter Semi-Bold)
  static TextStyle badge({
    Color color = AppColors.darkCoffee,
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // ===========================================================================
  // 5. GLOBAL MATERIAL 3 TEXT THEME BUILDER
  // ===========================================================================

  /// Builds a complete Flutter [TextTheme] adhering to the Oswald / Roboto / Inter hierarchy.
  static TextTheme buildTextTheme() {
    return TextTheme(
      // Display: Oswald / Bebas Neue style for massive dashboard headers
      displayLarge: GoogleFonts.oswald(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: AppColors.darkCoffee,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.oswald(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.darkCoffee,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.oswald(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.darkCoffee,
        letterSpacing: -0.2,
      ),

      // Headlines: Oswald Bold
      headlineLarge: GoogleFonts.oswald(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.darkCoffee,
        letterSpacing: 0.1,
      ),
      headlineMedium: GoogleFonts.oswald(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.darkCoffee,
        letterSpacing: 0.2,
      ),
      headlineSmall: GoogleFonts.oswald(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkCoffee,
        letterSpacing: 0.2,
      ),

      // Titles: Oswald (Large = Page Title, Medium = Section Heading, Small = Card Title)
      titleLarge: GoogleFonts.oswald(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.darkCoffee,
        letterSpacing: 0.2,
      ),
      titleMedium: GoogleFonts.oswald(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.darkCoffee,
        letterSpacing: 0.1,
      ),
      titleSmall: GoogleFonts.oswald(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.darkCoffee,
        letterSpacing: 0.1,
      ),

      // Body: Roboto (Clean & Readable)
      bodyLarge: GoogleFonts.roboto(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.darkCoffee,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.roboto(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.darkCoffee,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.35,
      ),

      // Labels: Inter (Interactive UI, Buttons, Tabs, Chips)
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.darkCoffee,
        letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}

