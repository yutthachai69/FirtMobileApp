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
    required this.surfaceElevated,
    required this.primary,
    required this.creative,
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

  /// การ์ดที่ต้องเด่นกว่าพื้นผิวหลัก เช่น งานที่ต้องตรวจและแถบนำทาง
  final Color surfaceElevated;

  /// ปุ่มหลัก, ลิงก์
  final Color primary;

  /// การกระทำด้านการสร้างคอนเทนต์เท่านั้น
  final Color creative;

  /// ตัวอักษรบน primary
  final Color onPrimary;

  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  final Color success;
  final Color warning;
  final Color error;

  static const light = AppTokens(
    surface: Color(0xFFF5F7FA),
    surfaceContainer: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDF2F7),
    primary: Color(0xFF007F92),
    creative: Color(0xFFD5004D),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
  );

  /// ค่าตรงตัวจาก stitch_relaycontent_mobile_ux_review3/relaycontent_creator_system
  /// /DESIGN.md — เวอร์ชันล่าสุดที่อนุมัติแล้ว (เช็ค timestamp ยืนยันแล้วว่าใหม่สุด
  /// ในบรรดา review1/2/3) ห้ามแก้ค่าตรงนี้ลอย ๆ โดยไม่เทียบกับไฟล์ต้นทางก่อน
  ///
  /// mapping จาก Material 3 token name → AppTokens:
  ///   surface           = background / surface
  ///   surfaceContainer  = surface-container
  ///   surfaceElevated   = surface-container-high
  ///   primary           = primary-container (สีปุ่มจริง ไม่ใช่ "primary" เฉย ๆ
  ///                        ซึ่งใน M3 dark scheme เป็นสีอ่อนสำหรับตัวอักษรบนพื้นเข้ม)
  ///   onPrimary         = on-primary (ตัวอักษรบนปุ่ม primary-container)
  ///   creative          = secondary-container (ปุ่ม/แถบเน้นงานสร้างคอนเทนต์)
  ///   textPrimary       = on-surface
  ///   textSecondary     = on-surface-variant
  ///   border            = outline-variant (ไม่ใช้ outline เพราะสว่างเกินไปสำหรับเส้นขอบ)
  ///   success           = tertiary-container
  static const dark = AppTokens(
    surface: Color(0xFF051424),
    surfaceContainer: Color(0xFF122131),
    surfaceElevated: Color(0xFF1C2B3C),
    primary: Color(0xFF00F2FE),
    creative: Color(0xFFB90039),
    onPrimary: Color(0xFF00373A),
    textPrimary: Color(0xFFD4E4FA),
    textSecondary: Color(0xFFB9CACB),
    border: Color(0xFF3A494B),
    success: Color(0xFF4AF7AD),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFFFB4AB),
  );

  @override
  AppTokens copyWith({
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceElevated,
    Color? primary,
    Color? creative,
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
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      primary: primary ?? this.primary,
      creative: creative ?? this.creative,
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
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      creative: Color.lerp(creative, other.creative, t)!,
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
