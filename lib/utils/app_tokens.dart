import 'package:flutter/material.dart';

import 'theme_controller.dart';

@immutable
class AppTokens {
  final Color bg;
  final Color card;
  final Color cardBorder;
  final Color text;
  final Color textSub;
  final Color textMuted;
  final Color primaryBlue;
  final Color disabled;
  final Color disabledFg;
  final Color success;
  final Color danger;
  final Color warn;
  final Color surface2;
  final Color actionRowGastosTint;
  final Color actionRowCargaTint;
  final Color heroBlue;
  final Color heroBlueDeeper;
  final Color heroPanelTint;
  final Color heroBtnFill;
  final Color heroBtnBorder;
  final Brightness brightness;

  const AppTokens._({
    required this.bg,
    required this.card,
    required this.cardBorder,
    required this.text,
    required this.textSub,
    required this.textMuted,
    required this.primaryBlue,
    required this.disabled,
    required this.disabledFg,
    required this.success,
    required this.danger,
    required this.warn,
    required this.surface2,
    required this.actionRowGastosTint,
    required this.actionRowCargaTint,
    required this.heroBlue,
    required this.heroBlueDeeper,
    required this.heroPanelTint,
    required this.heroBtnFill,
    required this.heroBtnBorder,
    required this.brightness,
  });

  factory AppTokens.light() => const AppTokens._(
    bg: Color(0xFFF5F5F7),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E7EB),
    text: Color(0xFF111827),
    textSub: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    primaryBlue: Color(0xFF2D6BFF),
    disabled: Color(0xFFC9CDD3),
    disabledFg: Color(0xFF6B7280),
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    warn: Color(0xFFD97706),
    surface2: Color(0xFFF4F6F8),
    actionRowGastosTint: Color(0xFFFFE4E4),
    actionRowCargaTint: Color(0xFFE7EDFF),
    heroBlue: Color(0xFF2D6BFF),
    heroBlueDeeper: Color(0xFF1F4FE0),
    heroPanelTint: Color(0x29FFFFFF),
    heroBtnFill: Color(0x33FFFFFF),
    heroBtnBorder: Color(0x66FFFFFF),
    brightness: Brightness.light,
  );

  factory AppTokens.dark() => const AppTokens._(
    bg: Color(0xFF070E1A),
    card: Color(0xFF0F1B2D),
    cardBorder: Color(0xFF1A2A40),
    text: Color(0xFFE8EEF8),
    textSub: Color(0xFF9BADC8),
    textMuted: Color(0xFF6C7E9C),
    primaryBlue: Color(0xFF60A5FA),
    disabled: Color(0xFF1F2E4A),
    disabledFg: Color(0xFF6C7E9C),
    success: Color(0xFF34D27A),
    danger: Color(0xFFF87171),
    warn: Color(0xFFFBBF24),
    surface2: Color(0xFF16253F),
    actionRowGastosTint: Color(0x33F87171),
    actionRowCargaTint: Color(0x333B82F6),
    heroBlue: Color(0xFF3B82F6),
    heroBlueDeeper: Color(0xFF1D4ED8),
    heroPanelTint: Color(0x1FFFFFFF),
    heroBtnFill: Color(0x29FFFFFF),
    heroBtnBorder: Color(0x55FFFFFF),
    brightness: Brightness.dark,
  );

  bool get isDark => brightness == Brightness.dark;

  static AppTokens of(BuildContext context) => AppTheme.of(context).tokens;
}
