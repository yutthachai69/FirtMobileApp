import 'package:flutter/material.dart';

import 'tokens.dart';

/// ฟอนต์ไทย — ฟอนต์ default ของ Flutter ตัดคำไทยไม่สวย
/// (สระบนล่างลอย วรรณยุกต์ซ้อนผิดตำแหน่ง)
const _fontFamily = 'NotoSansThai';

/// จุดเข้าใช้งานหลักของ theme
///
/// เลือกชุด token ตาม brightness แล้วประกอบเป็น ThemeData
/// สีทุกสีมาจาก [AppTokens] เท่านั้น — ไม่มี Colors.* ลอยอยู่ในนี้
ThemeData appTheme(Brightness brightness) => brightness == Brightness.dark
    ? AppTheme.dark()
    : AppTheme.light();

abstract final class AppTheme {
  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: t.primary,
      brightness: brightness,
    ).copyWith(
      surface: t.surface,
      primary: t.primary,
      onPrimary: t.onPrimary,
      error: t.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.surface,
      fontFamily: _fontFamily,
      extensions: [t],

      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        color: t.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: t.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: t.error),
        ),
        hintStyle: TextStyle(color: t.textSecondary),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          // ปุ่มหลักต้องกดง่ายด้วยนิ้วโป้ง — 48 คือขั้นต่ำที่แนะนำ
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),

      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surfaceContainer,
        contentTextStyle: TextStyle(color: t.textPrimary, fontFamily: _fontFamily),
        behavior: SnackBarBehavior.floating,
      ),

      textTheme: _textTheme(t),
    );
  }

  static TextTheme _textTheme(AppTokens t) {
    return TextTheme(
      headlineSmall: TextStyle(
        color: t.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: t.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: t.textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: t.textPrimary, fontSize: 14),
      bodySmall: TextStyle(color: t.textSecondary, fontSize: 13),
      labelLarge: TextStyle(
        color: t.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
