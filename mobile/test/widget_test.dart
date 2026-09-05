import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';
import 'package:relaycontent/app/theme/tokens.dart';

void main() {
  group('design token', () {
    test('theme ทั้งสองโหมดต้องมี AppTokens ติดมาด้วยเสมอ', () {
      // ถ้า extension หลุด context.t จะพังทั้งแอปตอน runtime
      expect(appTheme(Brightness.light).extension<AppTokens>(), isNotNull);
      expect(appTheme(Brightness.dark).extension<AppTokens>(), isNotNull);
    });

    test('dark กับ light ต้องใช้คนละชุดสี', () {
      final light = appTheme(Brightness.light).extension<AppTokens>()!;
      final dark = appTheme(Brightness.dark).extension<AppTokens>()!;

      expect(light.surface, isNot(dark.surface));
      expect(light.textPrimary, isNot(dark.textPrimary));
    });

    test('ตัวอักษรต้องตัดกับพื้นหลังพอให้อ่านออก', () {
      for (final t in [AppTokens.light, AppTokens.dark]) {
        final ratio = _contrast(t.textPrimary, t.surface);
        // 4.5:1 คือเกณฑ์ WCAG AA สำหรับตัวอักษรขนาดปกติ
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'textPrimary บน surface ได้อัตราส่วน ${ratio.toStringAsFixed(2)}',
        );
      }
    });

    testWidgets('context.t อ่านค่าได้จริงใน widget tree', (tester) async {
      // พิสูจน์ว่า extension เข้าถึงได้จริง ไม่ใช่แค่ประกาศไว้เฉย ๆ
      late AppTokens seen;

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.dark),
          home: Builder(
            builder: (context) {
              seen = context.t;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen.surface, AppTokens.dark.surface);
    });
  });
}

/// อัตราส่วนความต่างของความสว่างตามสูตร WCAG
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color c) => c.computeLuminance();
