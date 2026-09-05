-- กันการแจ้งเตือนซ้ำเรื่องเดียวกันแบบ atomic
--
-- ทำไมต้องเป็น unique index ไม่ใช่ SELECT-แล้วค่อย-INSERT:
-- สาเหตุเดียวมักกระทบหลายงานพร้อมกัน (token หลุดครั้งเดียว แต่มีงานค้าง 5 ชิ้น)
-- worker ทำงานขนานกัน ทุกตัวจะ SELECT ไม่เจอพร้อมกันแล้วต่างคนต่าง INSERT
-- ผู้ใช้ก็ได้ push 5 อันเรื่องเดียวกัน
--
-- จำกัดเฉพาะที่ยังไม่อ่าน: พอผู้ใช้อ่านแล้ว ถ้าเกิดเรื่องเดิมอีกก็ควรแจ้งได้ใหม่

-- ต้องเก็บกวาดของซ้ำที่มีอยู่ก่อน ไม่งั้นสร้าง unique index ไม่ผ่าน
-- เก็บอันล่าสุดไว้ให้ยังไม่อ่าน ที่เหลือถือว่าอ่านแล้ว
UPDATE notifications n
   SET read_at = now()
 WHERE n.data ->> 'dedupe_key' IS NOT NULL
   AND n.read_at IS NULL
   AND EXISTS (
       SELECT 1
         FROM notifications newer
        WHERE newer.user_id = n.user_id
          AND newer.type    = n.type
          AND newer.data ->> 'dedupe_key' = n.data ->> 'dedupe_key'
          AND newer.read_at IS NULL
          AND (newer.created_at, newer.id) > (n.created_at, n.id)
   );

CREATE UNIQUE INDEX idx_notifications_dedupe
    ON notifications (user_id, type, (data ->> 'dedupe_key'))
 WHERE data ->> 'dedupe_key' IS NOT NULL
   AND read_at IS NULL;
