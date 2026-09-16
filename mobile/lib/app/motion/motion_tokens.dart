import 'package:flutter/material.dart';

/// ภาษาการเคลื่อนไหวกลางของ RelayContent
///
/// Fast ใช้กับแรงกด, standard ใช้กับ state ภายในหน้า และ journey ใช้กับ
/// การส่งต่องานข้ามขั้น ห้ามใช้ journey กับ interaction เล็ก ๆ เพราะจะรู้สึกหน่วง
abstract final class RelayMotion {
  static const Duration fast = Duration(milliseconds: 110);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasis = Duration(milliseconds: 360);
  static const Duration journey = Duration(milliseconds: 520);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeOutBack;

  static Duration duration(BuildContext context, Duration preferred) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false
      ? Duration.zero
      : preferred;
}

extension RelayMotionX on BuildContext {
  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;

  Duration motion(Duration preferred) => RelayMotion.duration(this, preferred);
}
