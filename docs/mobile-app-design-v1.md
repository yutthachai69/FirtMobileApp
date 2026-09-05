# Mobile App Design V1 — Flutter

> คู่กับ [system-design-v1.md](system-design-v1.md)
> **วันที่:** 2026-09-05

---

## 1. หลักคิดของแอปนี้

> **"คุณคิดและกำหนดเวลา ที่เหลือระบบจัดการให้"**

แอปนี้ **ไม่ใช่เครื่องมือสร้างคอนเทนต์** แต่เป็น **ห้องควบคุม** ผลลัพธ์คือ:

| หลัก | แปลว่า |
|---|---|
| **Status-first ไม่ใช่ feed-first** | หน้าแรกตอบว่า "ตอนนี้มีอะไรต้องทำ" ไม่ใช่โชว์คอนเทนต์สวย ๆ |
| **ผู้ใช้แตะน้อยที่สุด** | เส้นทางสร้างงานต้องจบใน ≤ 5 หน้าจอ |
| **ปิดแอปได้ตลอดเวลา** | ไม่มีขั้นตอนไหนที่ต้องเปิดแอปค้างรอ |
| **บอกเสมอว่าตอนนี้อยู่ตรงไหน** | งาน AI ใช้เวลาหลายนาที ถ้าเงียบ = ผู้ใช้คิดว่าพัง |
| **ผิดพลาดต้องบอกว่าทำอะไรต่อ** | ไม่ใช่ "Error 500" แต่เป็น "เชื่อม TikTok ใหม่" + ปุ่มกด |

---

## 2. Navigation Map

```
AuthGate
 ├─ (ยังไม่ล็อกอิน) ──▶ Login ⇄ Register
 └─ (ล็อกอินแล้ว)  ──▶ MainShell (Bottom Nav 4 แท็บ)
                          │
      ┌───────────────────┼───────────────────┬──────────────┐
      ▼                   ▼                   ▼              ▼
   หน้าหลัก            คอนเทนต์            เชื่อมต่อ          ฉัน
   (Home)            (Contents)        (Connections)    (Profile)
      │                   │                   │
      │                   └─▶ ContentDetail   └─▶ ConnectOAuth (in-app browser)
      │                                           └─▶ deep link กลับ
      │
      └─▶ Create ─▶ Upload ─▶ TikTokComposer ─▶ Preview ─▶ Schedule/PostNow ─▶ ✅

   [ FAB ] ──▶ Create (เลือกวิดีโอ)  ← ทางลัดหลัก อยู่ทุกแท็บ
```

**เลือก `go_router`** เพราะต้องรับ deep link จาก OAuth callback (`app://oauth/tiktok?code=...`) ซึ่ง Navigator 1.0 จัดการยาก

---

## 3. Screen Inventory

| # | หน้าจอ | V0.1 | หน้าที่ |
|---|---|---|---|
| 1 | AuthGate / Splash | ✅ | เช็ค token → ตัดสินเส้นทาง |
| 2 | Login / Register | ✅ | |
| 3 | **Connections** | ✅ | เชื่อม TikTok — **ทำก่อนเพราะต้องใช้อัดวิดีโอ audit** |
| 4 | **TikTokComposer** | ✅ | ⚠️ ตัวตัดสิน audit |
| 5 | **Create / Upload** | ✅ | เลือกวิดีโอ → อัป (progress) |
| 6 | Preview | ✅ | ดูก่อนยืนยัน |
| 7 | SchedulePicker | ✅ | ตั้งเวลา หรือ "โพสต์เลย" |
| 8 | **Home** | ✅ | ศูนย์กลางสถานะงาน |
| 9 | Contents / History | ✅ | รายการ + filter + permalink |
| 10 | Profile | ✅ | timezone, ออกจากระบบ |
| 11 | RunDetail | ⬜ | V0.2 (มาพร้อม Workflow Engine) |
| 12 | Approve | ⬜ | V0.2 |
| 13 | WorkflowList | ⬜ | V0.3 |

> **ลำดับในตารางนี้คือลำดับที่ควรสร้างจริง** — ข้อ 3-4 มาก่อน Home เพราะเป็นสิ่งที่ต้องใช้อัดวิดีโอสาธิตยื่น TikTok audit

---

## 4. หน้าหลัก (Home) — หัวใจของ Control Center

```
┌──────────────────────────────────┐
│  สวัสดี ยุทธชัย          [🔔 2]   │
├──────────────────────────────────┤
│  ⚠️ ต้องทำ (2)                    │  ← ขึ้นบนสุดเสมอ
│  ┌────────────────────────────┐  │
│  │ ❌ โพสต์ไม่สำเร็จ            │  │
│  │ "คลิปขายเสื้อ Oversize"     │  │
│  │ วิดีโอยาวเกินกำหนด           │  │
│  │              [ ดูสาเหตุ ]    │  │
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │ ❌ TikTok หลุดการเชื่อมต่อ   │  │
│  │              [ เชื่อมใหม่ ]  │  │
│  └────────────────────────────┘  │
├──────────────────────────────────┤
│  ⏳ กำลังทำงาน (1)                │
│  ● กำลังโพสต์ขึ้น TikTok... 0:42  │  ← polling 5 วิ
├──────────────────────────────────┤
│  📅 ตั้งเวลาไว้ (3)               │
│  วันนี้ 19:00  TikTok  เสื้อยืด    │
│  พรุ่งนี้ 12:00 TikTok  กางเกง     │
├──────────────────────────────────┤
│  ✅ โพสต์แล้ววันนี้ (2)            │
└──────────────────────────────────┘
              ( + )  ← FAB
```

**กฎการเรียงลำดับ:** เรียงตาม *ความเร่งด่วนของสิ่งที่ผู้ใช้ต้องทำ* ไม่ใช่ตามเวลา

```
1. ต้องทำ       (failed, needs_reauth)          [V0.2 เพิ่ม waiting_approval]
2. กำลังทำงาน   (uploading, queued, processing)
3. ตั้งเวลาไว้   (scheduled)
4. เสร็จแล้ว    (published วันนี้)
```

ถ้ากลุ่มไหนว่าง → **ซ่อนทั้งกลุ่ม** ไม่ต้องโชว์ empty state ย่อย

**Empty state ทั้งหน้า** (ผู้ใช้ใหม่):
```
      🌱
  ยังไม่มีคอนเทนต์เลย
  เริ่มจากเลือกวิดีโอแรกของคุณ
      [ + สร้างคอนเทนต์ ]
```

---

## 5. ⚠️ TikTokComposer — Widget Spec เต็ม

หน้านี้ผิดข้อเดียว = audit ตก ผมแยกเป็น state model + validation rule ให้เขียนตรง ๆ ได้เลย

### 5.1 State model

```dart
class TikTokComposerState {
  // ── จาก creator_info/query (โหลดใหม่ทุกครั้งที่เปิดหน้า) ──
  final CreatorInfo? creatorInfo;   // avatar, username, options, limits
  final bool isLoadingCreatorInfo;

  // ── ค่าที่ผู้ใช้เลือก ──
  final String caption;                    // ≤ 2200 UTF-16 runes
  final PrivacyLevel? privacyLevel;        // ⚠️ null = ยังไม่เลือก ห้ามมี default
  final bool allowComment;                 // ⚠️ เริ่มที่ false
  final bool allowDuet;                    // ⚠️ เริ่มที่ false
  final bool allowStitch;                  // ⚠️ เริ่มที่ false
  final bool discloseContent;              // เริ่มที่ false
  final bool brandOrganic;                 // "Your brand"
  final bool brandedContent;               // "Branded content"
  final bool isAigc;                       // true เมื่อวิดีโอมาจาก AI
  final DateTime? scheduledAt;
}
```

### 5.2 Validation — `canPost` ต้องเป็น true ทุกข้อ

```dart
bool get canPost {
  if (creatorInfo == null) return false;
  if (privacyLevel == null) return false;              // R2
  if (caption.runes.length > 2200) return false;
  if (videoDurationSec > creatorInfo!.maxVideoPostDurationSec) return false; // R7
  if (discloseContent && !brandOrganic && !brandedContent) return false;     // R4
  if (brandedContent && privacyLevel == PrivacyLevel.selfOnly) return false; // R5
  return true;
}

String? get postBlockedReason {
  if (privacyLevel == null)
    return 'กรุณาเลือกว่าใครดูวิดีโอนี้ได้';
  if (discloseContent && !brandOrganic && !brandedContent)
    return 'You need to indicate if your content promotes yourself, '
           'a third party, or both.';                  // ⚠️ ข้อความตามสเปก TikTok
  if (brandedContent && privacyLevel == PrivacyLevel.selfOnly)
    return 'Branded content ไม่สามารถตั้งเป็น "เฉพาะฉัน" ได้';
  return null;
}
```

### 5.3 Widget checklist — 8 ข้อบังคับ

| # | กฎ | Widget ที่ต้องทำ |
|---|---|---|
| **R1** | แสดง avatar + username ของ creator | `CircleAvatar` + `Text` จาก `creatorInfo` **สด** ห้ามใช้ค่า cache เก่า |
| **R2** | Privacy **ห้ามมี default** | `DropdownButton<PrivacyLevel?>` ค่าเริ่มต้น `null`, hint = "เลือก" — options จาก `creatorInfo.privacyLevelOptions` เท่านั้น |
| **R3** | Comment/Duet/Stitch **ห้าม pre-check** | `Switch(value: false)` ทั้ง 3 ตัว และ `onChanged: null` (disable) ถ้า `creatorInfo.commentDisabled == true` |
| **R4** | เปิด disclose แต่ไม่เลือกอะไร → ปุ่ม disabled | ปุ่ม disabled + แสดง `postBlockedReason` ใต้ปุ่ม |
| **R5** | Branded content + SELF_ONLY = ห้าม | disable checkbox Branded เมื่อเลือก "เฉพาะฉัน" |
| **R6** | ข้อความยินยอม **เหนือปุ่ม Post** | `RichText` มีลิงก์ Music Usage Confirmation (+ Branded Content Policy เมื่อเปิด branded) |
| **R7** | เช็คความยาววิดีโอ | เทียบกับ `creatorInfo.maxVideoPostDurationSec` ก่อนเปิดใช้ปุ่ม |
| **R8** | `is_aigc = true` เมื่อวิดีโอมาจาก AI | ตั้งอัตโนมัติจาก `mediaAsset.source == 'ai'` ผู้ใช้ปิดไม่ได้ |

### 5.4 Lifecycle

```dart
@override
void initState() {
  super.initState();
  // ⚠️ ต้อง fetch ใหม่ทุกครั้ง — audit ตรวจว่าค่าที่แสดงตรงกับบัญชีจริง
  ref.read(creatorInfoProvider.notifier).fetch(connectionId);
}
```
`creator_info` cache ได้ไม่เกิน **5 นาที** ถ้าเก่ากว่านั้นต้องยิงใหม่

---

## 6. State Management — Riverpod

**เลือก `flutter_riverpod`** ไม่ใช่ Bloc เพราะ:
- แอปนี้เป็น **async-heavy** (polling, refresh token, cache) → `AsyncValue` จัดการ loading/error/data ให้ครบในตัว
- `ref.invalidate()` ทำให้ refresh หลังอนุมัติ/โพสต์ ง่ายกว่า event ของ Bloc มาก
- boilerplate น้อยกว่าครึ่ง สำหรับทีมเล็ก

```dart
// ── auth ──
final authProvider = NotifierProvider<AuthNotifier, AuthState>(...);

// ── home: รวม 4 กลุ่มในคำขอเดียว ──
final homeProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  return ref.watch(apiProvider).getHome();
});

// ── run: polling เฉพาะตอน foreground และยังไม่จบ ──
final runProvider = StreamProvider.autoDispose.family<Run, String>((ref, id) async* {
  final api = ref.watch(apiProvider);
  while (true) {
    final run = await api.getRun(id);
    yield run;
    if (run.isTerminal) break;          // จบแล้วหยุด poll
    await Future.delayed(const Duration(seconds: 5));
  }
});

final connectionsProvider = FutureProvider<List<Connection>>(...);
final creatorInfoProvider  = AsyncNotifierProvider.family<...>(...);
```

> **`autoDispose` สำคัญมาก** — ออกจากหน้าแล้ว polling ต้องหยุดเอง ไม่งั้นแบตหมดและยิง API ทิ้ง

---

## 7. โครงโฟลเดอร์ (feature-first)

```
lib/
├── main.dart
│
├── app/
│   ├── app.dart              root widget + ProviderScope
│   ├── router.dart           go_router + deep link OAuth
│   └── theme/
│       ├── tokens.dart       ⚠️ design token (ดูข้อ 12)
│       ├── app_theme.dart    ThemeData light + dark จาก token
│       └── typography.dart   Noto Sans Thai
│
├── core/
│   ├── network/
│   │   ├── api_client.dart   dio + base url
│   │   ├── interceptors/
│   │   │   ├── auth_interceptor.dart    JWT + single-flight refresh
│   │   │   ├── retry_interceptor.dart   backoff 5xx/network
│   │   │   └── error_interceptor.dart   error code → ข้อความไทย
│   │   └── endpoints.dart
│   ├── auth/                 session state, token lifecycle
│   ├── storage/              flutter_secure_storage
│   ├── upload/               ⚠️ abstraction (ดูข้อ 9)
│   │   ├── uploader.dart     interface
│   │   └── background_uploader.dart
│   ├── error/                AppException + mapper
│   └── config/               env, flavor, feature flag
│
├── features/
│   ├── auth/          { data/ domain/ presentation/ }
│   ├── connections/
│   ├── composer/      ⚠️ tiktok composer
│   ├── content/
│   ├── schedule/
│   ├── approval/
│   └── profile/
│
└── shared/
    ├── widgets/       StatusChip, EmptyState, ErrorView, LoadingShimmer
    ├── models/
    └── utils/
```

**ยังไม่สร้าง `features/workflow/` ใน V0.1** — บังคับ scope ตัวเองไม่ให้บาน

แต่ละ feature แยก `data / domain / presentation` — เพิ่มแพลตฟอร์มใหม่ไม่ต้องแตะของเดิม

---

## 8. Package ที่ใช้

| งาน | Package | หมายเหตุ |
|---|---|---|
| State | `flutter_riverpod` | |
| HTTP | `dio` | interceptor ครบ |
| Router | `go_router` | รองรับ deep link |
| Token storage | `flutter_secure_storage` | **ห้ามใช้ SharedPreferences กับ token** |
| Push | `firebase_messaging` | |
| **อัปวิดีโอ** | `background_downloader` | ⚠️ ดูข้อ 9 |
| เลือกไฟล์ | `file_picker` | |
| Preview | `video_player` + `chewie` | |
| Model | `freezed` + `json_serializable` | |
| วันเวลาไทย | `intl` | `th_TH` |
| OAuth | `flutter_web_auth_2` | เปิด in-app browser แล้วรับ callback |

---

## 9. ⚠️ จุดที่ยากที่สุดของฝั่ง Mobile: อัปวิดีโอ

วิดีโอ 50–200MB จากมือถือ มีปัญหาจริง 3 ข้อ:

| ปัญหา | ทางแก้ |
|---|---|
| ผู้ใช้สลับแอประหว่างอัป → iOS ฆ่า process | ใช้ **background upload** (`background_downloader` → URLSession background บน iOS) ไม่ใช่ `dio` ธรรมดา |
| เน็ตหลุดกลางทาง → เริ่มใหม่หมด | presigned **multipart upload** ของ R2 อัปเป็นชิ้น ๆ resume ได้ |
| ผู้ใช้ไม่รู้ว่าอัปถึงไหน | progress bar จริง + แจ้งว่าปิดแอปได้ |

**V0.1 ลดความซับซ้อน:** จำกัดวิดีโอ ≤ **100MB** และใช้ presigned PUT ก้อนเดียว + background upload
พอ Veo เข้ามา (วิดีโอสร้างบน server ไม่ต้องอัปจากมือถือ) ปัญหานี้จะเบาลงเองมาก

---

## 10. Auth & Deep Link

### Token flow
```
Login ──▶ access(15m) + refresh(30d) ──▶ flutter_secure_storage
                    │
        401 ──▶ interceptor refresh อัตโนมัติ ──▶ ยิงคำขอเดิมซ้ำ
                    │
        refresh ล้มเหลว ──▶ ล้าง storage ──▶ เด้งไป Login
```
> **ต้องกัน refresh ซ้อน** — ถ้ามี 3 request 401 พร้อมกัน ต้อง refresh ครั้งเดียวแล้วให้ที่เหลือรอ (single-flight lock) ไม่งั้น refresh token จะถูก rotate ทิ้งกัน

### OAuth TikTok
```
กด "เชื่อม TikTok"
   → GET /connections/tiktok/oauth/start → authorize_url
   → flutter_web_auth_2 เปิด in-app browser
   → ผู้ใช้อนุญาตบน tiktok.com
   → redirect: https://api.<domain>/v1/oauth/tiktok/callback
   → server แลก token, เก็บแบบเข้ารหัส, redirect ต่อไป app://oauth/success
   → go_router รับ → ref.invalidate(connectionsProvider)
```
**`state` parameter ต้อง verify ทุกครั้ง** (กัน CSRF)

---

## 11. Push Notification → หน้าจอ

| ประเภท | ข้อความ | แตะแล้วไป |
|---|---|---|
| `content_ready` | "คอนเทนต์พร้อมให้ตรวจแล้ว" | Approve |
| `publish_success` | "โพสต์ TikTok สำเร็จ ✅" | ContentDetail |
| `publish_failed` | "โพสต์ไม่สำเร็จ — แตะดูสาเหตุ" | ContentDetail |
| `needs_reauth` | "TikTok หลุดการเชื่อมต่อ" | Connections |
| `run_failed` | "สร้างคอนเทนต์ไม่สำเร็จ" | RunDetail |

payload ต้องมี `{type, target_id}` เพื่อ route ได้ถูกหน้า

---

## 12. Design System

### 12.1 ⚠️ Design Token — วางตั้งแต่ commit แรก

**กฎเหล็ก: ห้ามเขียน `Colors.white` / `Colors.black` / `Colors.grey` ที่ไหนก็ตามใน `features/`**
ถ้าปล่อยให้ hard-code กระจาย พอจะทำ dark mode ทีหลังต้องไล่แก้ทั้งโปรเจกต์

```dart
// app/theme/tokens.dart
class AppTokens {
  final Color surface;           // พื้นหลังหน้าจอ
  final Color surfaceContainer;  // การ์ด, sheet, ช่องกรอก
  final Color primary;           // ปุ่มหลัก, ลิงก์
  final Color onPrimary;         // ตัวอักษรบน primary
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color warning;
  final Color error;
}
```

| Token | Light | Dark |
|---|---|---|
| `surface` | `#FFFFFF` | `#0F1115` |
| `surfaceContainer` | `#F5F6F8` | `#1A1D23` |
| `primary` | `#2563EB` | `#3B82F6` |
| `onPrimary` | `#FFFFFF` | `#0F1115` |
| `textPrimary` | `#111827` | `#F3F4F6` |
| `textSecondary` | `#6B7280` | `#9CA3AF` |
| `border` | `#E5E7EB` | `#2A2F3A` |
| `success` | `#16A34A` | `#22C55E` |
| `warning` | `#D97706` | `#F59E0B` |
| `error` | `#DC2626` | `#EF4444` |

> ค่าเหล่านี้เป็นจุดตั้งต้น ปรับได้ตอนทำจริง — สิ่งที่ห้ามเปลี่ยนคือ **โครงสร้าง token**

เข้าถึงผ่าน extension เดียว ไม่ต้อง import ตรง:
```dart
extension AppThemeX on BuildContext {
  AppTokens get t => Theme.of(this).extension<AppTokens>()!;
}
// ใช้งาน: color: context.t.textSecondary
```

### 12.2 สีสถานะ — ผูกกับ token ไม่ใช่ Colors.*

```
scheduled  → primary   📅
uploading  → warning   ⬆️
processing → warning   ⏳
published  → success   ✅
failed     → error     ❌
```

### 12.3 Spacing & Typography

```dart
// 4pt scale
xs 4 · sm 8 · md 16 · lg 24 · xl 32

// Noto Sans Thai — font default ของ Flutter ตัดคำไทยไม่สวย
fontFamily: 'NotoSansThai'
```

**Component ที่ต้องมีก่อน:**
`StatusChip` · `EmptyState` · `ErrorView(retry)` · `LoadingShimmer` · `UploadProgressTile` · `ConnectionCard`

---

## 13. Error Copy — ภาษาไทยที่บอกว่าต้องทำอะไรต่อ

| error code | ❌ อย่าเขียน | ✅ เขียนแบบนี้ |
|---|---|---|
| `CONNECTION_NEEDS_REAUTH` | "Unauthorized" | "TikTok หลุดการเชื่อมต่อ — แตะเพื่อเชื่อมใหม่" |
| `VIDEO_TOO_LONG` | "Validation error" | "วิดีโอยาวเกิน 10 นาที กรุณาตัดให้สั้นลง" |
| `DAILY_LIMIT_REACHED` | "429" | "วันนี้โพสต์ครบ 15 คลิปแล้ว ลองพรุ่งนี้" |
| `AI_PROVIDER_ERROR` | "500" | "AI ไม่ตอบสนอง กำลังลองใหม่อัตโนมัติ (2/4)" |
| network | "SocketException" | "เชื่อมต่อไม่ได้ ตรวจสอบอินเทอร์เน็ต" + ปุ่มลองใหม่ |

**ทุกข้อความ error ต้องมีปุ่มให้กดต่อ** ห้ามมีแค่ข้อความลอย ๆ

---

## 14. ลำดับสร้างฝั่ง Mobile

| # | ทำอะไร | ผลลัพธ์ที่จับต้องได้ |
|---|---|---|
| 1 | โครง + theme + router + api client + interceptor | แอปเปิดได้ ยิง `/health` ผ่าน |
| 2 | Auth (Login/Register) + secure storage | ล็อกอินค้างไว้ได้ ปิดแอปเปิดใหม่ยังอยู่ |
| 3 | **Connections + OAuth TikTok** | เห็น "@username เชื่อมแล้ว ✓" |
| 4 | **TikTokComposer** (สเปกข้อ 5) | ⚠️ อัดวิดีโอสาธิตยื่น audit ได้ |
| 5 | อัปวิดีโอ + preview | วิดีโอขึ้น R2 จริง |
| 6 | Create + RunDetail + polling | เห็น progress เดินทีละ node |
| 7 | Approve | อนุมัติแล้ว run เดินต่อ |
| 8 | Home + FCM | ปิดแอปแล้วได้ push |
| 9 | Contents + Profile | ครบ V0.1 |

> **ข้อ 3-4 มาก่อนเสมอ** เพราะต้องใช้อัดวิดีโอสาธิตยื่น TikTok audit ซึ่งเป็น critical path — ไม่ต้องรอให้ Workflow Engine เสร็จ

---

## 15. ✅ Decisions ที่ล็อกแล้ว

| เรื่อง | ตัดสิน | หมายเหตุ |
|---|---|---|
| Working name | **RelayContent** | เลี่ยงชนชื่อ FlowPost / PostFlow ที่มีเจ้าอื่นใช้ |
| Bundle ID | `com.relaycontent.app` | ใช้ตอนตั้ง Firebase + deep link scheme |
| Deep link scheme | `relaycontent://` | เช่น `relaycontent://oauth/success` |
| State | **Riverpod** | async-heavy: connection, upload, publish, polling, refresh |
| Font | **Noto Sans Thai** | neutral เหมาะกับแอป utility ให้ content เด่นกว่าบุคลิก font |
| Dark mode | **มีตั้งแต่ V0.1** ผ่าน design token | ไม่ได้ออกแบบสองชุด แค่วาง token แล้วให้ ThemeData จัดการ |
| Upload | abstraction ตั้งแต่แรก + ≤100MB ใน V0.1 | เปลี่ยน implementation ทีหลังได้โดยไม่แตะ UI |
| Refresh token | **single-flight = requirement** | ไม่ใช่ optimization |
| iOS | Android-first → Codemagic ตอนถึงขั้น iOS | ยังไม่มี Mac |
| `features/workflow/` | **ไม่สร้างใน V0.1** | บังคับ scope ตัวเองไม่ให้บาน |

### เรื่องที่ยังต้องเตรียม

- [ ] ติดตั้ง **Flutter SDK** (แยกต่างหากจาก Android Studio — Android Studio ให้แค่ Android SDK + emulator)
- [ ] สร้าง Firebase project ชื่อ `relaycontent` + ลง `google-services.json`
- [ ] ดาวน์โหลด Noto Sans Thai ใส่ `assets/fonts/` แล้วประกาศใน `pubspec.yaml`
- [ ] จด domain (ใช้ทั้ง OAuth redirect และ TikTok domain verification)
