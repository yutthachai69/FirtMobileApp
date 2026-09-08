import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../showcase/domain/showcase_product.dart';

enum _AiStep { brief, script, preview, approved }

class AiCreatePage extends StatefulWidget {
  const AiCreatePage({super.key, required this.product});

  final ShowcaseProduct product;

  @override
  State<AiCreatePage> createState() => _AiCreatePageState();
}

class _AiCreatePageState extends State<AiCreatePage> {
  _AiStep _step = _AiStep.brief;
  int _concept = 0;
  int _duration = 30;
  int _tone = 0;
  int _voice = 0;
  int _variant = 0;
  bool _subtitles = true;
  bool _generating = false;
  int _generationRun = 0;
  late final TextEditingController _script;

  static const _concepts = [
    (
      'รีวิวป้ายยาแบบจริงใจ',
      'เล่าปัญหาและผลลัพธ์แบบเพื่อนแนะนำเพื่อน',
      Icons.record_voice_over_outlined,
    ),
    (
      'แกะกล่องทดลองใช้',
      'โชว์แพ็กเกจ เนื้อสัมผัส และความรู้สึกแรก',
      Icons.inventory_2_outlined,
    ),
    (
      'เทียบก่อนใช้–หลังใช้',
      'เล่าความเปลี่ยนแปลงด้วยหลักฐานที่ตรวจสอบได้',
      Icons.compare_rounded,
    ),
  ];
  static const _tones = ['เป็นกันเอง', 'ผู้เชี่ยวชาญ', 'สนุกกระตือรือร้น'];
  static const _voices = [
    'มิน — สดใส',
    'นัท — เป็นกันเอง',
    'พริม — น่าเชื่อถือ',
  ];

  @override
  void initState() {
    super.initState();
    _script = TextEditingController(text: _makeScript());
  }

  @override
  void dispose() {
    _script.dispose();
    super.dispose();
  }

  String _makeScript() {
    final p = widget.product;
    return 'หยุดก่อน ถ้าคุณกำลังมองหา ${p.name}\n\n'
        'เราเลือกจุดเด่นที่ตรวจสอบได้มาให้แล้ว: ${p.sellingPoints.take(2).join(' และ ')}\n\n'
        'ดูรายละเอียดสินค้าและโปรล่าสุดได้ที่ตะกร้าในคลิปนี้';
  }

  void _back() {
    if (_generating) return;
    if (_step == _AiStep.brief) {
      context.go('/create', extra: widget.product);
      return;
    }
    setState(() => _step = _AiStep.values[_step.index - 1]);
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _AiStep.approved) return _Approved(product: widget.product);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          children: [
            Text(
              _generating ? 'กำลังสร้างคลิป' : _title,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _generating
                  ? 'AI CREATIVE ENGINE'
                  : 'ขั้นตอน ${_step.index + 1} จาก 3',
              style: TextStyle(color: context.t.primary, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'เกี่ยวกับขั้นตอนนี้',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Text(
                  'ข้อมูลทั้งหมดในโหมดทดลองเก็บอยู่ในเครื่อง คุณแก้สคริปต์และเลือกเวอร์ชันได้ก่อนอนุมัติ',
                  style: TextStyle(height: 1.6),
                ),
              ),
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_step.index + 1) / 3,
            minHeight: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _generating
              ? _GenerationView(product: widget.product)
              : switch (_step) {
                  _AiStep.brief => _brief(),
                  _AiStep.script => _scriptStep(),
                  _AiStep.preview => _preview(),
                  _AiStep.approved => const SizedBox.shrink(),
                },
        ),
      ),
      bottomNavigationBar: _generating
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  8,
                  Spacing.md,
                  12,
                ),
                child: OutlinedButton.icon(
                  key: const Key('cancel-ai-generation'),
                  onPressed: _cancelGeneration,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('ยกเลิกและกลับไปแก้สคริปต์'),
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  8,
                  Spacing.md,
                  12,
                ),
                child: FilledButton.icon(
                  key: const Key('ai-next'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _step == _AiStep.preview
                        ? context.t.success
                        : context.t.creative,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (_step == _AiStep.script) {
                      _startGeneration();
                    } else {
                      setState(() => _step = _AiStep.values[_step.index + 1]);
                    }
                  },
                  icon: Icon(
                    _step == _AiStep.preview
                        ? Icons.check_circle_outline_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    _step == _AiStep.preview
                        ? 'อนุมัติคลิปนี้'
                        : _step == _AiStep.brief
                        ? 'สร้างสคริปต์ตัวอย่าง'
                        : 'สร้างตัวอย่างคลิป',
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _startGeneration() async {
    final run = ++_generationRun;
    setState(() => _generating = true);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted || run != _generationRun) return;
    setState(() {
      _generating = false;
      _step = _AiStep.preview;
    });
  }

  void _cancelGeneration() {
    _generationRun++;
    setState(() {
      _generating = false;
      _step = _AiStep.script;
    });
    _toast('ยกเลิกการสร้างแล้ว คุณแก้สคริปต์และลองใหม่ได้');
  }

  String get _title => switch (_step) {
    _AiStep.brief => 'กำหนดแนวทาง',
    _AiStep.script => 'สคริปต์และเสียง',
    _AiStep.preview => 'ตรวจสอบคลิป',
    _AiStep.approved => 'พร้อมใช้งาน',
  };

  Widget _brief() => ListView(
    key: const ValueKey('brief'),
    padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, 24),
    children: [
      _ProductSummary(product: widget.product),
      const SizedBox(height: Spacing.lg),
      _SectionTitle(icon: Icons.videocam_outlined, text: 'เลือกสไตล์คลิป'),
      const SizedBox(height: 10),
      for (var i = 0; i < _concepts.length; i++) ...[
        _SelectCard(
          icon: _concepts[i].$3,
          title: _concepts[i].$1,
          description: _concepts[i].$2,
          selected: _concept == i,
          onTap: () => setState(() => _concept = i),
        ),
        const SizedBox(height: 9),
      ],
      const SizedBox(height: 10),
      const _SectionTitle(icon: Icons.timer_outlined, text: 'ความยาวคลิป'),
      const SizedBox(height: 10),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 15, label: Text('15 วินาที')),
          ButtonSegment(value: 30, label: Text('30 วินาที')),
          ButtonSegment(value: 60, label: Text('60 วินาที')),
        ],
        selected: {_duration},
        onSelectionChanged: (v) => setState(() => _duration = v.first),
      ),
      const SizedBox(height: Spacing.lg),
      const _SectionTitle(icon: Icons.mood_outlined, text: 'น้ำเสียงการพูด'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _tones.length; i++)
            ChoiceChip(
              label: Text(_tones[i]),
              selected: _tone == i,
              onSelected: (_) => setState(() => _tone = i),
            ),
        ],
      ),
      const SizedBox(height: Spacing.lg),
      _EngineCard(duration: _duration),
    ],
  );

  Widget _scriptStep() => ListView(
    key: const ValueKey('script'),
    padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, 24),
    children: [
      Row(
        children: [
          const Expanded(
            child: _SectionTitle(
              icon: Icons.auto_awesome,
              text: 'สคริปต์ AI 3 ฉาก',
            ),
          ),
          _ScoreBadge(score: 92),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('ai-script'),
        controller: _script,
        minLines: 8,
        maxLines: 12,
        decoration: const InputDecoration(
          labelText: 'แก้บทพูดได้โดยตรง',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: Spacing.lg),
      const _SectionTitle(
        icon: Icons.graphic_eq_rounded,
        text: 'เสียงพากย์ AI',
      ),
      const SizedBox(height: 10),
      for (var i = 0; i < _voices.length; i++)
        _VoiceOption(
          label: _voices[i],
          selected: _voice == i,
          onSelect: () => setState(() => _voice = i),
          onPreview: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('กำลังเล่นเสียงตัวอย่าง ${_voices[i]}')),
          ),
        ),
      const SizedBox(height: 8),
      SwitchListTile(
        value: _subtitles,
        onChanged: (v) => setState(() => _subtitles = v),
        title: const Text('เปิดคำบรรยายอัตโนมัติ'),
        subtitle: const Text('เน้นคำสำคัญแบบ TikTok Pop'),
        secondary: const Icon(Icons.subtitles_outlined),
      ),
      const SizedBox(height: Spacing.md),
      _InfoBox(
        icon: Icons.verified_user_outlined,
        text: 'สคริปต์อ้างอิงเฉพาะข้อมูลสินค้าในระบบ และต้องให้คุณตรวจอีกครั้ง',
        color: context.t.success,
      ),
    ],
  );

  Widget _preview() => ListView(
    key: const ValueKey('preview'),
    padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, 24),
    children: [
      _VideoMock(
        product: widget.product,
        duration: _duration,
        variant: _variant,
      ),
      const SizedBox(height: Spacing.md),
      const _SectionTitle(
        icon: Icons.view_carousel_outlined,
        text: 'เลือกเวอร์ชัน',
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                child: _VariantCard(
                  key: Key('variant-$i'),
                  index: i,
                  selected: _variant == i,
                  onTap: () => setState(() => _variant = i),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: Spacing.lg),
      _SafetyCard(product: widget.product),
      const SizedBox(height: Spacing.lg),
      const _SectionTitle(icon: Icons.tune_rounded, text: 'ปรับแต่งด่วน'),
      const SizedBox(height: 10),
      Row(
        children: [
          _QuickAction(
            icon: Icons.content_cut,
            label: 'ตัดสั้นลง',
            onTap: () => _toast('ปรับ Hook ให้สั้นลงแล้ว'),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.record_voice_over,
            label: 'เปลี่ยนเสียง',
            onTap: () => setState(() => _step = _AiStep.script),
          ),
          const SizedBox(width: 8),
          _QuickAction(
            icon: Icons.edit_note,
            label: 'แก้ Hook',
            onTap: () => setState(() => _step = _AiStep.script),
          ),
        ],
      ),
    ],
  );

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _GenerationView extends StatelessWidget {
  const _GenerationView({required this.product});

  final ShowcaseProduct product;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2100),
        builder: (context, progress, _) => Column(
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [context.t.creative, context.t.primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.t.primary.withValues(alpha: .22),
                    blurRadius: 28 + (progress * 12),
                    spreadRadius: progress * 3,
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: progress * 6.28,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'กำลังประกอบเรื่องให้ขายได้',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.t.textSecondary),
            ),
            const SizedBox(height: Spacing.xl),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress, minHeight: 7),
            ),
            const SizedBox(height: 9),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: context.t.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            _GenerationTask(
              done: progress >= .25,
              active: progress < .25,
              text: 'วิเคราะห์จุดขายและ Hook',
            ),
            _GenerationTask(
              done: progress >= .62,
              active: progress >= .25 && progress < .62,
              text: 'สร้างเสียงพากย์และคำบรรยาย',
            ),
            _GenerationTask(
              done: progress >= .96,
              active: progress >= .62,
              text: 'ประกอบฉากและตรวจข้อมูลสินค้า',
            ),
          ],
        ),
      ),
    ),
  );
}

class _GenerationTask extends StatelessWidget {
  const _GenerationTask({
    required this.done,
    required this.active,
    required this.text,
  });

  final bool done;
  final bool active;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: done
              ? Icon(
                  Icons.check_circle_rounded,
                  key: ValueKey('$text-done'),
                  color: context.t.success,
                  size: 20,
                )
              : active
              ? SizedBox(
                  key: ValueKey('$text-active'),
                  width: 20,
                  height: 20,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.circle_outlined,
                  key: ValueKey('$text-wait'),
                  color: context.t.textSecondary,
                  size: 20,
                ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: done || active
                ? context.t.textPrimary
                : context.t.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({required this.product});
  final ShowcaseProduct product;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.border),
    ),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.t.surfaceElevated,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(Icons.shopping_bag_outlined, color: context.t.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'คอมมิชชัน ${product.commissionPercent}% · +฿${product.commissionBaht}/ออเดอร์',
                style: TextStyle(color: context.t.success, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: context.t.primary, size: 20),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ],
  );
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? context.t.primary.withValues(alpha: .07)
        : context.t.surfaceContainer,
    borderRadius: BorderRadius.circular(Radii.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: selected ? context.t.primary : context.t.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? context.t.primary : context.t.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.t.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? context.t.primary : context.t.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({required this.duration});
  final int duration;
  @override
  Widget build(BuildContext context) => _InfoBox(
    icon: Icons.bolt_rounded,
    text:
        'พร้อมสร้างสคริปต์ $duration วินาที · ประมาณ 3 ฉาก · ตรวจคำเคลมสินค้าอัตโนมัติ',
    color: context.t.primary,
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.45)),
        ),
      ],
    ),
  );
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: context.t.success.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'Hook $score/100',
      style: TextStyle(
        color: context.t.success,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _VoiceOption extends StatelessWidget {
  const _VoiceOption({
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.onPreview,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? context.t.primary : context.t.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? context.t.primary : context.t.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              IconButton(
                tooltip: 'ทดลองฟัง',
                onPressed: onPreview,
                icon: const Icon(Icons.play_circle_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VideoMock extends StatelessWidget {
  const _VideoMock({
    required this.product,
    required this.duration,
    required this.variant,
  });
  final ShowcaseProduct product;
  final int duration;
  final int variant;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 238,
      height: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.t.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.t.surfaceElevated,
            context.t.creative.withValues(alpha: .3),
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 64,
              color: context.t.primary,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _TinyBadge(text: 'ตัวอย่าง V${variant + 1} · 1080P'),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: context.t.warning,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shopping_bag,
                        size: 16,
                        color: Color(0xFF382900),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'ตะกร้า · ฿${product.priceBaht}',
                          style: const TextStyle(
                            color: Color(0xFF382900),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: .46, minHeight: 3),
                const SizedBox(height: 4),
                Text(
                  '00:14 / 00:${duration.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: context.t.surface.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: const TextStyle(fontSize: 9)),
  );
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    super.key,
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(Radii.md),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.t.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: selected ? context.t.primary : context.t.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            index == 0
                ? Icons.flash_on_outlined
                : index == 1
                ? Icons.favorite_border
                : Icons.workspace_premium_outlined,
            color: selected ? context.t.primary : context.t.textSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            ['Hook ไว', 'เล่าเรื่อง', 'พรีเมียม'][index],
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.product});
  final ShowcaseProduct product;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Spacing.md),
    decoration: BoxDecoration(
      color: context.t.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: context.t.success.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_user_outlined, color: context.t.success),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ตรวจความพร้อมแล้ว',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'ผ่าน 3/3',
              style: TextStyle(color: context.t.success, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _CheckLine(text: 'ไม่พบคำเคลมเกินข้อมูลสินค้า'),
        const _CheckLine(text: 'วิดีโอแนวตั้ง Full HD พร้อมซับ'),
        _CheckLine(text: 'เตรียมตะกร้า ${product.name} แล้ว'),
      ],
    ),
  );
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      children: [
        Icon(Icons.check_circle_rounded, color: context.t.success, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      ),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}

class _Approved extends StatelessWidget {
  const _Approved({required this.product});
  final ShowcaseProduct product;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: context.t.success.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: context.t.success,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'อนุมัติคลิปแล้ว',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'บันทึกเป็นฉบับร่างพร้อมสินค้า ${product.name} แล้ว',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.t.textSecondary, height: 1.5),
              ),
              const SizedBox(height: Spacing.lg),
              _InfoBox(
                icon: Icons.shopping_bag_outlined,
                text: 'ขั้นต่อไปจะเป็นการตรวจตะกร้า แคปชัน และเวลาเผยแพร่',
                color: context.t.warning,
              ),
              const SizedBox(height: Spacing.lg),
              FilledButton.icon(
                onPressed: () => context.go('/create/publish', extra: product),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('ตรวจตะกร้าและเผยแพร่'),
              ),
              TextButton(
                onPressed: () => context.go('/create', extra: product),
                child: const Text('สร้างอีกเวอร์ชัน'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
