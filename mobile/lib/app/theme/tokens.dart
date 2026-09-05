import 'package:flutter/material.dart';

/// Design token ของทั้งแอป
///
/// กฎเหล็ก: **ห้ามเขียน Colors.white / Colors.black / Colors.grey ที่ไหนใน features/**
/// ถ้าปล่อยให้ hard-code กระจาย พอจะทำ dark mode ทีหลังต้องไล่แก้ทั้งโปรเจกต์
///
/// ใช้งานผ่าน `context.t.textSecondary` (ดู extension ท้ายไฟล์)
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surface,
    required this.surfaceContainer,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
  });

  /// พื้นหลังหน้าจอ
  final Color surface;

  /// การ์ด, sheet, ช่องกรอก
  final Color surfaceContainer;

  /// ปุ่มหลัก, ลิงก์
  final Color primary;

  /// ตัวอักษรบน primary
  final Color onPrimary;

  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  final Color success;
  final Color warning;
  final Color error;

  static const light = AppTokens(
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF5F6F8),
    primary: Color(0xFF2563EB),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
  );

  static const dark = AppTokens(
    surface: Color(0xFF0F1115),
    surfaceContainer: Color(0xFF1A1D23),
    primary: Color(0xFF3B82F6),
    onPrimary: Color(0xFF0F1115),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    border: Color(0xFF2A2F3A),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  @override
  AppTokens copyWith({
    Color? surface,
    Color? surfaceContainer,
    Color? primary,
    Color? onPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AppTokens(
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

/// ระยะห่างมาตรฐาน — สเกล 4pt
///
/// ใช้ค่าจากตรงนี้เสมอ อย่าใส่ตัวเลขลอย ๆ ใน widget
/// ไม่งั้นระยะห่างจะไม่สม่ำเสมอทั้งแอปโดยไม่มีใครสังเกต
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

/// ทางลัดเข้าถึง token — `context.t.textSecondary`
extension AppThemeX on BuildContext {
  AppTokens get t => Theme.of(this).extension<AppTokens>()!;
}
