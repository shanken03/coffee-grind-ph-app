import 'package:flutter/material.dart';

/// Coffee Grind PH 60/30/10 Warm Premium Coffee Design System Palette.
///
/// Refined with an artisanal, modern, clean, and premium coffee shop aesthetic.
class AppColors {
  AppColors._();

  // 60% — Warm Cream Main Backgrounds & Surfaces
  static const Color warmCream = Color(0xFFF9F6F0);
  static const Color scaffoldBackground = Color(0xFFF9F6F0);
  static const Color darkBackground = Color(0xFFF9F6F0); // Warm cream background alias

  // 30% — Rich Dark Coffee Brown (Navbars, Headers, Primary Buttons, Headings)
  static const Color darkCoffee = Color(0xFF4A3025);
  static const Color primaryCoffee = Color(0xFF4A3025);
  static const Color espressoDark = Color(0xFF2E1C14); // Deep roasted espresso accent
  static const Color caramelAccent = Color(0xFF4A3025); // Primary Dark Coffee alias
  static const Color warmBronze = Color(0xFF9E6B38); // Warm artisanal bronze highlight

  // 10% Accents & Statuses
  static const Color forestGreen = Color(0xFF2E7D32); // Positive status & healthy stock
  static const Color forestGreenAccent = Color(0xFF388E3C);
  static const Color latteBeige = Color(0xFFE8DED1); // Subtle borders, panels & dividers
  static const Color borderSubtle = Color(0xFFEFE8DE); // Soft latte border alias
  static const Color amber = Color(0xFFD97706); // Warm amber (low-stock warning/pending)
  static const Color mutedRed = Color(0xFFC62828); // Vibrant muted red (out-of-stock/error)

  // Supporting Surfaces & Cards
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF); // White cards
  static const Color cardSurfaceLight = Color(0xFFFAF7F2); // Subtle warm container
  static const Color containerMuted = Color(0xFFF2ECE3); // Pill & badge container background

  // Typography Hierarchy
  static const Color textPrimary = Color(0xFF2E1C14); // Deep espresso text on light
  static const Color textDark = Color(0xFF1E1815); // Deep espresso text
  static const Color textSecondary = Color(0xFF6B635B); // Warm gray for body/descriptions
  static const Color textMuted = Color(0xFF9C948C); // Muted warm gray
  static const Color caramelLight = Color(0xFF77716B);

  // Status & Indicator Colors
  static const Color statusApproved = Color(0xFF2E7D32); // Forest Green (healthy stock/success)
  static const Color statusCompleted = Color(0xFF2E7D32); // Forest Green
  static const Color statusPending = Color(0xFFD97706); // Amber (low-stock warning/pending)
  static const Color statusWarning = Color(0xFFD97706); // Amber
  static const Color statusRejected = Color(0xFFC62828); // Muted Red (out-of-stock/error)
  static const Color statusReceived = Color(0xFF2E7D32); // Forest Green

  // Subtle Modern Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF3E2723).withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: const Color(0xFF3E2723).withValues(alpha: 0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF3E2723).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get floatingBarShadow => [
    BoxShadow(
      color: const Color(0xFF2E1C14).withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}
