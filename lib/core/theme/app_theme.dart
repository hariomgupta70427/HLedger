import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Color Palette - Light Theme
  static const Color primaryLight = Color(0xFF00BFA6);
  static const Color primaryDark = Color(0xFF00E5CC);
  static const Color accentLight = Color(0xFF6C63FF);
  static const Color accentDark = Color(0xFF8B85FF);
  
  // Light Theme Colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color cardLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF1A1D29);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color dividerLight = Color(0xFFE5E7EB);
  
  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color dividerDark = Color(0xFF334155);
  
  // Chat bubble colors
  static const Color userBubbleLight = Color(0xFF00BFA6);
  static const Color aiBubbleLight = Color(0xFFF1F5F9);
  static const Color userBubbleDark = Color(0xFF00E5CC);
  static const Color aiBubbleDark = Color(0xFF1E293B);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  // Priority colors
  static const Color priorityHigh = Color(0xFFEF4444);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityLow = Color(0xFF10B981);

  // Backward compatibility aliases (for old code)
  static const Color background = backgroundLight;
  static const Color accent = primaryLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color cardBackground = cardLight;
  static const Color divider = dividerLight;
  static const Color userChatBubble = userBubbleLight;
  static const Color aiChatBubble = aiBubbleLight;

  // Get text theme with Google Fonts
  static TextTheme _getTextTheme(bool isDark) {
    final Color textColor = isDark ? textPrimaryDark : textPrimaryLight;
    return GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textColor),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textColor),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: isDark ? textSecondaryDark : textSecondaryLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: primaryLight,
      textTheme: _getTextTheme(false),
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: accentLight,
        surface: surfaceLight,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLight,
        foregroundColor: textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: primaryLight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dividerLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.inter(
          color: textSecondaryLight,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondaryLight,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dividerLight),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryLight,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimaryLight,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerLight,
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryLight;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryLight;
          return textSecondaryLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryLight;
          return dividerLight;
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryDark,
      textTheme: _getTextTheme(true),
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: accentDark,
        surface: surfaceDark,
        error: error,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimaryDark,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: primaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primaryDark, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.inter(
          color: textSecondaryDark,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondaryDark,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dividerDark),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryDark,
        unselectedItemColor: textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceDark,
        contentTextStyle: GoogleFonts.inter(color: textPrimaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerDark,
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryDark;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryDark;
          return textSecondaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryDark;
          return dividerDark;
        }),
      ),
    );
  }
}