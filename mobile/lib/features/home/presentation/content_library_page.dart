import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/skeleton.dart';
import '../../../core/config/app_config.dart';
import '../domain/content_store.dart';
import '../domain/home_data.dart';
import 'content_planner.dart';
import 'home_controller.dart';
import 'home_page.dart' show JobCard;

/// รายการคอนเทนต์ทั้งหมด — แท็บ "คอนเทนต์" ของ bottom nav
///
/// ใช้ [HomeController] ตัวเดียวกับหน้าหลัก ไม่ยิง API ซ้ำ
/// เพราะข้อมูลชุดเดียวกัน (publish_jobs + contents) แค่มุมมองต่างกัน:
/// หน้าหลักจัดกลุ่มตามความเร่งด่วน หน้านี้กรองแบบ flat ตามสถานะ
class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({super.key, required this.controller, this.store});
  final HomeController controller;

  /// แหล่งงานกลาง — ถ้าไม่มีข้อมูลจาก backend หน้านี้จะแสดงงานจาก store
  final ContentStore? store;

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

enum _Filter { all, needAction, working, scheduled, published }

enum _ViewMode { list, week }

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  _Filter _filter = _Filter.all;
  _ViewMode _view = _ViewMode.list;

  @override
  void initState() {
    super.initState();
    // หน้าหลักโหลดไว้ก่อนแล้วเกือบทุกครั้ง แต่กันไว้เผื่อเข้าหน้านี้ตรง ๆ
    if (!widget.controller.loaded) widget.controller.load();
  }

  /// true = กำลังแสดงงานจาก store (prototype) ไม่ใช่ข้อมูล backend
  bool _usingStore() => AppConfig.isDemo && widget.store != null;

  List<PublishJob> _sourceJobs(HomeData data) {
    return widget.store?.jobs ?? data.jobs;
  }

  List<PublishJob> _jobsFor(HomeData data) {
    final jobs = _sourceJobs(data);
    return switch (_filter) {
      _Filter.all => jobs,
      _Filter.needAction =>
        jobs
            .where(
              (j) =>
                  j.status == JobStatus.failed ||
                  j.status == JobStatus.awaitingReview,
            )
            .toList(),
      _Filter.working =>
        jobs
            .where((j) => j.status.isWorking || j.status == JobStatus.draft)
            .toList(),
      _Filter.scheduled =>
        jobs.where((j) => j.status == JobStatus.scheduled).toList(),
      _Filter.published =>
        jobs.where((j) => j.status == JobStatus.published).toList(),
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store == null
        ? widget.controller
        : Listenable.merge([widget.controller, widget.store!]),
    builder: (context, _) {
      final c = widget.controller;
      // ไม่มีข้อมูล backend แต่มี store -> ใช้ HomeData ว่างแล้วให้ _sourceJobs
      // ดึงงานจาก store มาแสดงแทนการขึ้นหน้า error
      final data = c.data ?? (widget.store != null ? const HomeData() : null);

      return Scaffold(
        appBar: AppBar(
          title: const Text('คอนเทนต์'),
          actions: [
            if (widget.store != null)
              SegmentedButton<_ViewMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: _ViewMode.list,
                    icon: Icon(Icons.view_list_rounded),
                  ),
                  ButtonSegment(
                    value: _ViewMode.week,
                    icon: Icon(Icons.calendar_view_week_rounded),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (v) => setState(() => _view = v.first),
              ),
            const SizedBox(width: Spacing.sm),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: c.load,
            child: !c.loaded && c.loading && widget.store == null
                ? const SkeletonList()
                : data == null
                ? _errorBody(c)
                : _view == _ViewMode.week && widget.store != null
                ? ContentPlanner(
                    jobs: _sourceJobs(data),
                    onReschedule: widget.store!.reschedule,
                    onOpen: (job) =>
                        context.go('/content/${job.id}', extra: job),
                  )
                : _list(context, data),
          ),
        ),
      );
    },
  );

  Widget _errorBody(HomeController c) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 120),
      Center(
        child: Column(
          children: [
            Text(c.error ?? 'โหลดข้อมูลไม่ได้'),
            const SizedBox(height: Spacing.md),
            FilledButton(onPressed: c.load, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    ],
  );

  Widget _list(BuildContext context, HomeData data) {
    final source = _sourceJobs(data);
    final counts = <_Filter, int>{
      _Filter.all: source.length,
      _Filter.needAction: source
          .where(
            (j) =>
                j.status == JobStatus.failed ||
                j.status == JobStatus.awaitingReview,
          )
          .length,
      _Filter.working: source
          .where((j) => j.status.isWorking || j.status == JobStatus.draft)
          .length,
      _Filter.scheduled: source
          .where((j) => j.status == JobStatus.scheduled)
          .length,
      _Filter.published: source
          .where((j) => j.status == JobStatus.published)
          .length,
    };
    final jobs = _jobsFor(data);

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: ChoiceChip(
                    label: Text('${_label(f)} (${counts[f]})'),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        if (_usingStore()) ...[
          _PreviewBanner(),
          const SizedBox(height: Spacing.md),
        ],
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'ยังไม่มีคอนเทนต์ในหมวดนี้',
                style: TextStyle(color: context.t.textSecondary),
              ),
            ),
          )
        else
          for (final job in jobs)
            JobCard(
              job: job,
              onTap: () => context.go('/content/${job.id}', extra: job),
            ),
      ],
    );
  }

  String _label(_Filter f) => switch (f) {
    _Filter.all => 'ทั้งหมด',
    _Filter.needAction => 'ต้องทำ',
    _Filter.working => 'กำลังสร้าง',
    _Filter.scheduled => 'ตั้งเวลาไว้',
    _Filter.published => 'โพสต์แล้ว',
  };
}

class _PreviewBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: context.t.primary.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: context.t.primary.withValues(alpha: .2)),
    ),
    child: const Row(
      children: [
        Icon(Icons.science_outlined, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'ข้อมูลตัวอย่างสำหรับทดสอบสถานะและการแก้ปัญหา',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
