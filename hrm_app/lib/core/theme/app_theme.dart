import 'package:flutter/material.dart';

/// Shared colors for HRM Cafe. Status foregrounds support small text on soft fills.
class AppColors {
  static const primaryDark = Color(0xFF30231F);
  static const primary = Color(0xFF614638);
  static const primaryLight = Color(0xFF80614E);
  static const primaryMuted = Color(0xFF74665D);
  static const primarySubtle = Color(0xFFF1EAE4);
  static const accent = Color(0xFF9A581B);
  static const accentLight = Color(0xFFFFEEDB);
  static const accentWarm = Color(0xFFE3BC8C);
  static const accentHover = Color(0xFF784315);
  static const amberBadge = Color(0xFFF5D7AC);
  static const background = Color(0xFFFCFAF8);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF3F0EB);
  static const card = Colors.white;
  static const cardWarm = Color(0xFFFFFCF8);
  static const border = Color(0xFFE5E0D9);
  static const borderLight = Color(0xFFEEEAE4);
  static const textPrimary = Color(0xFF282622);
  static const textSecondary = Color(0xFF645E56);
  static const textMuted = Color(0xFF756D63);
  static const textInverse = Colors.white;
  static const success = Color(0xFF16734B);
  static const successBg = Color(0xFFECF7F0);
  static const successBorder = Color(0xFFCBE5D5);
  static const warning = Color(0xFF925407);
  static const warningBg = Color(0xFFFFF5E3);
  static const warningBorder = Color(0xFFEEDDAD);
  static const error = Color(0xFFB93838);
  static const errorBg = Color(0xFFFFEFEF);
  static const errorBorder = Color(0xFFF0CCCC);
  static const info = Color(0xFF315EA0);
  static const infoBg = Color(0xFFEDF3FC);
  static const infoBorder = Color(0xFFCFDCF0);
  static List<BoxShadow> get cardShadow => const [];
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: primaryDark.withValues(alpha: .06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> get primaryGlow => const [];
}

class AppTheme {
  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'HRMSans',
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    ButtonStyle button(Color? background, Color foreground) =>
        ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'HRMSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            headlineMedium: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'HRMSans',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            titleLarge: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'HRMSans',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'HRMSans',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'HRMSans',
              fontSize: 16,
              height: 1.5,
            ),
            bodyMedium: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'HRMSans',
              fontSize: 14,
              height: 1.5,
            ),
            bodySmall: const TextStyle(
              fontFamily: 'HRMSans',
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'HRMSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button(AppColors.primary, Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button(AppColors.primary, Colors.white),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button(null, AppColors.primary).copyWith(
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.border),
          ),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary, 2),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 2),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIconColor: AppColors.primaryMuted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarySubtle,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'HRMSans',
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        height: 76,
        elevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySubtle,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
    );
  }
}
