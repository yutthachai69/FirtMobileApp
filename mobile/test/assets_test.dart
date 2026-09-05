import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relaycontent/app/theme/app_theme.dart';

/// เทสชุดนี้กันบั๊กที่ analyze กับ test ปกติจับไม่ได้
///
/// ถ้า theme อ้าง fontFamily ที่ไม่ได้ประกาศใน pubspec.yaml
/// Flutter จะ **เงียบ ๆ** แล้วใช้ฟอนต์ default แทน ไม่มี error ไม่มี warning
/// ผลคือแอปแสดงภาษาไทยด้วยฟอนต์ที่ตัดคำไม่สวยโดยไม่มีใครรู้
/// (เคยเกิดจริงตอน flutter create --overwrite ลบ fonts: ใน pubspec ทิ้ง)
void main() {
  group('ฟอนต์', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('fontFamily ที่ theme ใช้ ต้องถูกประกาศใน pubspec', () {
      final family = appTheme(Brightness.light).textTheme.bodyMedium?.fontFamily
          // Flutter เติม prefix "packages/..." ให้ในบางกรณี
          ?.split('/')
          .last;

      expect(family, isNotNull, reason: 'theme ไม่ได้ตั้ง fontFamily');
      expect(
        pubspec.contains('family: $family'),
        isTrue,
        reason: 'theme ใช้ "$family" แต่ pubspec.yaml ไม่ได้ประกาศไว้ '
            '— Flutter จะเงียบแล้วใช้ฟอนต์ default แทน',
      );
    });

    test('ไฟล์ฟอนต์ที่ประกาศไว้ต้องมีอยู่จริง', () {
      // ข้ามบรรทัดคอมเมนต์ — pubspec ที่ flutter create สร้างมามี template
      // ของฟอนต์ตัวอย่างคอมเมนต์ไว้ ซึ่งไฟล์พวกนั้นไม่มีอยู่จริง
      final assets = pubspec
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('#'))
          .map((line) => RegExp(r'-\s*asset:\s*(\S+\.ttf)').firstMatch(line))
          .nonNulls
          .map((m) => m.group(1)!)
          .toList();

      expect(assets, isNotEmpty, reason: 'ไม่มีไฟล์ฟอนต์ประกาศไว้เลย');

      for (final path in assets) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'pubspec อ้าง $path แต่ไม่มีไฟล์นั้นจริง',
        );
      }
    });

    test('ฟอนต์ต้องรองรับภาษาไทย', () {
      // ไฟล์ฟอนต์ที่เล็กเกินไปมักเป็นไฟล์ error page ที่โหลดพลาดมา
      final file = File('assets/fonts/NotoSansThai.ttf');
      expect(file.existsSync(), isTrue);
      expect(
        file.lengthSync(),
        greaterThan(50000),
        reason: 'ไฟล์เล็กผิดปกติ อาจเป็นไฟล์ที่โหลดไม่สำเร็จ',
      );
    });
  });
}
