import 'package:flutter/material.dart';

/// Central brand colors used by shared widgets and workspace screens.
abstract final class DeckColors {
  static const Color accent = Color(0xFF8FA600);
  static const Color railwayBlue = Color(0xFF176B87);
  static const Color railwayNavy = Color(0xFF102D4D);
}

/// Shared Material 3 themes. Keep global surface, card and input styling here.
abstract final class DeckTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: DeckColors.accent,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF5F6F3),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEEF0E9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: DeckColors.accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0D1016),
      cardTheme: const CardThemeData(
        color: Color(0xFF151A22),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A202A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
