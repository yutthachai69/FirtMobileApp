import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../data/composer_api.dart' show PublishJob;
import '../domain/composer_state.dart';
import '../domain/creator_info.dart';
import 'composer_controller.dart';

/// ลิงก์นโยบายที่ TikTok บังคับให้แสดงในข้อความยินยอม (กฎ R6)
const _musicPolicyUrl =
    'https://www.tiktok.com/legal/page/global/music-usage-confirmation/en';
const _brandedPolicyUrl =
    'https://www.tiktok.com/legal/page/global/bc-policy/en';

/// หน้าตั้งค่าโพสต์ TikTok
///
/// ⚠️ หน้านี้คือสิ่งที่ TikTok ตรวจตอน audit — ผิดข้อเดียวคือไม่ผ่าน
/// กฎแต่ละข้อกำกับไว้ที่ widget ที่เกี่ยวข้อง อย่าแก้โดยไม่อ่านคอมเมนต์
class TikTokComposerPage extends StatefulWidget {
  const TikTokComposerPage({
    super.key,
    required this.controller,
    this.onSubmitted,
  });
  final ComposerController controller;

  /// Lets the app refresh shared content state after the server accepts a job.
  final Future<void> Function()? onSubmitted;

  @override
  State<TikTokComposerPage> createState() => _TikTokComposerPageState();
}

class _TikTokComposerPageState extends State<TikTokComposerPage> {
  final _caption = TextEditingController();
  final _captionKey = GlobalKey();
  final _privacyKey = GlobalKey();
  final _disclosureKey = GlobalKey();
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    // ดึงข้อมูลสดทุกครั้งที่เปิดหน้า ห้าม cache ข้ามรอบ
    widget.controller.loadCreatorInfo();
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final s = c.state;

      if (_accepted) {
        return _PublishAcceptedView(
          job: c.result,
          onPoll: c.pollUntilTerminal,
          onDone: () => Navigator.of(context).pop(true),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('โพสต์ลง TikTok')),
        body: SafeArea(
          child: c.state.creator == null
              ? _Loading(error: c.error, onRetry: c.loadCreatorInfo)
              : ListView(
                  padding: const EdgeInsets.all(Spacing.md),
                  children: [
                    _CreatorHeader(creator: s.creator!),
                    const SizedBox(height: Spacing.lg),
                    KeyedSubtree(
                      key: _captionKey,
                      child: _CaptionField(
                        controller: _caption,
                        state: s,
                        onChanged: c.setCaption,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    KeyedSubtree(
                      key: _privacyKey,
                      child: _PrivacySection(state: s, onChanged: c.setPrivacy),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _InteractionSection(state: s, controller: c),
                    const SizedBox(height: Spacing.lg),
                    KeyedSubtree(
                      key: _disclosureKey,
                      child: _DisclosureSection(state: s, controller: c),
                    ),
                    if (s.isAigc) ...[
                      const SizedBox(height: Spacing.md),
                      const _AigcNotice(),
                    ],
                    const SizedBox(height: Spacing.xl),
                    _ConsentAndPost(
                      state: s,
                      controller: c,
                      onSubmitted: widget.onSubmitted,
                      onAccepted: () => setState(() => _accepted = true),
                      onFix: _issueTarget(s) == null
                          ? null
                          : () => _jumpToIssue(s),
                    ),
                    const SizedBox(height: Spacing.xl),
                  ],
                ),
        ),
      );
    },
  );

  GlobalKey? _issueTarget(ComposerState state) => state.privacyLevel == null
      ? _privacyKey
      : state.discloseContent && !state.brandOrganic && !state.brandedContent
      ? _disclosureKey
      : state.captionLength > kMaxCaptionRunes
      ? _captionKey
      : null;

  void _jumpToIssue(ComposerState state) {
    final target = _issueTarget(state);
    final targetContext = target?.currentContext;
    if (targetContext == null) return;
    HapticFeedback.selectionClick();
    Scrollable.ensureVisible(
      targetContext,
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: .14,
    );
  }
}

// ── R1: avatar + ชื่อบัญชี ต้องดึงสด ห้ามใช้ค่าเก่า ────────────

class _CreatorHeader extends StatelessWidget {
  const _CreatorHeader({required this.creator});
  final CreatorInfo creator;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: context.t.surfaceContainer,
        foregroundImage: creator.avatarUrl.isEmpty
            ? null
            : NetworkImage(creator.avatarUrl),
        child: Icon(Icons.person, color: context.t.textSecondary),
      ),
      const SizedBox(width: Spacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              creator.handle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (creator.nickname.isNotEmpty)
              Text(
                creator.nickname,
                style: TextStyle(color: context.t.textSecondary),
              ),
          ],
        ),
      ),
    ],
  );
}

class _CaptionField extends StatelessWidget {
  const _CaptionField({
    required this.controller,
    required this.state,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ComposerState state;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final over = state.captionLength > kMaxCaptionRunes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'เขียนคำบรรยาย… ใส่ #แฮชแท็ก ได้',
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            // นับเป็นตัวอักษร ไม่ใช่ไบต์ — ภาษาไทยตัวละ 3 ไบต์
            '${state.captionLength} / $kMaxCaptionRunes',
            style: TextStyle(
              fontSize: 12,
              color: over ? context.t.error : context.t.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── R2: privacy ห้ามมีค่าเริ่มต้น ผู้ใช้ต้องเลือกเอง ───────────

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.state, required this.onChanged});
  final ComposerState state;
  final ValueChanged<PrivacyLevel?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const _Label('ใครดูวิดีโอนี้ได้'),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: state.privacyLevel == null
                ? _ComposerBadge(
                    key: const ValueKey('privacy-required'),
                    label: 'ต้องเลือก',
                    color: context.t.warning,
                  )
                : _ComposerBadge(
                    key: const ValueKey('privacy-ready'),
                    label: 'เลือกแล้ว',
                    color: context.t.success,
                    icon: Icons.check_rounded,
                  ),
          ),
        ],
      ),
      const SizedBox(height: Spacing.sm),
      AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: state.privacyLevel == null
              ? context.t.warning.withValues(alpha: .055)
              : context.t.success.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: state.privacyLevel == null
              ? null
              : [
                  BoxShadow(
                    color: context.t.success.withValues(alpha: .07),
                    blurRadius: 14,
                  ),
                ],
        ),
        child: DropdownButtonFormField<PrivacyLevel>(
          // value เป็น null จนกว่าผู้ใช้จะเลือก — ห้ามใส่ค่าตั้งต้น
          initialValue: state.privacyLevel,
          hint: const Text('เลือก'),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(
              state.privacyLevel == null
                  ? Icons.visibility_outlined
                  : Icons.visibility_rounded,
              color: state.privacyLevel == null
                  ? context.t.warning
                  : context.t.success,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              borderSide: BorderSide(
                color:
                    (state.privacyLevel == null
                            ? context.t.warning
                            : context.t.success)
                        .withValues(alpha: .42),
              ),
            ),
          ),
          // ตัวเลือกมาจาก creator_info เท่านั้น ห้ามใส่รายการเอง
          items: [
            for (final level in state.privacyOptions)
              DropdownMenuItem(value: level, child: Text(level.label)),
          ],
          onChanged: (value) {
            HapticFeedback.selectionClick();
            onChanged(value);
          },
        ),
      ),
      if (!(state.creator?.canPublishPublic ?? true)) ...[
        const SizedBox(height: Spacing.sm),
        _Note(
          icon: Icons.lock_outline_rounded,
          text:
              'บัญชีนี้ยังโพสต์สาธารณะไม่ได้ '
              'จะเปิดให้เมื่อแอปผ่านการตรวจสอบจาก TikTok',
        ),
      ],
    ],
  );
}

// ── R3: comment/duet/stitch เริ่มปิด และล็อกเมื่อบัญชีปิดไว้ ────

class _InteractionSection extends StatelessWidget {
  const _InteractionSection({required this.state, required this.controller});
  final ComposerState state;
  final ComposerController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Label('อนุญาตให้ผู้ชม'),
      const SizedBox(height: Spacing.xs),
      _Toggle(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'แสดงความคิดเห็น',
        value: state.allowComment,
        // ปิดจากฝั่งบัญชี = disable ทั้งช่อง ไม่ใช่แค่ปล่อยว่าง
        locked: state.commentLocked,
        onChanged: controller.setAllowComment,
      ),
      _Toggle(
        icon: Icons.people_alt_outlined,
        title: 'Duet',
        value: state.allowDuet,
        locked: state.duetLocked,
        onChanged: controller.setAllowDuet,
      ),
      _Toggle(
        icon: Icons.movie_filter_outlined,
        title: 'Stitch',
        value: state.allowStitch,
        locked: state.stitchLocked,
        onChanged: controller.setAllowStitch,
      ),
    ],
  );
}

// ── R4 + R5: การเปิดเผยเนื้อหาเชิงพาณิชย์ ──────────────────────

class _DisclosureSection extends StatelessWidget {
  const _DisclosureSection({required this.state, required this.controller});
  final ComposerState state;
  final ComposerController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Toggle(
        icon: Icons.campaign_outlined,
        accent: context.t.warning,
        title: 'เปิดเผยว่าเป็นเนื้อหาเชิงพาณิชย์',
        subtitle: 'เปิดเมื่อวิดีโอโปรโมตสินค้าหรือบริการ',
        value: state.discloseContent,
        onChanged: controller.setDisclose,
      ),
      if (state.discloseContent)
        Padding(
          padding: const EdgeInsets.only(left: Spacing.md),
          child: Column(
            children: [
              _Toggle(
                icon: Icons.storefront_outlined,
                accent: context.t.creative,
                title: 'แบรนด์ของคุณเอง',
                subtitle: 'โปรโมตสินค้าหรือบริการของตัวเอง',
                value: state.brandOrganic,
                onChanged: controller.setBrandOrganic,
              ),
              _Toggle(
                icon: Icons.handshake_outlined,
                accent: context.t.creative,
                title: 'Branded content',
                subtitle: state.brandedContentBlocked
                    // R5: บอกเหตุผลที่ล็อก ไม่ใช่ปล่อยให้กดไม่ได้เฉย ๆ
                    ? 'ใช้กับ "เฉพาะฉัน" ไม่ได้ — เปลี่ยนผู้ที่ดูได้ก่อน'
                    : 'ได้รับค่าตอบแทนจากแบรนด์อื่น',
                value: state.brandedContent,
                locked: state.brandedContentBlocked,
                onChanged: controller.setBrandedContent,
              ),
            ],
          ),
        ),
    ],
  );
}

// ── R8: วิดีโอจาก AI ต้องประกาศ ผู้ใช้ปิดเองไม่ได้ ─────────────

class _AigcNotice extends StatelessWidget {
  const _AigcNotice();

  @override
  Widget build(BuildContext context) => _Note(
    icon: Icons.auto_awesome_rounded,
    text: 'วิดีโอนี้สร้างด้วย AI — ระบบจะแจ้ง TikTok ให้อัตโนมัติ',
  );
}

// ── R6: ข้อความยินยอมต้องอยู่เหนือปุ่มโพสต์ ────────────────────

class _ConsentAndPost extends StatelessWidget {
  const _ConsentAndPost({
    required this.state,
    required this.controller,
    this.onSubmitted,
    this.onAccepted,
    this.onFix,
  });
  final ComposerState state;
  final ComposerController controller;
  final Future<void> Function()? onSubmitted;
  final VoidCallback? onAccepted;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final reason = state.postBlockedReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComposerReadiness(
          submitting: state.submitting,
          reason: reason,
          onFix: onFix,
        ),
        const SizedBox(height: Spacing.md),
        // ข้อความนี้ต้องอยู่ "เหนือ" ปุ่มเสมอตามกฎของ TikTok
        _ConsentText(showBrandedPolicy: state.brandedContent),
        const SizedBox(height: Spacing.md),

        _ComposerPostButton(
          onPressed: state.canPost ? () => _submit(context) : null,
          scheduled: state.scheduledAt != null,
          submitting: state.submitting,
        ),

        if (controller.error != null) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            controller.error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.t.error),
          ),
        ],
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    final ok = await controller.submit();
    if (!ok) return;

    // The publish request has already been accepted by the backend at this
    // point. A dashboard refresh is useful, but must not turn a successful
    // publish into a false error when the network drops immediately after.
    try {
      await onSubmitted?.call();
    } catch (_) {
      // The accepted state is still truthful; Home can refresh on its next
      // poll or when the user pulls to refresh.
    }
    if (!context.mounted) return;
    onAccepted?.call();
  }
}

class _ComposerReadiness extends StatelessWidget {
  const _ComposerReadiness({
    required this.submitting,
    required this.reason,
    required this.onFix,
  });

  final bool submitting;
  final String? reason;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final ready = reason == null && !submitting;
    final color = submitting
        ? context.t.primary
        : ready
        ? context.t.success
        : context.t.warning;
    final title = submitting
        ? 'กำลังส่งคำสั่งเผยแพร่'
        : ready
        ? 'พร้อมส่งไป TikTok'
        : 'เหลืออีก 1 จุดก่อนโพสต์';

    return AnimatedContainer(
      key: const Key('composer-readiness'),
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: .32)),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              submitting
                  ? Icons.sync_rounded
                  : ready
                  ? Icons.verified_rounded
                  : Icons.route_outlined,
              key: ValueKey('$submitting-$ready'),
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (reason != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      reason!,
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (onFix != null)
            TextButton.icon(
              key: const Key('composer-fix-issue'),
              onPressed: onFix,
              icon: const Icon(Icons.arrow_upward_rounded, size: 16),
              label: const Text('ไปแก้'),
              style: TextButton.styleFrom(
                foregroundColor: color,
                minimumSize: const Size(64, 40),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComposerPostButton extends StatefulWidget {
  const _ComposerPostButton({
    required this.onPressed,
    required this.scheduled,
    required this.submitting,
  });

  final VoidCallback? onPressed;
  final bool scheduled;
  final bool submitting;

  @override
  State<_ComposerPostButton> createState() => _ComposerPostButtonState();
}

class _ComposerPostButtonState extends State<_ComposerPostButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted || widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final enabled = widget.onPressed != null;
    final accent = widget.scheduled ? t.warning : t.success;
    final reduced = MediaQuery.of(context).disableAnimations;

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: reduced || !_pressed ? 1 : .97,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          height: 58,
          decoration: BoxDecoration(
            color: enabled ? null : t.surfaceElevated,
            gradient: enabled
                ? LinearGradient(
                    colors: [t.primary, Color.lerp(t.primary, accent, .3)!],
                  )
                : null,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: enabled ? accent.withValues(alpha: .28) : t.border,
            ),
            boxShadow: enabled && !_pressed
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .18),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: _PostSignature(
                  enabled: enabled,
                  scheduled: widget.scheduled,
                  color: enabled ? t.onPrimary : t.textSecondary,
                ),
              ),
              FilledButton(
                key: const Key('composer-submit'),
                onPressed: widget.onPressed == null
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        widget.onPressed!();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: t.primary.withValues(alpha: 0),
                  disabledBackgroundColor: t.surfaceElevated.withValues(
                    alpha: 0,
                  ),
                  foregroundColor: t.onPrimary,
                  disabledForegroundColor: t.textSecondary,
                  shadowColor: t.primary.withValues(alpha: 0),
                  minimumSize: const Size.fromHeight(58),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: widget.submitting
                      ? const SizedBox(
                          key: ValueKey('submitting'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          key: ValueKey('post-${widget.scheduled}-$enabled'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              enabled
                                  ? widget.scheduled
                                        ? Icons.event_available_rounded
                                        : Icons.rocket_launch_outlined
                                  : Icons.lock_outline_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              widget.scheduled ? 'ตั้งเวลาโพสต์' : 'โพสต์เลย',
                            ),
                            if (enabled) ...[
                              const SizedBox(width: 9),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostSignature extends StatelessWidget {
  const _PostSignature({
    required this.enabled,
    required this.scheduled,
    required this.color,
  });

  final bool enabled;
  final bool scheduled;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (enabled && !scheduled)
          for (var i = 0; i < 3; i++)
            Positioned(
              right: 4.0 + (i * 9),
              child: Container(
                width: 15.0 - (i * 2),
                height: 2,
                color: color.withValues(alpha: .08 + (i * .05)),
              ),
            )
        else if (enabled)
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .2), width: 2),
            ),
          ),
        Icon(
          enabled
              ? scheduled
                    ? Icons.schedule_rounded
                    : Icons.chevron_right_rounded
              : Icons.lock_outline_rounded,
          color: color.withValues(alpha: enabled ? .25 : .18),
          size: 22,
        ),
      ],
    ),
  );
}

class _PublishAcceptedView extends StatefulWidget {
  const _PublishAcceptedView({
    required this.job,
    required this.onDone,
    this.onPoll,
  });

  final PublishJob? job;
  final VoidCallback onDone;
  final Future<PublishJob?> Function()? onPoll;

  @override
  State<_PublishAcceptedView> createState() => _PublishAcceptedViewState();
}

class _PublishAcceptedViewState extends State<_PublishAcceptedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _icon = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0, .55, curve: Curves.easeOutBack),
  );
  late final Animation<double> _details = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(.25, 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    if (widget.job != null && widget.onPoll != null) {
      Future<void>.microtask(() => widget.onPoll!());
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final scheduled = job?.status == 'scheduled';
    return Scaffold(
      appBar: AppBar(title: const Text('สถานะการเผยแพร่')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              children: [
                ScaleTransition(
                  scale: _icon,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.t.primary.withValues(alpha: .16),
                      border: Border.all(color: context.t.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: context.t.primary.withValues(alpha: .28),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: context.t.primary,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                FadeTransition(
                  opacity: _details,
                  child: Column(
                    children: [
                      Text(
                        'Backend รับงานแล้ว',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scheduled
                            ? 'คอนเทนต์ถูกตั้งเวลาไว้เรียบร้อย'
                            : 'คอนเทนต์เข้าคิวเผยแพร่แล้ว',
                        style: TextStyle(color: context.t.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.xl),
                      _PublishTimeline(scheduled: scheduled),
                      const SizedBox(height: Spacing.lg),
                      SelectableText(
                        'Job ID: ${job?.id ?? '-'}',
                        style: TextStyle(
                          color: context.t.textSecondary,
                          fontSize: 12,
                          letterSpacing: .3,
                        ),
                      ),
                      const SizedBox(height: Spacing.xl),
                      FilledButton.icon(
                        onPressed: widget.onDone,
                        icon: const Icon(Icons.dashboard_outlined),
                        label: const Text('กลับไปดูคอนเทนต์'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublishTimeline extends StatelessWidget {
  const _PublishTimeline({required this.scheduled});

  final bool scheduled;

  @override
  Widget build(BuildContext context) {
    final labels = [
      ('รับคำสั่งแล้ว', Icons.check_rounded),
      ('เข้าคิวเผยแพร่', Icons.hourglass_top_rounded),
      (
        scheduled ? 'รอถึงเวลาที่ตั้งไว้' : 'ส่งไปยัง TikTok',
        Icons.rocket_launch_outlined,
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.t.primary.withValues(alpha: .16),
                  shape: BoxShape.circle,
                  border: Border.all(color: context.t.primary),
                ),
                child: Icon(labels[i].$2, size: 16, color: context.t.primary),
              ),
              const SizedBox(width: Spacing.md),
              Text(labels[i].$1),
            ],
          ),
          if (i != labels.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 2,
                  height: 22,
                  color: context.t.primary.withValues(alpha: .45),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ConsentText extends StatelessWidget {
  const _ConsentText({required this.showBrandedPolicy});
  final bool showBrandedPolicy;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: context.t.textSecondary, fontSize: 12);
    final link = TextStyle(
      color: context.t.primary,
      fontSize: 12,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'เมื่อกดโพสต์ ถือว่าคุณยอมรับ '),
          TextSpan(
            text: 'Music Usage Confirmation',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _open(_musicPolicyUrl),
          ),
          if (showBrandedPolicy) ...[
            const TextSpan(text: ' และ '),
            TextSpan(
              text: 'Branded Content Policy',
              style: link,
              recognizer: TapGestureRecognizer()
                ..onTap = () => _open(_brandedPolicyUrl),
            ),
          ],
          const TextSpan(text: ' ของ TikTok'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── ชิ้นส่วนที่ใช้ซ้ำ ─────────────────────────────────────────

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.locked = false,
    this.icon,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool locked;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final activeColor = accent ?? context.t.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: value && !locked
            ? activeColor.withValues(alpha: .075)
            : context.t.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: value && !locked
              ? activeColor.withValues(alpha: .34)
              : context.t.border,
        ),
      ),
      child: Material(
        color: context.t.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(Radii.md),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 8),
          secondary: icon == null
              ? null
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        (value && !locked
                                ? activeColor
                                : context.t.textSecondary)
                            .withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    locked ? Icons.lock_outline_rounded : icon,
                    color: value && !locked
                        ? activeColor
                        : context.t.textSecondary,
                    size: 18,
                  ),
                ),
          title: Text(
            title,
            style: TextStyle(
              color: locked ? context.t.textSecondary : context.t.textPrimary,
              fontWeight: value && !locked ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          subtitle: subtitle == null
              ? locked
                    ? Text(
                        'บัญชีนี้ปิดการใช้งานไว้',
                        style: TextStyle(
                          color: context.t.textSecondary,
                          fontSize: 11,
                        ),
                      )
                    : null
              : Text(
                  subtitle!,
                  style: TextStyle(
                    color: context.t.textSecondary,
                    fontSize: 12,
                  ),
                ),
          value: locked ? false : value,
          activeThumbColor: activeColor,
          activeTrackColor: activeColor.withValues(alpha: .36),
          // onChanged เป็น null = Flutter disable ตัว switch ให้เอง
          onChanged: locked
              ? null
              : (next) {
                  HapticFeedback.selectionClick();
                  onChanged(next);
                },
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _ComposerBadge extends StatelessWidget {
  const _ComposerBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: context.t.textSecondary),
      const SizedBox(width: Spacing.sm),
      Expanded(
        child: Text(
          text,
          style: TextStyle(color: context.t.textSecondary, fontSize: 12),
        ),
      ),
    ],
  );
}

class _Loading extends StatelessWidget {
  const _Loading({this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: error == null
            ? const [
                CircularProgressIndicator(),
                SizedBox(height: Spacing.md),
                Text('กำลังโหลดข้อมูลบัญชี…'),
              ]
            : [
                Icon(Icons.error_outline, color: context.t.error, size: 40),
                const SizedBox(height: Spacing.md),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: Spacing.lg),
                FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
              ],
      ),
    ),
  );
}
