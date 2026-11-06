import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.warmCream,
      colorScheme: const ColorScheme.light(
        primary: AppColors.forestGreen,
        onPrimary: Colors.white,
        secondary: AppColors.latteBeige,
        onSecondary: AppColors.darkCoffee,
        surface: AppColors.surfaceWhite,
        onSurface: AppColors.textPrimary,
        error: AppColors.statusRejected,
        onError: Colors.white,
      ),
      textTheme: AppTextStyles.buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.darkCoffee,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.pageTitle(
          color: AppColors.darkCoffee,
          fontSize: 18,
          letterSpacing: 0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkCoffee),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.forestGreen,
        labelColor: AppColors.forestGreen,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppTextStyles.navLabel(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: AppTextStyles.navLabel(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceWhite,
        selectedItemColor: AppColors.forestGreen,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: AppTextStyles.navLabelSelected(fontSize: 11),
        unselectedLabelStyle: AppTextStyles.navLabel(fontSize: 11, fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.latteBeige, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 6,
        titleTextStyle: AppTextStyles.dialogTitle(),
        contentTextStyle: AppTextStyles.body(color: AppColors.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.latteBeige, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceWhite,
        modalBackgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkCoffee,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.button(
            color: Colors.white,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkCoffee,
          side: const BorderSide(color: AppColors.darkCoffee, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.button(
            color: AppColors.darkCoffee,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkCoffee,
          textStyle: AppTextStyles.button(
            color: AppColors.darkCoffee,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.latteBeige),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.latteBeige),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkCoffee, width: 1.5),
        ),
        hintStyle: AppTextStyles.inputHint(),
        labelStyle: AppTextStyles.formLabel(),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceWhite,
        selectedColor: AppColors.darkCoffee,
        secondarySelectedColor: AppColors.darkCoffee,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.latteBeige, width: 1),
        ),
        labelStyle: AppTextStyles.badge(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: AppTextStyles.badge(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.latteBeige,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCoffee,
        contentTextStyle: AppTextStyles.subtitle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
