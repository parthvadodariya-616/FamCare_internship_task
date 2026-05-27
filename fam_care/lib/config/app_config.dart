// ============================================================
// app_config.dart
// Single source of truth for backend URL and app constants.
// Change baseUrl to your laptop's local IP when running on
// a physical device (e.g. http://192.168.1.X:8000).
// ============================================================

class AppConfig {
  // ── Backend URL ─────────────────────────────────────────
  // Android emulator  → http://10.0.2.2:8000
  // iOS simulator     → http://localhost:8000
  // Physical device   → http://<YOUR_LAN_IP>:8000
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ── App meta ────────────────────────────────────────────
  static const String appName = 'FamCARE';
  static const String appTagline = 'Home healthcare, on your schedule';

  // ── Slot window ─────────────────────────────────────────
  static const int slotDayStartHour = 8;   // 08:00
  static const int slotDayEndHour   = 20;  // 20:00

  // ── Colours (matches design exactly) ────────────────────
  static const int colorPrimaryValue    = 0xFF007AFF;
  static const int colorSuccessValue    = 0xFF34C759;
  static const int colorDangerValue     = 0xFFFF3B30;
  static const int colorAmberValue      = 0xFFFF9500;
  static const int colorSecondaryText   = 0xFF8E8E93;
  static const int colorBorder          = 0xFFE0E0E0;
  static const int colorCardBg          = 0xFFFFFFFF;
  static const int colorBlueBg          = 0xFFE6F1FB;
  static const int colorBlueText        = 0xFF185FA5;
  static const int colorGreenBg         = 0xFFEAF3DE;
  static const int colorGreenText       = 0xFF3B6D11;
  static const int colorRedBg           = 0xFFFCEBEB;
  static const int colorRedText         = 0xFFA32D2D;
  static const int colorAmberBg         = 0xFFFAEEDA;
  static const int colorAmberText       = 0xFF854F0B;
  static const int colorGrayBg          = 0xFFF1EFE8;
  static const int colorGrayText        = 0xFF5F5E5A;
}
