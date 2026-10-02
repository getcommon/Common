/// Design System - Color Palette
///
/// Defines the color scheme for Common Grounds app with support for light and dark themes.
/// Based on Common's warm, editorial visual language.
library;

import 'package:flutter/material.dart';

/// App color palette following Material Design 3 principles
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ===========================
  // PRIMARY COLORS
  // ===========================

  /// Primary brand color - warm terracotta, used deliberately for action.
  static const Color primary = Color(0xFFB9503A);
  static const Color primaryLight = Color(0xFFF0C7B8);
  static const Color primaryDark = Color(0xFF873625);

  /// Secondary accent color - quiet clay for supporting emphasis.
  static const Color secondary = Color(0xFF9A6551);
  static const Color secondaryLight = Color(0xFFE8C9BB);
  static const Color secondaryDark = Color(0xFF714536);

  /// Reserved for the few interests a member intentionally prioritizes.
  static const Color topInterestGold = Color(0xFFC58A18);
  static const Color topInterestGoldLight = Color(0xFFFFE8A6);
  static const Color topInterestGoldDark = Color(0xFF765000);

  // ===========================
  // NEUTRAL COLORS
  // ===========================

  /// Background colors
  static const Color backgroundLight = Color(0xFFFFFAF8);
  static const Color backgroundDark = Color(0xFF1E1A19);

  /// Surface colors (cards, sheets, etc.)
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF282220);

  /// Surface variant (slightly different from surface)
  static const Color surfaceVariantLight = Color(0xFFF5EEEA);
  static const Color surfaceVariantDark = Color(0xFF342C29);

  // ===========================
  // TEXT COLORS
  // ===========================

  static const Color textPrimaryLight = Color(0xFF241E1C);
  static const Color textSecondaryLight = Color(0xFF756C68);
  static const Color textDisabledLight = Color(0xFFA79C98);

  static const Color textPrimaryDark = Color(0xFFFCF7F4);
  static const Color textSecondaryDark = Color(0xFFC3B7B2);
  static const Color textDisabledDark = Color(0xFF786E69);

  // ===========================
  // SEMANTIC COLORS
  // ===========================

  /// Success states
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color successDark = Color(0xFF388E3C);

  /// Error states
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color errorDark = Color(0xFFC62828);

  /// Warning states
  static const Color warning = Color(0xFFFFA726);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFF57C00);

  /// Info states
  static const Color info = Color(0xFF29B6F6);
  static const Color infoLight = Color(0xFF4FC3F7);
  static const Color infoDark = Color(0xFF0288D1);

  // ===========================
  // CHAT-SPECIFIC COLORS
  // ===========================

  /// Message bubbles
  static const Color messageSent = primary;
  static const Color messageReceived = Color(0xFFF1EAE6);
  static const Color messageReceivedDark = Color(0xFF342C29);

  /// Online/Active status
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);

  // ===========================
  // DIVIDER & BORDER COLORS
  // ===========================

  static const Color dividerLight = Color(0xFFE8DEDA);
  static const Color dividerDark = Color(0xFF403632);

  static const Color borderLight = Color(0xFFE8DEDA);
  static const Color borderDark = Color(0xFF403632);

  // ===========================
  // OVERLAY COLORS
  // ===========================

  /// Semi-transparent overlays for modals, dialogs
  static const Color scrimLight = Color(0x80000000); // 50% black
  static const Color scrimDark = Color(0xB3000000); // 70% black

  /// Hover, pressed states
  static const Color hoverLight = Color(0x0A000000); // 4% black
  static const Color hoverDark = Color(0x14FFFFFF); // 8% white

  static const Color pressedLight = Color(0x1F000000); // 12% black
  static const Color pressedDark = Color(0x29FFFFFF); // 16% white
}
