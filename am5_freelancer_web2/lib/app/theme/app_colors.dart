import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF142B6F);
  static const Color primaryDark = Color(0xFF0D1B45);
  static const Color primaryLight = Color(0xFF28458F);

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE8CC72);

  // Basic
  static const Color white = Colors.white;
  static const Color black = Color(0xFF111111);

  // Background / surfaces
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF687386);
  static const Color textHint = Color(0xFF9AA3B2);

  // Borders
  static const Color border = Color(0xFFE2E6EE);
  static const Color divider = Color(0xFFEEF0F4);

  // Status
  static const Color success = Color(0xFF198754);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);

  static const Color overlay = Color(0x66000000);
}
