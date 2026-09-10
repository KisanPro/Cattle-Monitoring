import 'package:flutter/material.dart';

class AppTheme {
  // Premium Brand Colors
  static const Color primary = Color(0xFF006D60); // Deep Teal
  static const Color primaryLight = Color(0xFFE6F3F1);
  static const Color primaryGreen = Color(0xFF006D60);
  static const Color primaryTeal = Color(0xFF005D56);
  static const Color accentTeal = Color(0xFF00796B);
  static const Color mintGreen = Color(0xFF00BFA5);
  static const Color accentMint = Color(0xFF00BFA5); // Mint Green
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFFFA000); // Morning shift amber
  static const Color accentIndigo = Color(0xFF3F51B5); // Evening shift indigo
  static const Color accentRose = Color(0xFFF50057); // Warnings & Alerts
  static const Color errorColor = Color(0xFFEF4444);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color starOrange = Color(0xFFF59E0B);
  
  static const Color morningColor = Color(0xFFFFA000); // Amber morning
  static const Color eveningColor = Color(0xFF3F51B5); // Indigo evening
  static const Color orangeAccent = Color(0xFFF59E0B); // Orange cow avatar
  
  // Backgrounds
  static const Color backgroundLight = Color(0xFFFAF7E8); // Warm Cream background
  static const Color surfaceLight = Color(0xFFFFFFFF); // White cards
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputFillLight = Color(0xFFF6F3E3); // Light warm input fill
  static const Color fieldFill = Color(0xFFF6F3E3);
  static const Color borderLight = Color(0xFFEBE8D8); // Subtle border
  
  // Dark Mode
  static const Color backgroundDark = Color(0xFF0A1513); // Very dark teal
  static const Color surfaceDark = Color(0xFF122220); // Dark teal card
  static const Color inputFillDark = Color(0xFF0E1A18); // Input box dark
  static const Color borderDark = Color(0xFF1E3834); // Teal border dark
  
  static const Color textDark = Color(0xFFE0F2F1);
  static const Color textLight = Color(0xFF1B2D2A); // Dark charcoal for readability
  static const Color textMuted = Color(0xFF708581); // Muted slate-green
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color darkText = Color(0xFF1B2D2A);
  static const Color lightText = Color(0xFF6B7280);

  // Multi-gradient visualizers
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient morningGradient = LinearGradient(
    colors: [accentAmber, Color(0xFFFF6D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient eveningGradient = LinearGradient(
    colors: [accentIndigo, Color(0xFF651FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintGradient = LinearGradient(
    colors: [accentMint, Color(0xFF1DE9B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient profitGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration cardDecoration({
    required bool isDark,
    Color? customColor,
    double borderRadius = 18.0,
    bool showShadow = true,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: customColor ?? (isDark ? surfaceDark : surfaceLight),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? borderDark : borderLight.withOpacity(0.4),
        width: borderWidth,
      ),
      boxShadow: showShadow
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.035),
                blurRadius: 12.0,
                offset: const Offset(0, 5),
              ),
            ]
          : null,
    );
  }

  static TextStyle headlineStyle({required bool isDark, double size = 22}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: isDark ? textDark : textLight,
      letterSpacing: -0.5,
    );
  }

  static TextStyle subheadStyle({required bool isDark, double size = 13}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.bold,
      color: isDark ? primaryLight.withOpacity(0.8) : primary,
      letterSpacing: 0.8,
    );
  }

  static TextStyle bodyStyle({required bool isDark, double size = 14, bool isMuted = false}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: isMuted 
          ? textMuted 
          : (isDark ? textDark : textLight),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accentMint,
        surface: surfaceLight,
        error: accentRose,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillLight,
        labelStyle: const TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRose, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentMint,
        surface: surfaceDark,
        error: accentRose,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillDark,
        labelStyle: const TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRose, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
