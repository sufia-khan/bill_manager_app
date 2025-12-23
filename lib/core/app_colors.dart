import 'package:flutter/material.dart';

/// BillMinder Design System Colors
/// Based on the locked UI design specification
class AppColors {
  AppColors._();

  // Primary - Used for success, growth, and primary actions
  static const Color primary = Color(0xFF10B981); // Emerald 500
  static const Color primaryLight = Color(0xFF34D399); // Emerald 400
  static const Color primaryDark = Color(0xFF059669); // Emerald 600

  // Action/Dark - Used for floating buttons and high contrast
  static const Color dark = Color(0xFF0F172A); // Slate 900
  static const Color darkLight = Color(0xFF1E293B); // Slate 800

  // Neutral - Background colors
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color surfaceDim = Color(0xFFF1F5F9); // Slate 100

  // Alert - Used for overdue bills and deletions
  static const Color alert = Color(0xFFF43F5E); // Rose 500
  static const Color alertLight = Color(0xFFFDA4AF); // Rose 300

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White

  // Border colors
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderLight = Color(0xFFF1F5F9); // Slate 100

  // Status colors
  static const Color pending = Color(0xFFF59E0B); // Amber 500
  static const Color paid = Color(0xFF10B981); // Emerald 500
  static const Color overdue = Color(0xFFF43F5E); // Rose 500

  // Shadow colors
  static const Color shadowPrimary = Color(
    0x1A10B981,
  ); // Emerald with 10% opacity
  static const Color shadowDark = Color(
    0x1A0F172A,
  ); // Slate 900 with 10% opacity
}
