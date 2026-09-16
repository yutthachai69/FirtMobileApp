import '../../home/domain/content_store.dart';
import '../../home/domain/home_data.dart';
import 'showcase_product.dart';

/// Opportunity Radar — บอกว่าสินค้าตัวไหนควรหยิบมาทำคอนเทนต์ต่อ
///
/// อยู่บนหน้า Showcase เท่านั้น ไม่มีหน้าของตัวเอง ทุกใบพาไปสร้างงานได้
/// เรียงความสำคัญ: เคยทำแล้วได้ผล > ใกล้หมดสต็อก > คอมสูงยังไม่มีคลิป > ยังไม่มีคลิป

enum OpportunityKind { proven, lowStock, highCommission, noContent }

class Opportunity {
  const Opportunity({
    required this.kind,
    required this.product,
    required this.headline,
    required this.detail,
  });

  final OpportunityKind kind;
  final ShowcaseProduct product;
  final String headline;
  final String detail;

  int get _priority => switch (kind) {
    OpportunityKind.proven => 0,
    OpportunityKind.lowStock => 1,
    OpportunityKind.highCommission => 2,
    OpportunityKind.noContent => 3,
  };

  /// สแกนสินค้าทั้งหมด คืนคำแนะนำหนึ่งใบต่อสินค้า (ใบที่สำคัญสุด)
  static List<Opportunity> scan({
    required List<ShowcaseProduct> products,
    required ContentStore store,
    bool includeOrderMetrics = true,
  }) {
    final out = <Opportunity>[];
    for (final p in products) {
      final jobs = store.byProduct(p.id);
      final published = jobs
          .where((j) => j.status == JobStatus.published)
          .toList();
      final revenue = includeOrderMetrics
          ? published.fold<int>(
              0,
              (sum, j) => sum + mockOrdersFor(j) * p.commissionBaht,
            )
          : 0;

      if (includeOrderMetrics && published.isNotEmpty && revenue >= 400) {
        out.add(
          Opportunity(
            kind: OpportunityKind.proven,
            product: p,
            headline: 'เคยทำเงินให้คุณ',
            detail:
                '฿$revenue จาก ${published.length} คลิป — ทำเวอร์ชันใหม่ต่อยอด',
          ),
        );
        continue;
      }

      if (p.inStock && p.stock <= 400) {
        out.add(
          Opportunity(
            kind: OpportunityKind.lowStock,
            product: p,
            headline: 'ใกล้หมดสต็อก',
            detail: 'เหลือ ${p.stock} ชิ้น รีบทำคลิปก่อนของหมด',
          ),
        );
        continue;
      }

      if (jobs.isEmpty && p.inStock && p.commissionPercent >= 15) {
        out.add(
          Opportunity(
            kind: OpportunityKind.highCommission,
            product: p,
            headline: 'คอมมิชชันสูง',
            detail:
                'ได้ ฿${p.commissionBaht}/ชิ้น (${p.commissionPercent}%) '
                'ยังไม่มีคลิป',
          ),
        );
        continue;
      }

      if (jobs.isEmpty && p.inStock) {
        out.add(
          Opportunity(
            kind: OpportunityKind.noContent,
            product: p,
            headline: 'ยังไม่มีคอนเทนต์',
            detail: 'เริ่มคลิปแรกให้สินค้านี้',
          ),
        );
      }
    }

    out.sort((a, b) => a._priority.compareTo(b._priority));
    return out;
  }
}
