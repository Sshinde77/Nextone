import 'package:flutter/material.dart';

class AppColors {
  // 🌟 Brand Colors (from your UI)
  static const Color primary = Color(0xFFB1916C);
  static const Color primaryLight = Color(0xFFD6C2A8);
  static const Color primaryDark = Color(0xFF8A6E4F);

  static const Color secondary = Color(0xFFE8E3DC);
  static const Color tertiary = Color(
    0xFF2E7D6B,
  ); // subtle green (used in stats)

  // 🌿 Background System
  static const Color background = Color(0xFFF5F3F0); // main bg (warm grey)
  static const Color surface = Colors.white;
  static const Color card = Color(0xFFFFFFFF);

  // ⚠️ Status Colors (soft, not harsh)
  static const Color success = Color(0xFF4CAF8E);
  static const Color error = Color(0xFFD9534F);
  static const Color warning = Color(0xFFE6A23C);
  static const Color info = Color(0xFF6C8CD5);

  // 📊 Chart Colors (muted to match UI)
  static const Color chart1 = Color(0xFF6C8CD5);
  static const Color chart2 = Color(0xFF4CAF8E);
  static const Color chart3 = Color(0xFFE6A23C);
  static const Color chart4 = Color(0xFFD9534F);
  static const Color chart5 = Color(0xFFA78BFA);
  static const Color chart6 = Color(0xFFE57399);

  // ✍️ Text Colors
  static const Color textPrimary = Color(0xFF2C2C2C); // softer than black
  static const Color textSecondary = Color(0xFF7A7A7A);

  // 🔲 Borders & Dividers
  static const Color border = Color(0xFFE0DDD7);
}
