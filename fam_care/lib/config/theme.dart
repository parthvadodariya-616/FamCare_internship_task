import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_config.dart';

class AppTheme {
  static const Color primary       = Color(AppConfig.colorPrimaryValue);
  static const Color success       = Color(AppConfig.colorSuccessValue);
  static const Color danger        = Color(AppConfig.colorDangerValue);
  static const Color amber         = Color(AppConfig.colorAmberValue);
  static const Color secondaryText = Color(AppConfig.colorSecondaryText);
  static const Color border        = Color(AppConfig.colorBorder);
  static const Color cardBg        = Color(AppConfig.colorCardBg);
  static const Color blueBg        = Color(AppConfig.colorBlueBg);
  static const Color blueText      = Color(AppConfig.colorBlueText);
  static const Color greenBg       = Color(AppConfig.colorGreenBg);
  static const Color greenText     = Color(AppConfig.colorGreenText);
  static const Color redBg         = Color(AppConfig.colorRedBg);
  static const Color redText       = Color(AppConfig.colorRedText);
  static const Color amberBg       = Color(AppConfig.colorAmberBg);
  static const Color amberText     = Color(AppConfig.colorAmberText);
  static const Color grayBg        = Color(AppConfig.colorGrayBg);
  static const Color grayText      = Color(AppConfig.colorGrayText);
  static const Color pageBackground = Color(0xFFF2F2F7);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Display',
    scaffoldBackgroundColor: pageBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF111111),
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111111),
      ),
      iconTheme: IconThemeData(color: primary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: secondaryText,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: border, width: 0.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        minimumSize: const Size(double.infinity, 48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8E8E8),
      thickness: 0.5,
      space: 0,
    ),
  );
}
