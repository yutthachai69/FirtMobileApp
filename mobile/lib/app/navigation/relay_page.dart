import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../motion/motion_tokens.dart';

enum RelayPageMotion { journey, detail }

/// Page transition กลาง — journey เดินตามแกนงาน, detail ยกขึ้นจาก surface เดิม
CustomTransitionPage<void> relayPage(
  GoRouterState state,
  Widget child, {
  RelayPageMotion motion = RelayPageMotion.journey,
}) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: motion == RelayPageMotion.journey
      ? RelayMotion.emphasis
      : RelayMotion.standard,
  reverseTransitionDuration: RelayMotion.standard,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (context.reduceMotion) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: RelayMotion.enter,
      reverseCurve: RelayMotion.exit,
    );
    final begin = motion == RelayPageMotion.journey
        ? const Offset(.065, 0)
        : const Offset(0, .025);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: .988, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  },
);
