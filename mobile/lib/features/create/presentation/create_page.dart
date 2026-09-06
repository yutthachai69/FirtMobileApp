import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/tokens.dart';
import '../../composer/domain/composer_state.dart';
import 'create_controller.dart';

/// หน้าสร้างคอนเทนต์: เลือกวิดีโอ → อัป → เขียนคำบรรยาย → ไปหน้า Composer
class CreatePage extends StatefulWidget {
  const CreatePage({super.key, required this.controller});
  final CreateController controller;

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final _caption = TextEditingController();
  VideoPlayerController? _player;

  /// ความยาววิดีโอ อ่านจากไฟล์ที่อัปแล้ว
  /// ส่งต่อให้หน้า Composer ใช้ตรวจกฎ R7 (ห้ามยาวเกินที่บัญชีรองรับ)
  int _durationSec = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.loadConnections();
    widget.controller.addListener(_onStep);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStep);
    _caption.dispose();
    _player?.dispose();
    super.dispose();
  }

  /// _onStep เตรียม preview ทันทีที่อัปเสร็จ
  void _onStep() {
    final url = widget.controller.previewUrl;
    if (url == null || url.isEmpty || _player != null) return;

    final p = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = p;
    p.initialize().then((_) {
      if (!mounted) return;
      setState(() => _durationSec = p.value.duration.inSeconds);
    }).catchError((_) {
      // อ่าน metadata ไม่ได้ก็ไม่ควรบล็อกผู้ใช้
      // หน้า Composer จะข้ามการตรวจความยาวไปเอง (ส่ง 0)
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;

          return Scaffold(
            appBar: AppBar(
              title: const Text('สร้างคอนเทนต์'),
              actions: [
                if (c.step != CreateStep.pick && !c.busy)
                  TextButton(
                    onPressed: () {
                      _player?.dispose();
                      _player = null;
                      _caption.clear();
                      _durationSec = 0;
                      c.reset();
                    },
                    child: const Text('เริ่มใหม่'),
                  ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(Spacing.md),
                children: [
                  if (c.connectionsLoaded && c.target == null)
                    _NoConnection(onTap: () => context.push('/connections')),

                  if (c.error != null) ...[
                    _ErrorBox(message: c.error!),
                    const SizedBox(height: Spacing.md),
                  ],

                  switch (c.step) {
                    CreateStep.pick => _PickStep(controller: c),
                    CreateStep.uploading => _UploadingStep(controller: c),
                    _ => _DescribeStep(
                        controller: c,
                        caption: _caption,
                        player: _player,
                        durationSec: _durationSec,
                        onContinue: () => _goToComposer(context),
                      ),
                  },
                ],
              ),
            ),
          );
        },
      );

  Future<void> _goToComposer(BuildContext context) async {
    final c = widget.controller;
    if (!await c.saveContent()) return;
    if (!context.mounted || !c.canContinue) return;

    await _player?.pause();
    if (!context.mounted) return;

    context.push(
      '/composer',
      extra: ComposerArgs(
        contentId: c.contentId!,
        connectionId: c.target!.id,
        videoDurationSec: _durationSec,
        // V0.1 อัปเอง ยังไม่มี AI — พอมี Veo ค่อยตั้งเป็น true ตาม media.source
        isAigc: false,
      ),
    );
  }
}

/// ComposerArgs ส่งข้อมูลข้ามหน้าให้ Composer
class ComposerArgs {
  const ComposerArgs({
    required this.contentId,
    required this.connectionId,
    required this.videoDurationSec,
    required this.isAigc,
  });

  final String contentId;
  final String connectionId;
  final int videoDurationSec;
  final bool isAigc;
}

// ── ขั้นตอนที่ 1: เลือกวิดีโอ ─────────────────────────────────

class _PickStep extends StatelessWidget {
  const _PickStep({required this.controller});
  final CreateController controller;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const SizedBox(height: Spacing.xl),
          Icon(Icons.video_library_outlined,
              size: 56, color: context.t.textSecondary),
          const SizedBox(height: Spacing.md),
          Text('เลือกวิดีโอที่จะโพสต์',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Spacing.sm),
          Text(
            'รองรับ MP4 และ MOV ขนาดไม่เกิน 100 MB',
            style: TextStyle(color: context.t.textSecondary),
          ),
          const SizedBox(height: Spacing.xl),
          FilledButton.icon(
            onPressed: controller.busy ? null : controller.pickAndUpload,
            icon: const Icon(Icons.add_rounded),
            label: const Text('เลือกวิดีโอ'),
          ),
        ],
      );
}

// ── ขั้นตอนที่ 2: กำลังอัป ────────────────────────────────────

class _UploadingStep extends StatelessWidget {
  const _UploadingStep({required this.controller});
  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    final pct = (controller.progress * 100).clamp(0, 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.xl),
        Text('กำลังอัปโหลด…',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Spacing.sm),
        Text(
          controller.video?.name ?? '',
          style: TextStyle(color: context.t.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Spacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: LinearProgressIndicator(
            value: controller.progress > 0 ? controller.progress : null,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          '$pct% · ${controller.video?.readableSize ?? ''}',
          style: TextStyle(color: context.t.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: Spacing.lg),
        // ไฟล์ไปที่ storage ตรง ๆ ไม่ผ่านเซิร์ฟเวอร์เรา จึงเร็วกว่าและไม่กินแบนด์วิดท์เรา
        Text(
          'วิดีโอถูกส่งขึ้นที่เก็บไฟล์โดยตรง ไม่ผ่านเซิร์ฟเวอร์ของเรา',
          style: TextStyle(color: context.t.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

// ── ขั้นตอนที่ 3: เขียนคำบรรยาย ───────────────────────────────

class _DescribeStep extends StatelessWidget {
  const _DescribeStep({
    required this.controller,
    required this.caption,
    required this.player,
    required this.durationSec,
    required this.onContinue,
  });

  final CreateController controller;
  final TextEditingController caption;
  final VideoPlayerController? player;
  final int durationSec;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final over = c.caption.runes.length > kMaxCaptionRunes;
    final ready = player?.value.isInitialized ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: context.t.success, size: 18),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                'อัปโหลดเสร็จแล้ว${durationSec > 0 ? ' · ${_len(durationSec)}' : ''}',
                style: TextStyle(color: context.t.success),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),

        if (ready)
          _Preview(player: player!)
        else
          Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.t.surfaceContainer,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: context.t.border),
            ),
            child: const CircularProgressIndicator(),
          ),

        const SizedBox(height: Spacing.lg),
        Text('คำบรรยาย', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: caption,
          onChanged: c.setCaption,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'เขียนคำบรรยาย… ใส่ #แฮชแท็ก ได้',
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${c.caption.runes.length} / $kMaxCaptionRunes',
            style: TextStyle(
              fontSize: 12,
              color: over ? context.t.error : context.t.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: Spacing.lg),
        FilledButton(
          onPressed: (c.busy || over || c.target == null) ? null : onContinue,
          child: c.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('ถัดไป — ตั้งค่าโพสต์'),
        ),
        if (c.target == null) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            'ต้องเชื่อมบัญชี TikTok ก่อนถึงจะตั้งเวลาโพสต์ได้',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.t.warning, fontSize: 13),
          ),
        ],
      ],
    );
  }

  static String _len(int s) =>
      s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')} นาที' : '$s วินาที';
}

class _Preview extends StatefulWidget {
  const _Preview({required this.player});
  final VideoPlayerController player;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  @override
  Widget build(BuildContext context) {
    final p = widget.player;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: AspectRatio(
        aspectRatio: p.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(p),
            IconButton.filled(
              onPressed: () {
                setState(() => p.value.isPlaying ? p.pause() : p.play());
              },
              icon: Icon(p.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ส่วนประกอบเล็ก ๆ ──────────────────────────────────────────

class _NoConnection extends StatelessWidget {
  const _NoConnection({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: Spacing.md),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: context.t.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.link_off_rounded, color: context.t.warning, size: 20),
            const SizedBox(width: Spacing.sm),
            const Expanded(
              child: Text('ยังไม่ได้เชื่อมบัญชี TikTok',
                  style: TextStyle(fontSize: 13)),
            ),
            TextButton(onPressed: onTap, child: const Text('เชื่อมเลย')),
          ],
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: context.t.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: context.t.error, size: 20),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(message, style: TextStyle(color: context.t.error)),
              ),
            ),
          ],
        ),
      );
}
