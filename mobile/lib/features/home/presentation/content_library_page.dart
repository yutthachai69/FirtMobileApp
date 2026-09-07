import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../domain/home_data.dart';
import 'home_controller.dart';
import 'home_page.dart' show JobCard;

/// รายการคอนเทนต์ทั้งหมด — แท็บ "คอนเทนต์" ของ bottom nav
///
/// ใช้ [HomeController] ตัวเดียวกับหน้าหลัก ไม่ยิง API ซ้ำ
/// เพราะข้อมูลชุดเดียวกัน (publish_jobs + contents) แค่มุมมองต่างกัน:
/// หน้าหลักจัดกลุ่มตามความเร่งด่วน หน้านี้กรองแบบ flat ตามสถานะ
class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({super.key, required this.controller});
  final HomeController controller;

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

enum _Filter { all, needAction, working, scheduled, published }

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    // หน้าหลักโหลดไว้ก่อนแล้วเกือบทุกครั้ง แต่กันไว้เผื่อเข้าหน้านี้ตรง ๆ
    if (!widget.controller.loaded) widget.controller.load();
  }

  List<PublishJob> _jobsFor(HomeData data) => switch (_filter) {
        _Filter.all => [
            ...data.working,
            ...data.scheduled,
            ...data.publishedToday,
          ],
        _Filter.needAction => const [], // action item ไม่ใช่ PublishJob โดยตรง
        _Filter.working => data.working,
        _Filter.scheduled => data.scheduled,
        _Filter.published => data.publishedToday,
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          final data = c.data;

          return Scaffold(
            appBar: AppBar(title: const Text('คอนเทนต์')),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: c.load,
                child: !c.loaded && c.loading
                    ? const Center(child: CircularProgressIndicator())
                    : data == null
                        ? _errorBody(c)
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
    final counts = <_Filter, int>{
      _Filter.all: data.working.length +
          data.scheduled.length +
          data.publishedToday.length,
      _Filter.needAction: data.needAction.length,
      _Filter.working: data.working.length,
      _Filter.scheduled: data.scheduled.length,
      _Filter.published: data.publishedToday.length,
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
        if (_filter == _Filter.needAction)
          Text(
            'ดูรายการที่ต้องทำได้ที่หน้าหลัก',
            style: TextStyle(color: context.t.textSecondary),
          )
        else if (jobs.isEmpty)
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
          for (final job in jobs) JobCard(job: job),
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
