import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors matched to screenshots
  static const Color primaryTeal = Color(0xFF006660);  // High fidelity deep teal
  static const Color accentTeal = Color(0xFF0B6655);   // Rich secondary teal
  static const Color warmBg = Color(0xFFF9F6ED);       // Warm cream scaffold background
  static const Color fieldFill = Color(0xFFF3EFE3);     // Warm beige input fields background
  static const Color darkText = Color(0xFF1E332F);     // Deep green-grey charcoal text
  static const Color lightText = Color(0xFF6A7E7A);    // Muted grey-green text
  static const Color cardBg = Colors.white;            // Pure white card background
  static const Color badgeBg = Color(0xFFFEF9EB);      // Light yellow background for cards
  static const Color starOrange = Color(0xFFFFB300);   // Golden orange for star badges
  static const Color dangerRed = Color(0xFF8B0000);    // Crimson red for Close Preview button

  // Legacy/compatibility colors matching screenshots
  static const Color primaryGreen = primaryTeal;
  static const Color accentGreen = accentTeal;
  static const Color mintGreen = Color(0xFFE8F5E9);
  static const Color warningColor = starOrange;
  static const Color errorColor = dangerRed;


  // Smooth gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryTeal, Color(0xFF0C8A81)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryTeal,
      scaffoldBackgroundColor: warmBg,
      colorScheme: ColorScheme.light(
        primary: primaryTeal,
        secondary: accentTeal,
        background: warmBg,
        surface: cardBg,
        error: dangerRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: darkText,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: darkText,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          color: darkText,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: lightText,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEBE6D9), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryTeal,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: Color(0xFFA6B3B0), fontSize: 13),
        labelStyle: const TextStyle(color: lightText, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
