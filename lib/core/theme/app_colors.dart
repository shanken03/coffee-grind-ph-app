import 'package:flutter/material.dart';

/// Coffee Grind PH 60/30/10 Warm Premium Coffee Design System Palette
class AppColors {
  AppColors._();

  // 60% — Warm Cream Main Backgrounds & Surfaces
  static const Color warmCream = Color(0xFFF7F3ED);
  static const Color scaffoldBackground = Color(0xFFF7F3ED);
  static const Color darkBackground = Color(0xFFF7F3ED); // Warm cream background alias

  // 30% — Dark Coffee Brown (Navbars, Headers, Primary Buttons, Headings)
  static const Color darkCoffee = Color(0xFF4A3025);
  static const Color primaryCoffee = Color(0xFF4A3025);
  static const Color caramelAccent = Color(0xFF4A3025); // Primary Dark Coffee alias

  // 10% Accents
  static const Color forestGreen = Color(0xFF367D43); // Positive status & healthy stock
  static const Color latteBeige = Color(0xFFE8DED1); // Subtle borders, panels & dividers
  static const Color borderSubtle = Color(0xFFE8DED1); // Latte Beige border alias

  // Supporting Colors
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF); // White cards
  static const Color cardSurfaceLight = Color(0xFFFAF7F2); // Subtle warm container

  static const Color textPrimary = Color(0xFF4A3025); // Dark Coffee text on cream/white
  static const Color textDark = Color(0xFF1E1815); // Deep espresso text
  static const Color textSecondary = Color(0xFF77716B); // Warm gray for body/descriptions
  static const Color textMuted = Color(0xFF9E968F); // Muted warm gray
  static const Color caramelLight = Color(0xFF77716B);

  // Status & Indicator Colors
  static const Color forestGreenAccent = Color(0xFF367D43);
  static const Color amber = Color(0xFFC58B36); // Amber (low-stock warning/pending)
  static const Color mutedRed = Color(0xFFB94A48); // Muted Red (out-of-stock/error)
  static const Color statusApproved = Color(0xFF367D43); // Forest Green (healthy stock/success)
  static const Color statusCompleted = Color(0xFF367D43); // Forest Green
  static const Color statusPending = Color(0xFFC58B36); // Amber (low-stock warning/pending)
  static const Color statusWarning = Color(0xFFC58B36); // Amber
  static const Color statusRejected = Color(0xFFB94A48); // Muted Red (out-of-stock/error)
  static const Color statusReceived = Color(0xFF367D43); // Forest Green
}
