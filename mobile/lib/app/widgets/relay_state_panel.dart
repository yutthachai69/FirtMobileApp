import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum RelayStateKind { empty, error, offline }

/// State ที่จบด้วยทางไปต่อเสมอ ใช้แทนข้อความลอยกลางจอและ spinner เปล่า ๆ
class RelayStatePanel extends StatelessWidget {
  const RelayStatePanel({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final RelayStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      RelayStateKind.empty => (Icons.inbox_outlined, context.t.primary),
      RelayStateKind.error => (Icons.error_outline_rounded, context.t.error),
      RelayStateKind.offline => (Icons.cloud_off_outlined, context.t.warning),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: context.t.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: color.withValues(alpha: .34)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: .4)),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.t.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Spacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact warning above cached data when its latest refresh failed.
class RelayStaleBanner extends StatelessWidget {
  const RelayStaleBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: context.t.warning.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: context.t.warning.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 19, color: context.t.warning),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: context.t.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        TextButton(onPressed: () => onRetry(), child: const Text('ลองใหม่')),
      ],
    ),
  );
}
