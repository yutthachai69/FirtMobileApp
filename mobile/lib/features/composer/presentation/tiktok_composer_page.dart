import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
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
  const TikTokComposerPage({super.key, required this.controller});
  final ComposerController controller;

  @override
  State<TikTokComposerPage> createState() => _TikTokComposerPageState();
}

class _TikTokComposerPageState extends State<TikTokComposerPage> {
  final _caption = TextEditingController();

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
                        _CaptionField(
                          controller: _caption,
                          state: s,
                          onChanged: c.setCaption,
                        ),
                        const SizedBox(height: Spacing.lg),
                        _PrivacySection(state: s, onChanged: c.setPrivacy),
                        const SizedBox(height: Spacing.lg),
                        _InteractionSection(state: s, controller: c),
                        const SizedBox(height: Spacing.lg),
                        _DisclosureSection(state: s, controller: c),
                        if (s.isAigc) ...[
                          const SizedBox(height: Spacing.md),
                          const _AigcNotice(),
                        ],
                        const SizedBox(height: Spacing.xl),
                        _ConsentAndPost(state: s, controller: c),
                        const SizedBox(height: Spacing.xl),
                      ],
                    ),
            ),
          );
        },
      );
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
          _Label('ใครดูวิดีโอนี้ได้'),
          const SizedBox(height: Spacing.sm),
          DropdownButtonFormField<PrivacyLevel>(
            // value เป็น null จนกว่าผู้ใช้จะเลือก — ห้ามใส่ค่าตั้งต้น
            initialValue: state.privacyLevel,
            hint: const Text('เลือก'),
            isExpanded: true,
            // ตัวเลือกมาจาก creator_info เท่านั้น ห้ามใส่รายการเอง
            items: [
              for (final level in state.privacyOptions)
                DropdownMenuItem(value: level, child: Text(level.label)),
            ],
            onChanged: onChanged,
          ),
          if (!(state.creator?.canPublishPublic ?? true)) ...[
            const SizedBox(height: Spacing.sm),
            _Note(
              icon: Icons.lock_outline_rounded,
              text: 'บัญชีนี้ยังโพสต์สาธารณะไม่ได้ '
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
            title: 'แสดงความคิดเห็น',
            value: state.allowComment,
            // ปิดจากฝั่งบัญชี = disable ทั้งช่อง ไม่ใช่แค่ปล่อยว่าง
            locked: state.commentLocked,
            onChanged: controller.setAllowComment,
          ),
          _Toggle(
            title: 'Duet',
            value: state.allowDuet,
            locked: state.duetLocked,
            onChanged: controller.setAllowDuet,
          ),
          _Toggle(
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
                    title: 'แบรนด์ของคุณเอง',
                    subtitle: 'โปรโมตสินค้าหรือบริการของตัวเอง',
                    value: state.brandOrganic,
                    onChanged: controller.setBrandOrganic,
                  ),
                  _Toggle(
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
  const _ConsentAndPost({required this.state, required this.controller});
  final ComposerState state;
  final ComposerController controller;

  @override
  Widget build(BuildContext context) {
    final reason = state.postBlockedReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ข้อความนี้ต้องอยู่ "เหนือ" ปุ่มเสมอตามกฎของ TikTok
        _ConsentText(showBrandedPolicy: state.brandedContent),
        const SizedBox(height: Spacing.md),

        FilledButton(
          onPressed: state.canPost ? () => _submit(context) : null,
          child: state.submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(state.scheduledAt == null ? 'โพสต์เลย' : 'ตั้งเวลาโพสต์'),
        ),

        // บอกเสมอว่าติดตรงไหน ไม่ปล่อยให้ผู้ใช้เดาว่าทำไมปุ่มกดไม่ได้
        if (reason != null) ...[
          const SizedBox(height: Spacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.t.warning, fontSize: 13),
            ),
          ),
        ],

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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await controller.submit();
    if (!ok) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('ตั้งเวลาโพสต์เรียบร้อย')),
    );
    if (navigator.canPop()) navigator.pop(true);
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
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: TextStyle(
            color: locked ? context.t.textSecondary : context.t.textPrimary,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(color: context.t.textSecondary, fontSize: 12),
              ),
        value: locked ? false : value,
        // onChanged เป็น null = Flutter disable ตัว switch ให้เอง
        onChanged: locked ? null : onChanged,
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
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
                    Icon(Icons.error_outline,
                        color: context.t.error, size: 40),
                    const SizedBox(height: Spacing.md),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: Spacing.lg),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('ลองใหม่'),
                    ),
                  ],
          ),
        ),
      );
}
