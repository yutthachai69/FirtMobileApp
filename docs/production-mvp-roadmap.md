# RelayContent — Production MVP Roadmap

Updated: 14 September 2026

Current progress: **approximately 62% production-MVP ready** — Milestone 0 is
complete, Milestone 1 is nearly complete, and the first parts of Milestone 2
are already wired. The backend job snapshot now feeds the shared app store.
Retry/cancel/reschedule/restore mutations use the real API in live mode with
optimistic rollback on failure.

The upload flow now enters the server-backed TikTok Composer in live mode after
persisting the uploaded content and resolving the active TikTok connection.

The notifications screen now reads from `/v1/notifications` in live mode,
supports server-backed read-all, and routes notification payloads to the related
content or connection screen. Demo mode keeps the local fixture for UI work.

The Home bell now shows the unread notification count in live mode and refreshes
notifications on pull-to-refresh plus a low-frequency background poll.

Scheduled and cancelled jobs now use real `reschedule` and `restore` endpoints;
the mobile UI keeps optimistic updates with rollback when the server rejects a
mutation.

Push notification plumbing is now in place: the backend can send through FCM
HTTP v1 when service-account settings are supplied, while mobile builds request
permission, register and refresh FCM tokens through `/v1/devices` when Firebase
is configured. Missing Firebase settings remain a safe no-op.

## แผนดำเนินงานถัดไปจาก 62% ไป Internal Beta

ลำดับนี้ให้ความสำคัญกับเส้นทางหลักที่ผู้ใช้ต้องทำได้จริงก่อนเพิ่มฟีเจอร์ใหม่:

```text
ข้อมูลจริงเป็นแหล่งเดียว
  → อัปโหลดและสร้างงานโพสต์แบบไม่ซ้ำ
  → เชื่อม TikTok sandbox บนอุปกรณ์จริง
  → เพิ่มความทนทานและการติดตามปัญหา
  → ทดสอบ Internal Beta
```

### ช่วง A — ปิด Milestone 1 ให้ครบ (62% → 66%)

1. รวม Home, Content, Product detail และ Notifications ให้ผ่าน repository/API
   contract ชุดเดียวใน live mode
2. เติม loading, empty, offline, stale-data และ retry state ในจุดที่ยังขาด
3. เพิ่ม integration tests สำหรับ ownership และ state transition ของ publish job
4. ยืนยันว่า release/live build ไม่โหลดข้อมูล demo ทุกเส้นทาง

เกณฑ์จบ: ปิดและเปิดแอปใหม่แล้วข้อมูลทุกหน้าตรงกับ Backend และผู้ใช้หนึ่งคนอ่าน
หรือแก้ข้อมูลงานของอีกคนไม่ได้

### ช่วง B — Publish Flow ตลอดสาย (66% → 72%)

1. ทำ upload URL → upload media → complete media → create content → create job
   ให้เป็น flow เดียวที่ resume/retry ได้
2. ผูก `Idempotency-Key` กับ publish intent เพื่อกันกดซ้ำและ timeout แล้วเกิดสองโพสต์
3. ให้หน้า success แสดง job ID และสถานะ accepted จาก Backend จริง
4. polling เฉพาะงานที่ยังไม่จบ และหยุดเมื่อออกจากหน้าหรือถึง terminal state
5. เพิ่ม test สำหรับเน็ตหลุด, timeout และการกด Publish ซ้ำ

เกณฑ์จบ: การกด Publish หนึ่ง intent สร้าง job เดียวเสมอ แม้ request แรกไม่ทราบผล

### ช่วง C — TikTok Sandbox จริง (72% → 78%)

1. ตั้ง TikTok developer app, redirect URI และ secret แยก dev/staging
2. ทดสอบ OAuth + PKCE + state บน Android เครื่องจริง
3. ดึง creator info และ capability ก่อนแสดง privacy/comment/duet/stitch options
4. ต่อ worker กับ Content Posting API และเก็บ provider publish ID
5. รองรับ token หมดอายุ, revoked access และ reconnect flow

เกณฑ์จบ: บัญชีทดสอบโพสต์วิดีโอ `SELF_ONLY` สำเร็จอย่างน้อย 3 รอบ และงานตั้งเวลา
ทำงานใกล้เวลาที่กำหนดโดยไม่สร้างโพสต์ซ้ำ

### ช่วง D — Reliability + Push จริง (78% → 85%)

1. แยก transient/permanent error และใช้ exponential backoff
2. ทดสอบ stale-job reaper ด้วยการหยุด worker ระหว่างประมวลผล
3. เพิ่ม request ID, user ID, job ID และ provider publish ID ใน structured logs
4. เพิ่ม metrics ขั้นต่ำ: queue age, success rate, retry count และ provider latency
5. ใส่ Firebase credentials และทดสอบ push success/failure บนมือถือจริง
6. ลบ FCM token ที่หมดอายุหรือถูกยกเลิกจากผลตอบกลับ provider

เกณฑ์จบ: ติดตามงานหนึ่งชิ้นจาก Mobile ถึง TikTok ได้ และ worker restart ไม่ทำให้
เกิดโพสต์ซ้ำหรือทำให้งานค้างถาวร

### ช่วง E — Android Internal Beta (85% → 90%)

1. แก้ native Android build/cache issue และทำ signed staging APK/AAB
2. ทดสอบ permissions, file picker, background upload, deep link และ push notification
3. ทดสอบ Wi-Fi สลับมือถือ, เน็ตช้า, ปิดจอ และ force close
4. ตรวจ secure storage, token rotation, logout และ account deletion
5. ทำ acceptance flow 10 รอบบนเครื่องจริง และทดลองกับผู้ใช้ใหม่อย่างน้อย 5 คน

เกณฑ์จบ: ไม่มี crash/blocker, ไม่มีโพสต์ซ้ำ และมีวิธีปิด publishing ชั่วคราวเมื่อ
provider มีปัญหา

### งานรอบถัดไปที่ควรเริ่มทันที

เริ่มที่ **ช่วง A ข้อ 1–3**: ตรวจ data path ทุกหน้า, ปิดช่องที่ยังอ่าน local store
โดยตรง และเพิ่ม integration tests ของ job lifecycle ก่อนขยับไป upload/idempotency
ในช่วง B

## เป้าหมาย

เปลี่ยนแอปจาก prototype ที่กดทดลองได้ ให้เป็น MVP ที่ผู้สร้างคอนเทนต์สามารถทำงานนี้ได้จริงตั้งแต่ต้นจนจบ:

```text
สมัคร/เข้าสู่ระบบ
  → เชื่อมบัญชี TikTok
  → อัปโหลดวิดีโอ
  → เลือกหรือผูกสินค้า
  → ตรวจความพร้อม
  → โพสต์ทันทีหรือตั้งเวลา
  → เห็นสถานะจริงและแก้ปัญหาได้
```

สถานะเริ่มต้นโดยประมาณ:

- UI และ local prototype: 95–100%
- ฟังก์ชันที่ต่อระบบจริง: 45–50%
- ความพร้อมสำหรับผู้ใช้จริง: 25–30%

เป้าหมายรอบนี้คือ **Production MVP 75–80%** ไม่รวม AI generation เต็มรูปแบบ, กล้อง/ตัดต่อระดับ production และ analytics เชิงรายได้

## ขอบเขต MVP

### ต้องมี (P0)

- Email/password auth และ session restore
- TikTok OAuth และการเลือกบัญชีผู้สร้าง
- อัปโหลดวิดีโอจริงพร้อม resume/retry ขั้นพื้นฐาน
- สร้าง Content record จริงใน Backend
- ผูกสินค้าจากข้อมูลที่ Backend ยืนยันได้
- Publish now / Schedule ผ่าน Publish API จริง
- สถานะ queued, processing, scheduled, published และ failed จาก Backend
- Retry, cancel และ reschedule โดยไม่สร้างโพสต์ซ้ำ
- ข้อผิดพลาดที่ผู้ใช้เข้าใจและมีทางแก้
- ทดสอบบน Android เครื่องจริงอย่างน้อยหนึ่งรุ่น

### ควรมีหลัง P0 (P1)

- Google Login
- Push notification เมื่อโพสต์สำเร็จหรือล้มเหลว
- Preferences, onboarding และ saved products เก็บบน Backend
- Thumbnail extraction และ trim ขั้นพื้นฐาน
- Account deletion, privacy และ support flow

### พักไว้ก่อน (P2)

- AI video generation เต็มรูปแบบ
- AI Content Inbox จากหลาย provider
- Guided camera และ clip stitching
- Revenue analytics และ recommendation ขั้นสูง
- Batch publishing หลายแพลตฟอร์ม
- Facebook, Instagram และ YouTube publishing

## Milestone 0 — ทำ Baseline ให้เชื่อถือได้

ระยะเวลา: 1–2 วัน

งาน:

1. แยก `demo/local data` ออกจาก `live data` ด้วย environment flag ที่เห็นชัด
2. ห้าม production build โหลด seed jobs หรือ mock products โดยไม่ตั้งใจ
3. ทำคำสั่งรัน local แบบพอร์ตคงที่ พร้อม CORS ที่ตรงกัน
4. เพิ่ม smoke test: register → login → restore → logout กับ Backend จริง
5. บันทึก API contract และ error code ที่ Mobile ต้องรองรับ

Definition of Done:

- นักพัฒนาคนใหม่เปิดระบบ local ได้จากคำสั่งเดียว
- ทราบทันทีว่าหน้าใดใช้ mock และหน้าใดใช้ API จริง
- Test account และข้อมูลทดสอบสร้างซ้ำได้โดยไม่แก้ฐานข้อมูลมือ

ผลความพร้อมเป้าหมาย: **45% → 50%**

## Milestone 1 — Backend เป็นแหล่งข้อมูลหลัก

ระยะเวลา: 3–5 วัน

งาน Mobile:

1. สร้าง `ContentRepository` เป็น interface กลางสำหรับ contents และ publish jobs
2. ทำ `ApiContentRepository` สำหรับ production และ `MemoryContentRepository` สำหรับ widget tests
3. เปลี่ยน Home, Content, Notifications และ Product detail ให้อ่าน repository เดียวกัน
4. ย้าย approve, retry, cancel, restore และ reschedule จากการแก้ list ในหน่วยความจำไปเรียก API
5. รองรับ loading, empty, offline, stale data และ retry

งาน Backend:

1. ตรวจ pagination/filter ของ `/v1/contents` และ `/v1/publish-jobs`
2. เพิ่ม endpoint ที่ยังขาดสำหรับ reschedule/restore หรือกำหนด state transition ให้ชัด
3. ป้องกันผู้ใช้เข้าถึง content/job ของบัญชีอื่นทุก query
4. เพิ่ม integration tests สำหรับ lifecycle ของงาน

Definition of Done:

- ปิดและเปิดแอปใหม่แล้วงานยังอยู่
- Home และ Content แสดงสถานะเดียวกันจาก Backend
- การเปลี่ยนสถานะผิดกติกาถูกปฏิเสธทั้งฝั่ง Mobile และ Backend
- Seed data ไม่ถูกใช้ใน live mode

ผลความพร้อมเป้าหมาย: **50% → 60%**

## Milestone 2 — ต่อ Publish Flow ตลอดสาย

ระยะเวลา: 4–6 วัน

งาน:

1. ให้ทุก creation path ส่ง `assetId`, `contentId`, source และ product context แบบเดียวกัน
2. เปลี่ยนหน้า Publish Review ที่จำลอง delay แล้วเพิ่ม local job ให้เรียก API จริง
3. ลำดับ transaction ฝั่งแอป:

   ```text
   ขอ upload URL
     → PUT video
     → complete media
     → create/update content
     → fetch creator info
     → create publish job พร้อม Idempotency-Key
   ```

4. สร้าง Idempotency-Key หนึ่งครั้งต่อ intent และเก็บไว้จนได้ผลลัพธ์แน่นอน
5. รองรับ timeout แบบไม่สรุปทันทีว่าโพสต์ล้มเหลว ให้ query job เดิมก่อน retry
6. นำสถานะ accepted จาก Backend มาแสดงแทน success จำลอง
7. ทำ polling เฉพาะ job ที่ยังไม่จบ พร้อมหยุดเมื่อออกจากหน้า

Definition of Done:

- กด Publish หนึ่งครั้งแล้ว Backend มี job เดียว แม้ network timeout หรือกดซ้ำ
- Schedule ใช้ timezone ของผู้ใช้และเก็บ UTC ถูกต้อง
- หน้า success แสดง job ID และสถานะจาก Backend
- Error ทุกแบบมี Retry หรือทางกลับไปแก้ข้อมูล

ผลความพร้อมเป้าหมาย: **60% → 70%**

## Milestone 3 — TikTok จริง

ระยะเวลาพัฒนา: 5–10 วัน

ข้อขึ้นกับภายนอก: TikTok Developer approval อาจใช้เวลานอกเหนือจากระยะพัฒนา

งาน:

1. สร้าง TikTok developer app และกำหนด redirect URI แยก dev/staging/production
2. ตั้ง Client Key/Secret ใน secret manager ห้ามใส่ใน Mobile หรือ commit ลง Git
3. ทดสอบ OAuth + PKCE + state แบบครบเส้นทางบน Android จริง
4. ดึง creator info ใหม่ทุกครั้งก่อนแสดง privacy/options ที่ TikTok อนุญาต
5. ตรวจ video duration, privacy, duet, stitch, comment และ branded-content flags
6. เชื่อม Worker กับ Content Posting API จริง
7. เก็บ provider publish ID และ query สถานะหลัง handoff
8. รองรับ token expiry, revoked access และ reconnect flow
9. เตรียม video และเอกสารสำหรับ TikTok audit/review

Definition of Done:

- บัญชี TikTok test เชื่อมและยกเลิกการเชื่อมได้
- โพสต์ SELF_ONLY สำเร็จจากวิดีโอจริงอย่างน้อย 3 รอบ
- ตั้งเวลาแล้ว Worker ส่งงานใกล้เวลาที่กำหนดภายใน tolerance ที่ตกลง
- Token หมดอายุหรือถูกถอนแล้วแอปไม่ทำงานเงียบ ๆ และพา reconnect ได้
- ไม่มี Client Secret หรือ provider token หลุดใน log/response

ผลความพร้อมเป้าหมาย: **70% → 78%**

## Milestone 4 — Reliability และ Observability

ระยะเวลา: 3–5 วัน

งาน:

1. กำหนด publish state machine และ transition ที่อนุญาตเพียงชุดเดียว
2. ตั้ง retry policy แยก transient/permanent error พร้อม exponential backoff
3. เปิด stale-job reaper และพิสูจน์ว่า worker ตายกลางงานแล้วกู้คืนได้
4. เพิ่ม structured log ด้วย request ID, user ID, job ID และ provider publish ID
5. เพิ่ม metrics: queue age, success rate, retry count และ provider latency
6. ทำ notification record ทุก terminal state แม้ FCM ยังส่งไม่ได้
7. เพิ่มหน้าอธิบาย failure reason และ action ที่เหมาะกับ error code

Definition of Done:

- ทดสอบ restart Worker กลางงานแล้วไม่มีโพสต์ซ้ำ
- มองจาก job ID เดียวแล้วตามเหตุการณ์ได้ตั้งแต่ Mobile ถึง Provider
- ผู้ใช้แก้ auth error, invalid video และ provider rejection ได้ถูกทาง

ผลความพร้อมเป้าหมาย: **78% → 85%**

## Milestone 5 — Device Beta

ระยะเวลา: 4–7 วัน

งาน:

1. ทดสอบ Android เครื่องจริง: permissions, file picker, upload background/foreground และ deep link
2. ทดสอบ network ช้า, สลับ Wi‑Fi/มือถือ, ปิดจอ และ force close
3. ตรวจ secure storage, token rotation และ logout ทุกอุปกรณ์
4. ทำ performance pass: startup, list scrolling, image memory และ upload progress
5. เพิ่ม privacy policy, terms, account deletion และข้อมูล support
6. ทำ signed staging build และแจกผ่าน internal testing
7. รัน acceptance flow กับผู้ใช้ทดลองอย่างน้อย 5 คน

Definition of Done:

- P0 flow สำเร็จบนเครื่องจริงอย่างน้อย 10 รอบโดยไม่มีโพสต์ซ้ำ
- ไม่มี crash/blocker ใน beta session
- ผู้ทดสอบใหม่ทำ flow ได้โดยไม่ต้องให้นักพัฒนาบอกทีละขั้น
- มี rollback/disable publishing switch เมื่อ provider มีปัญหา

ผลความพร้อมเป้าหมาย: **85% → 90% beta-ready**

## ลำดับ Pull Request ที่แนะนำ

1. `chore(dev): separate demo and live modes`
2. `feat(content): add repository abstraction`
3. `feat(content): hydrate home and library from api`
4. `feat(content): persist lifecycle actions`
5. `feat(publish): unify creation handoff model`
6. `feat(publish): submit review to backend`
7. `feat(publish): add idempotent status recovery`
8. `feat(tiktok): complete oauth and reconnect flow`
9. `feat(tiktok): publish through worker`
10. `feat(observability): trace publish lifecycle`
11. `test(e2e): cover upload schedule publish`
12. `chore(beta): add staging build and legal flows`

แต่ละ PR ต้องเล็กพอ review ได้, มี test ของพฤติกรรมใหม่ และไม่รวม redesign UI ที่ไม่เกี่ยวข้อง

## Test Gate ทุก Milestone

- `flutter analyze`
- Flutter unit/widget tests
- `go test ./...`
- `go vet ./...`
- PostgreSQL integration tests ใน schema แยก
- API smoke test กับ Docker Compose
- ห้าม merge หาก happy path ผ่านแต่ retry/idempotency path ยังไม่มี test

ก่อนขึ้น Beta เพิ่ม:

- Android physical-device acceptance test
- Network interruption test
- Worker restart/recovery test
- Duplicate publish test
- Auth token expiry/reconnect test

## ความเสี่ยงหลัก

| ความเสี่ยง | ผลกระทบ | วิธีลดความเสี่ยง |
|---|---|---|
| TikTok app review ใช้เวลานาน | ส่งจริงไม่ได้ตามกำหนด | เริ่ม registration/audit ตั้งแต่ Milestone 1 และใช้ SELF_ONLY sandbox ก่อน |
| UI local กับ Backend state แยกกัน | ผู้ใช้เห็นข้อมูลไม่ตรง | บังคับ repository เดียวตั้งแต่ Milestone 1 |
| Timeout แล้วสร้างโพสต์ซ้ำ | ความเสียหายสูง | Idempotency-Key + query-before-retry + integration test |
| วิดีโอใหญ่หรือเน็ตหลุด | Upload ล้มบ่อย | progress, retry/resume และเก็บ asset state |
| Token provider หมดอายุ | งานตั้งเวลาล้มเหลว | preflight check, reconnect notification และ failure reason |
| Scope โตจาก AI/หลายแพลตฟอร์ม | MVP ไม่เสร็จ | พัก P2 จน TikTok end-to-end ผ่านจริง |

## แผนเวลาโดยรวม

หากมีนักพัฒนา 1 คนเต็มเวลา:

- สัปดาห์ 1: Milestone 0–1
- สัปดาห์ 2: Milestone 2
- สัปดาห์ 3–4: Milestone 3 และเริ่ม TikTok review
- สัปดาห์ 4: Milestone 4
- สัปดาห์ 5: Milestone 5 / Internal beta

ประมาณการรวม **4–5 สัปดาห์สำหรับ internal beta** โดยไม่รวมเวลารออนุมัติจาก TikTok และไม่รวม P2

## งานถัดไปทันที

เริ่มจาก Milestone 0 และ PR แรก:

1. เพิ่ม `APP_DATA_MODE=demo|live`
2. ทำให้ production/release ยอมรับเฉพาะ `live`
3. ย้าย seed data ไปอยู่ใน demo repository เท่านั้น
4. เพิ่ม local bootstrap command ที่เปิด Docker และ Flutter web ด้วย port/CORS คงที่
5. เพิ่ม live auth smoke test ใน CI/local script

หลังงานชุดนี้จบจึงเริ่ม `ContentRepository` โดยไม่ต้องรื้อ UI รอบสอง
