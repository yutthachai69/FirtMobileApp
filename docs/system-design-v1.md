# System Design V1 — Content Automation Platform

> **สถานะ:** Blueprint สำหรับเริ่มเขียนโค้ด V0.1
> **วันที่:** 2026-09-05
> **ขอบเขต:** เส้นทางเดียวแบบครบวงจร — ผู้ใช้พิมพ์ไอเดีย → โพสต์ขึ้น TikTok สำเร็จ

---

## 0. Decisions ที่ล็อกแล้ว

| หัวข้อ | ตัดสิน | เหตุผล |
|---|---|---|
| Mobile | Flutter | code base เดียว ได้ทั้ง Android/iOS |
| Backend | Go + Gin | |
| DB | PostgreSQL | source of truth ทุกอย่างรวมถึงคิวงาน |
| Queue | Redis | **transport เท่านั้น ไม่ใช่ที่เก็บงาน** |
| Storage | Cloudflare R2 | ต้องรองรับ signed public URL |
| แพลตฟอร์มแรก | TikTok | |
| ต่อไป | FB Page + IG (Meta app เดียว) → YouTube | |
| Shopee | แยกเป็น `commerce` module ไม่ใช่ publisher | ไม่มี content posting API |
| AI text/image | **เราจ่าย** (managed key) | caption ตกชิ้นละ ~0.02 บาท |
| AI video | **BYOK หรือเครดิตแยก** | Veo 3.1 ตกคลิปละ 8–112 บาท |
| Billing V0.1 | **ไม่ทำ** ขายด้วยมือก่อน | พิสูจน์ว่ามีคนจ่ายก่อนสร้างระบบเก็บเงิน |
| Multi-tenant | ทำตั้งแต่แรก (`user_id` ทุกตาราง) | |
| Realtime | **FCM + polling** ไม่ทำ WebSocket ใน V0.1 | งานยาว 2–10 นาที WS ไม่คุ้ม |
| Workflow V0.1 | linear เท่านั้น 4 node type | ไม่มี branch ไม่มี DAG |
| TikTok upload | **PULL_FROM_URL** | โค้ดน้อยกว่า chunked มาก และต้องมี public URL ให้ Meta อยู่แล้ว |
| Working name | **RelayContent** | เลี่ยงชนชื่อ FlowPost / PostFlow ที่มีเจ้าอื่นใช้แล้ว |
| Bundle ID | `com.relaycontent.app` | |
| Mobile ห้ามถือ platform token | OAuth callback → **Backend** → เข้ารหัสฝั่ง server; มือถือถือแค่ session ของเรา | ปลอดภัยกว่า และเพิ่มแพลตฟอร์มใหม่ไม่ต้องแตะแอป |

### ⚠️ ขอบเขต V0.1 (ล็อกแล้ว — แคบกว่าที่ร่างไว้ตอนแรก)

**V0.1 ไม่มี AI และไม่มี Workflow Engine** เส้นทางคือ:

```
Login → Connections → Connect TikTok → Composer → Upload Video
      → Caption (พิมพ์เอง) → Preview → Schedule/Post Now → Publish → History
```

**ตัดออกจาก V0.1:** `workflows` · `workflow_versions` · `workflow_runs` · `workflow_node_runs`
· OpenAI connector · node `ai_text` / `approval` · queue `q:workflow`

**เหตุผล:** ส่วนที่มีความเสี่ยงและถูก gate คือ **publish pipeline** ไม่ใช่ AI
ต้องพิสูจน์ให้ได้ก่อนว่า *เชื่อมบัญชี → เตรียมคอนเทนต์ → โพสต์ขึ้นจริง* ทำงานได้
Workflow Engine จะฉลาดแค่ไหนก็ไร้ค่าถ้าปลายทางโพสต์ไม่ได้
นอกจากนี้ยังทำให้ **วิดีโอสาธิตยื่น audit สั้นและชัดขึ้นมาก**

ตารางที่ยังต้องมีใน V0.1: `users` · `devices` · `platform_connections` · `contents`
· `media_assets` · `publish_jobs` · `publish_attempts` · `notifications` · `idempotency_keys`
(`usage_records` สร้างไว้เลย แต่ยังไม่มีอะไรเขียนลงจนกว่าจะมี AI)

**เพิ่มหลังพิสูจน์เส้นนี้แล้ว:** AI Connector → Workflow Engine → Auto-generation → Multi-platform

---

## 0.1 🔀 Pivot V1 — TikTok Shop Affiliate Creator (2026-09-07, ตัดสินใจร่วมกันแล้ว)

**V0.1 (เส้นทางในเอกสารนี้) ยังสร้างเสร็จและใช้งานได้ปกติ — เส้นนี้ไม่ถูกทิ้ง**
แต่ทิศทางของโปรดักต์ตั้งแต่ตอนนี้เปลี่ยนจาก *"เครื่องมือตั้งเวลาโพสต์ TikTok ทั่วไป"*
เป็น **"แอปสำหรับ TikTok Shop Affiliate Creator ในไทย"** — ผูกสินค้าจาก Showcase
เข้ากับทุกคลิปที่โพสต์ ดูรายละเอียดโปรดักต์เต็มที่ `docs/product-ux-brief-v1.md`
และดีไซน์ 10 หน้าจอที่อนุมัติแล้วใน `stitch_relaycontent_mobile_ux_review3/`

### สิ่งที่ยังใช้ต่อจาก V0.1 ทั้งหมด (ไม่รื้อ)

- `users` · `devices` · `platform_connections` · `notifications` · `idempotency_keys`
- Auth service, token vault (AES-256-GCM), refresh rotation
- Media upload (presigned PUT ตรงขึ้น R2)
- TikTok OAuth + Content Posting API (`video.publish`) — ยังใช้โพสต์คลิปเหมือนเดิม
- Scheduler/worker (`FOR UPDATE SKIP LOCKED`, retry backoff, poller)
- Design token, Riverpod/ChangeNotifier pattern, go_router

### สิ่งที่เพิ่มใหม่ (ของานหลัก)

| ส่วน | เพิ่มอะไร |
|---|---|
| **TikTok Shop Partner Center** | สมัครแยกจาก TikTok for Developers app เดิม ต้องมีเอกสารธุรกิจ (ทะเบียนบริษัท/ID/บัญชีธนาคาร) — **critical path ใหม่ รอ approve** |
| **Affiliate Creator API** | scope ใหม่ (อ่าน Showcase, สร้าง promotion link, โพสต์ shoppable video) — ยังไม่ยืนยัน scope name ที่แน่นอนจนกว่าจะสมัคร Partner Center สำเร็จ |
| `products` (ตารางใหม่) | sync จาก Showcase: id, title, price, commission, stock, images, ราคาที่ sync ล่าสุด |
| `contents.product_id` | ผูกสินค้า 1 รายการต่อวิดีโอ 1 คลิป (ตาม brief ข้อ 3) |
| `publish_jobs` เพิ่ม `product_anchor` | ส่งไปพร้อม `product_link_info` ตอนโพสต์ shoppable video |
| AI generation module | Idea/Hook/Script/Voice/Scene — **ถูกเลื่อนไว้หลัง product/showcase เสร็จ** ไม่ใช่ของด่านแรก |
| Bottom nav 5 แท็บ | หน้าหลัก, สินค้า (Showcase), สร้าง, คอนเทนต์, โปรไฟล์ — แทนที่ IA เดิมของ V0.1 |

### สิ่งที่ยังไม่ยืนยัน (ต้องเช็คก่อนลุยหนัก)

1. **Affiliate Creator API scope ที่แท้จริง** — เอกสารสาธารณะไม่บอกชื่อ scope/endpoint ละเอียด ต้องดูจาก Partner Center จริงหลังสมัคร
2. เวลาอนุมัติ Partner Center เทียบกับ TikTok Developer app (ปกติ 2–4 สัปดาห์) — ยังไม่รู้
3. Rate limit ของการ sync product จาก Showcase

### ลำดับสร้างที่แก้ไข

```
1. สมัคร TikTok Shop Partner Center (ผู้ใช้ทำเอง — critical path)
2. ระหว่างรอ: backend เพิ่มตาราง products + product sync module (mock data ก่อนได้)
3. Flutter: ต่อ bottom nav ให้ครบ 5 แท็บ ด้วย UI ตาม stitch design (ข้อมูลจริงรอ API)
4. พอ Partner Center อนุมัติ → ต่อ product sync จริง → ทดสอบโพสต์ shoppable video จริง
5. AI generation module (Idea/Script/Voice) — เริ่มทีหลังสุด
```

---

## 1. UC-01 — Golden Path (เส้นเดียวที่ V0.1 ต้องทำได้)

**Actor:** เจ้าของร้านค้าออนไลน์
**Precondition:** ล็อกอินแล้ว, เชื่อม TikTok แล้ว

### Main flow

| # | ผู้ใช้ทำ | ระบบทำ |
|---|---|---|
| 1 | กด "สร้างคอนเทนต์" | สร้าง `content` สถานะ `draft` |
| 2 | เลือกวิดีโอจากเครื่อง | ขอ presigned URL → อัป **ตรงขึ้น R2** (background upload) |
| 3 | — | `media_asset` → `uploaded` |
| 4 | เปิดหน้า Composer | Backend เรียก `creator_info/query` → คืน avatar, ตัวเลือก privacy, ลิมิต |
| 5 | พิมพ์ caption + ตั้งค่า TikTok (ดูข้อ 3.1) | ตรวจ validation ฝั่งแอปแบบ real-time |
| 6 | ดู Preview | |
| 7 | เลือก "โพสต์เลย" หรือ "ตั้งเวลา" | สร้าง `publish_job` สถานะ `scheduled` + `idempotency_key` |
| 8 | **ปิดแอปได้** | Scheduler จับเวลา → enqueue → Worker โพสต์ |
| 9 | — | `init` (PULL_FROM_URL) → poll `status/fetch` จนได้ผล |
| 10 | ได้ push "โพสต์สำเร็จ ✅" | บันทึก `external_post_id` + `permalink` |

### Alternate flows

- **A1** เลือก "โพสต์เลย" → `scheduled_at = now()` เข้าเส้นทางเดียวกัน **ไม่มีโค้ดแยก**
- **A2** ผู้ใช้ยกเลิกก่อนถึงเวลาโพสต์ → `publish_job` → `cancelled`
- **A3** ผู้ใช้แก้ caption ก่อนถึงเวลาโพสต์ → อัปเดต `contents.caption` + `publish_jobs.platform_options`

### Exception flows

- **E1** อัปโหลดหลุดกลางทาง → `media_asset` ค้าง `pending`; แอปให้เลือกวิดีโอใหม่ได้
- **E2** TikTok token หมดอายุ → refresh อัตโนมัติ; ถ้า refresh ไม่ได้ → connection `needs_reauth` + push ให้เชื่อมใหม่ + **เลื่อน publish_job ไม่ใช่ fail**
- **E3** TikTok ตอบ processing `FAILED` → `publish_job` `failed` + เก็บ reason code + push
- **E4** วิดีโอเกินสเปก (ยาวเกิน `max_video_post_duration_sec`) → กันตั้งแต่หน้า Composer ไม่ปล่อยให้ไปตายที่ API
- **E5** เกิน 15 โพสต์/วัน/บัญชี → กันตั้งแต่ตอนสร้าง `publish_job`

---

## 2. Architecture

```
┌──────────────────────────────────────────┐
│           Flutter App (Control Center)   │
└───────┬──────────────────────────┬───────┘
        │ REST (JWT)               │ FCM push
        ▼                          ▲
┌────────────────────────────────────────────┐
│                Go API (Gin)                │
│  auth · user · connection · media          │
│  content · workflow · publish · webhook    │
└───┬────────────────────┬───────────────────┘
    │ อ่าน/เขียน          │ enqueue
    ▼                    ▼
┌─────────────┐    ┌───────────┐
│ PostgreSQL  │    │   Redis   │  ← transport เท่านั้น
│ (SoT ทุกอย่าง)│    └─────┬─────┘
└──────┬──────┘          │
       │ ticker poll     │ consume
       │                 ▼
       │        ┌──────────────────┐
       └───────▶│    Go Worker     │
                │  runner·publisher │
                │  scheduler·poller │
                └────┬────────┬─────┘
                     │        │
              ┌──────▼──┐  ┌──▼────────┐
              │ OpenAI  │  │  TikTok   │
              │ Veo 3.1 │  │  (later:  │
              └─────────┘  │  Meta/YT) │
                           └───────────┘
                     ▲
              ┌──────┴──────┐
              │ Cloudflare  │
              │     R2      │ ← signed public URL
              └─────────────┘
```

### โครงโฟลเดอร์

```
backend/
├── cmd/
│   ├── api/main.go
│   └── worker/main.go
├── internal/
│   ├── auth/          jwt, refresh token rotation
│   ├── user/
│   ├── connection/    oauth flow + token vault
│   ├── media/         presigned upload, signed public url
│   ├── content/
│   ├── workflow/      engine, node registry, runner
│   ├── scheduler/     ticker + due-job claim
│   ├── notification/  fcm
│   ├── webhook/
│   ├── usage/         usage_records (ยังไม่บังคับ quota)
│   ├── ai/
│   │   ├── provider.go        ← interface
│   │   ├── openai/
│   │   ├── google/            ← veo 3.1
│   │   └── manual/            ← ผู้ใช้อัปเอง (ตัวเลือกถาวร)
│   ├── publisher/
│   │   ├── publisher.go       ← interface
│   │   └── tiktok/
│   └── commerce/              ← Shopee ไว้ทีหลัง คนละ interface
├── pkg/
│   ├── crypto/        envelope encryption
│   ├── httpx/         retry, backoff, rate limit
│   └── logger/
├── migrations/
├── configs/
└── Dockerfile
```

---

## 3. หน้าจอ Flutter (V0.1)

```
Login
Connections   → TikTok (V0.2 ค่อยเพิ่ม OpenAI / Google / Meta)
Home          → กำลังอัป / ตั้งเวลาไว้ / โพสต์แล้ว / ล้มเหลว
Create        → เลือกวิดีโอ → อัป
TikTokComposer→ ⚠️ หน้าที่ audit ตรวจหนักที่สุด (caption + ตั้งค่า + ตั้งเวลา)
Preview       → ดูก่อนยืนยัน
History       → รายการ + สถานะ + permalink
```
> รายละเอียดเต็มอยู่ใน [mobile-app-design-v1.md](mobile-app-design-v1.md)

### 3.1 ⚠️ TikTok Composer — สเปกที่ต้องทำเป๊ะ ไม่งั้น audit ตก

หน้านี้ต้องเรียก `creator_info/query` **ก่อนแสดงผลทุกครั้ง** แล้ว render ตามค่าที่ได้กลับมา

```
┌────────────────────────────────────────┐
│  [avatar]  @username                   │ ← บังคับ ต้องดึงสดจาก creator_info
├────────────────────────────────────────┤
│  [ วิดีโอ preview ]                     │
│  Caption: ______________  (≤2200 runes)│
├────────────────────────────────────────┤
│  Who can view this video  ▼            │
│  ── เลือก ──                            │ ← ⚠️ ห้ามมีค่า default
│    Public / Friends / Followers / Only me│  ← เฉพาะที่ creator_info คืนมา
├────────────────────────────────────────┤
│  Allow users to:                       │ ← ⚠️ ห้าม pre-check ทั้งหมด
│   ☐ Comment   ☐ Duet   ☐ Stitch        │ ← disable ถ้า creator_info ปิดไว้
├────────────────────────────────────────┤
│  ☐ Disclose video content              │
│     ├ ☐ Your brand                     │
│     └ ☐ Branded content                │
├────────────────────────────────────────┤
│  By posting, you agree to TikTok's     │ ← บังคับ ต้องอยู่เหนือปุ่ม
│  Music Usage Confirmation              │
│         [ Post ]                       │
└────────────────────────────────────────┘
```

**กฎบังคับ (ทุกข้อคือเหตุผลที่แอปอื่นโดนตีกลับ):**

1. **แสดง avatar + username ของ creator** — ดึงสดจาก `creator_info/query` ไม่ใช่ cache
2. **Privacy dropdown ห้ามมี default** — ต้องขึ้นว่า "เลือก" และผู้ใช้กดเอง; ตัวเลือกต้องมาจาก `privacy_level_options` ที่ API คืนเท่านั้น
3. **Comment / Duet / Stitch ห้ามติ๊กไว้ล่วงหน้า** — และถ้า `comment_disabled` / `duet_disabled` / `stitch_disabled` เป็น true ต้อง **disable ช่องนั้น** ไม่ใช่แค่ไม่ติ๊ก
4. **ถ้าเปิด "Disclose video content" แต่ไม่เลือกอะไรเลย → ปุ่ม Post ต้อง disabled** พร้อมข้อความ *"You need to indicate if your content promotes yourself, a third party, or both."*
5. **Branded content ใช้กับ SELF_ONLY ไม่ได้** — ถ้าเลือก "Only me" ต้อง disable Branded content (หรือสลับ visibility ให้ public อัตโนมัติ)
6. **ข้อความยินยอมต้องอยู่เหนือปุ่ม Post** — "By posting, you agree to TikTok's Music Usage Confirmation" (+ Branded Content Policy เมื่อเปิด branded)
7. **ตรวจความยาววิดีโอกับ `max_video_post_duration_sec`** ตั้งแต่ในหน้านี้
8. **ตั้ง `is_aigc = true` เมื่อวิดีโอมาจาก AI** — ผลิตภัณฑ์เราสร้างวิดีโอด้วย Veo จึงต้องประกาศเสมอ

> 💡 ค่าจาก `creator_info` ต้อง **cache สั้น ๆ (≤ 5 นาที)** และ refetch ทุกครั้งที่เปิดหน้า — audit ตรวจว่าค่าที่แสดงตรงกับสถานะจริงของบัญชี

---

## 4. API Contract

Base: `https://api.<domain>/v1` · Auth: `Authorization: Bearer <access_token>`

### Auth
```
POST   /auth/register          {email, password, timezone}
POST   /auth/login             → {access_token(15m), refresh_token(30d), user}
POST   /auth/refresh           {refresh_token} → คู่ใหม่ (rotation, revoke ตัวเก่า)
POST   /auth/logout
POST   /devices                {fcm_token, platform} — สำหรับ push
```

### Connections
```
GET    /connections                        → รายการ + capability
POST   /connections/tiktok/oauth/start     → {authorize_url, state}
GET    /oauth/tiktok/callback              → redirect กลับ deep link แอป
POST   /connections/openai                 {api_key}  ← เข้ารหัสก่อนเก็บ
DELETE /connections/{id}
GET    /connections/{id}/tiktok/creator-info → proxy creator_info/query
```

`GET /connections` response:
```json
{
  "id": "conn_01H...",
  "provider": "tiktok",
  "display_name": "@yutthachai",
  "status": "active",
  "capabilities": {
    "can_publish_public": false,
    "max_posts_per_day": 15,
    "max_video_duration_sec": 600,
    "audit_status": "pending"
  }
}
```
> Flutter ต้องอ่าน `capabilities` ไป render ไม่ใช่ hardcode — ค่านี้จะเปลี่ยนตอนผ่าน audit

### Media
```
POST   /media/upload-url   {kind, mime, size_bytes}
                           → {asset_id, upload_url, headers, expires_at}
POST   /media/{id}/complete {checksum_sha256, duration_ms, width, height}
GET    /media/{id}         → {..., public_url, public_url_expires_at}
```
> มือถืออัปตรงขึ้น R2 ไม่ผ่าน API — วิดีโอ 200MB ห้ามวิ่งผ่าน Go

### Workflow / Run
```
GET    /workflows
POST   /workflows                       {name, definition}
POST   /workflows/{id}/versions         {definition} → version ใหม่
POST   /workflows/{id}/run              {input:{idea, platform, connection_id}}
                                        → {run_id, status:"queued"}
GET    /runs/{id}                       → run + node_runs ทั้งหมด (ใช้ polling)
GET    /runs?status=waiting_approval
POST   /runs/{id}/nodes/{node_id}/approve
                                        {decision:"approve"|"reject", caption?}
POST   /runs/{id}/cancel
```

### Publish
```
POST   /publish-jobs        Idempotency-Key: <uuid>   ← บังคับ
       {content_id, connection_id, scheduled_at,
        tiktok:{privacy_level, disable_comment, disable_duet, disable_stitch,
                brand_content_toggle, brand_organic_toggle, is_aigc,
                video_cover_timestamp_ms}}
GET    /publish-jobs/{id}
POST   /publish-jobs/{id}/cancel
POST   /publish-jobs/{id}/retry
```

### Webhook
```
POST   /webhooks/tiktok     ← verify signature ก่อนประมวลผลเสมอ
```

**Error envelope มาตรฐาน:**
```json
{"error":{"code":"CONNECTION_NEEDS_REAUTH",
          "message":"กรุณาเชื่อมต่อ TikTok ใหม่",
          "details":{"connection_id":"conn_..."}}}
```

---

## 5. Database Schema (PostgreSQL)

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ── users ────────────────────────────────────────────
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         citext UNIQUE NOT NULL,
  password_hash text   NOT NULL,
  display_name  text,
  timezone      text   NOT NULL DEFAULT 'Asia/Bangkok',  -- สำคัญกับ scheduler
  status        text   NOT NULL DEFAULT 'active',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE devices (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fcm_token  text NOT NULL,
  platform   text NOT NULL,           -- ios | android
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, fcm_token)
);

-- ── connections (token vault) ─────────────────────────
CREATE TABLE platform_connections (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider            text NOT NULL,       -- tiktok | openai | google | facebook
  kind                text NOT NULL,       -- publisher | ai
  credential_source   text NOT NULL DEFAULT 'user',  -- user (BYOK) | platform
  external_account_id text,
  display_name        text,
  scopes              text[],

  -- envelope encryption: ห้ามเก็บ plain text เด็ดขาด
  access_token_ct     bytea,
  access_token_nonce  bytea,
  refresh_token_ct    bytea,
  refresh_token_nonce bytea,
  key_version         int  NOT NULL DEFAULT 1,

  access_expires_at   timestamptz,
  refresh_expires_at  timestamptz,
  capabilities        jsonb NOT NULL DEFAULT '{}',
  status              text  NOT NULL DEFAULT 'active',
                      -- active | expired | needs_reauth | revoked
  last_refreshed_at   timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider, external_account_id)
);
CREATE INDEX ON platform_connections (access_expires_at)
  WHERE status = 'active' AND refresh_token_ct IS NOT NULL;

-- ── workflow ──────────────────────────────────────────
CREATE TABLE workflows (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       text NOT NULL,
  status     text NOT NULL DEFAULT 'draft',  -- draft | active | archived
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- แยก version ออกมา เพื่อให้ run ที่ค้างอยู่ไม่พังเวลาผู้ใช้แก้ workflow
CREATE TABLE workflow_versions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_id uuid NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  version     int  NOT NULL,
  definition  jsonb NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workflow_id, version)
);

CREATE TABLE workflow_runs (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  workflow_id         uuid NOT NULL REFERENCES workflows(id),
  workflow_version_id uuid NOT NULL REFERENCES workflow_versions(id), -- freeze
  status              text NOT NULL DEFAULT 'queued',
  trigger_type        text NOT NULL DEFAULT 'manual',
  context             jsonb NOT NULL DEFAULT '{}',
  current_node_id     text,
  error               jsonb,
  started_at          timestamptz,
  finished_at         timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON workflow_runs (user_id, created_at DESC);
CREATE INDEX ON workflow_runs (status) WHERE status NOT IN
  ('completed','failed','cancelled','rejected');

CREATE TABLE workflow_node_runs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id          uuid NOT NULL REFERENCES workflow_runs(id) ON DELETE CASCADE,
  node_id         text NOT NULL,
  node_type       text NOT NULL,      -- ai_text | approval | schedule | publish
  provider        text,
  status          text NOT NULL DEFAULT 'pending',
  attempt         int  NOT NULL DEFAULT 0,
  input           jsonb,
  output          jsonb,
  error           jsonb,
  external_job_id text,               -- เช่น operation id ของ Veo
  started_at      timestamptz,
  finished_at     timestamptz,
  UNIQUE (run_id, node_id, attempt)
);

-- ── content ───────────────────────────────────────────
CREATE TABLE contents (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  run_id     uuid REFERENCES workflow_runs(id) ON DELETE SET NULL,
  title      text,
  caption    text,
  hashtags   text[],
  status     text NOT NULL DEFAULT 'draft',
             -- draft | processing | ready | scheduled | published | failed
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE media_assets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id      uuid REFERENCES contents(id) ON DELETE SET NULL,
  kind            text NOT NULL,       -- video | image
  source          text NOT NULL,       -- upload | ai
  storage_key     text NOT NULL,
  mime            text NOT NULL,
  size_bytes      bigint,
  duration_ms     int,
  width           int,
  height          int,
  checksum_sha256 text,
  status          text NOT NULL DEFAULT 'pending', -- pending|uploaded|failed
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ── publishing ────────────────────────────────────────
CREATE TABLE publish_jobs (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_id         uuid NOT NULL REFERENCES contents(id),
  connection_id      uuid NOT NULL REFERENCES platform_connections(id),
  platform           text NOT NULL,
  platform_options   jsonb NOT NULL DEFAULT '{}',  -- privacy_level, toggles, is_aigc
  scheduled_at       timestamptz NOT NULL,
  status             text NOT NULL DEFAULT 'scheduled',
  -- กันโพสต์ซ้ำ: กู้ไม่ได้ถ้าพลาด
  idempotency_key    text NOT NULL UNIQUE,
  attempt            int  NOT NULL DEFAULT 0,
  max_attempts       int  NOT NULL DEFAULT 4,
  next_run_at        timestamptz,
  locked_at          timestamptz,
  locked_by          text,
  external_publish_id text,            -- publish_id จาก TikTok
  external_post_id    text,
  permalink           text,
  last_error          jsonb,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
-- index ที่ scheduler ใช้จริง
CREATE INDEX ON publish_jobs (scheduled_at)
  WHERE status = 'scheduled' AND locked_at IS NULL;
CREATE INDEX ON publish_jobs (next_run_at)
  WHERE status IN ('queued','uploading','processing');

CREATE TABLE publish_attempts (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  publish_job_id uuid NOT NULL REFERENCES publish_jobs(id) ON DELETE CASCADE,
  attempt        int  NOT NULL,
  request        jsonb,
  response       jsonb,
  http_status    int,
  error_code     text,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- ── ops ───────────────────────────────────────────────
CREATE TABLE usage_records (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  run_id      uuid REFERENCES workflow_runs(id) ON DELETE SET NULL,
  provider    text NOT NULL,
  model       text,
  operation   text NOT NULL,     -- text | image | video
  units       bigint NOT NULL,   -- tokens | วินาที | จำนวนรูป
  cost_micros bigint NOT NULL,   -- USD ×1,000,000 — ห้ามใช้ float กับเงิน
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON usage_records (user_id, created_at DESC);

CREATE TABLE notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type       text NOT NULL,
  title      text NOT NULL,
  body       text,
  data       jsonb,
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE idempotency_keys (
  key          text PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endpoint     text NOT NULL,
  request_hash text NOT NULL,
  response     jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);
```

**หมายเหตุ V0.1:** ยังไม่ต้องมี `audit_logs` (ทำตอนก่อนเปิดขายจริง)

---

## 6. State Machines

### 6.1 `workflow_runs.status`

```
queued ──▶ running ──┬─▶ waiting_approval ──┬─▶ running
                     │                      └─▶ rejected  (ปลายทาง)
                     ├─▶ waiting_schedule ──▶ publishing ──┬─▶ completed
                     │                                     └─▶ failed
                     └─▶ failed
ทุกสถานะที่ยังไม่จบ ──▶ cancelled
```

> **run อยู่ต่อจนโพสต์เสร็จ** ไม่จบตอนตั้งเวลา — เพื่อให้มี source of truth เดียวสำหรับ progress ที่ผู้ใช้เห็น

### 6.2 `workflow_node_runs.status`

```
pending ──▶ running ──┬─▶ succeeded
                      ├─▶ waiting_external   (รอ Veo/AI job)
                      ├─▶ waiting_input      (รอผู้ใช้อนุมัติ)
                      └─▶ failed ──▶ running   (retry, attempt+1)
```

### 6.3 `publish_jobs.status`

```
scheduled ──▶ queued ──▶ uploading ──▶ processing ──┬─▶ published
     │                       │              │        └─▶ failed
     │                       └──────────────┴─▶ failed ──▶ queued (retry)
     └──▶ cancelled
```

Mapping จาก TikTok `status/fetch`:
| TikTok | ของเรา |
|---|---|
| `PROCESSING_UPLOAD` / `PROCESSING_DOWNLOAD` | `processing` |
| `PUBLISH_COMPLETE` | `published` |
| `FAILED` | `failed` + เก็บ reason |

---

## 7. Sequence — ตั้งแต่พิมพ์ไอเดียจนโพสต์ขึ้น

```
App          API              PG          Redis        Worker       TikTok
 │            │                │            │            │            │
 ├─POST /run─▶│                │            │            │            │
 │            ├─create run────▶│            │            │            │
 │            ├─enqueue────────┼───────────▶│            │            │
 │◀─{run_id}──┤                │            │            │            │
 │            │                │            ├───────────▶│            │
 │            │                │            │  node ai_text           │
 │            │                │            │            ├─OpenAI────▶│
 │            │                │◀───────────┼─save caption            │
 │            │                │◀───────────┼─usage_records           │
 │◀════ FCM "พร้อมตรวจ" ═══════════════════════┤            │
 │            │                │            │            │            │
 ├─upload-url▶│                │            │            │            │
 ├════ PUT ตรงขึ้น R2 (ไม่ผ่าน API) ════════════════════════▶ R2
 ├─complete──▶│                │            │            │            │
 │            │                │            │            │            │
 ├─approve───▶│  node approval → succeeded  │            │            │
 │            │                │            │            │            │
 ├─GET creator-info───────────▶│────────────┼────────────┼───────────▶│
 │◀─privacy options, limits────┤            │            │            │
 │  [ Composer: ผู้ใช้เลือกเอง ]  │            │            │            │
 ├─POST /publish-jobs─────────▶│            │            │            │
 │   + Idempotency-Key         ├─publish_job (scheduled) │            │
 │◀─{job_id, scheduled}────────┤            │            │            │
 │                                                                     │
 │   ⏰ ผู้ใช้ปิดแอปได้ — ที่เหลือระบบทำเอง                                  │
 │                                                                     │
 │            │  scheduler ticker ทุก 10 วิ:                             │
 │            │  SELECT..WHERE scheduled_at<=now() FOR UPDATE SKIP LOCKED│
 │            │                │            ├───────────▶│            │
 │            │                │            │            ├─init(PULL_FROM_URL)▶
 │            │                │            │            │◀─publish_id│
 │            │                │            │            ├─poll status▶
 │            │                │            │            │◀PUBLISH_COMPLETE
 │            │                │◀───────────┼─external_post_id        │
 │◀════ FCM "โพสต์สำเร็จ ✅" ═══════════════════┤            │
```

---

## 8. Worker & Scheduler

### 8.1 กฎเหล็ก: Postgres เป็นเจ้าของงาน Redis เป็นแค่ท่อ

Redis delayed job หายได้ตอน restart หรือโดน evict → โพสต์ไม่ออกโดยไม่มีใครรู้

```go
// scheduler ticker — ทุก 10 วินาที
const claimDueJobs = `
UPDATE publish_jobs
   SET status = 'queued', locked_at = now(), locked_by = $1
 WHERE id IN (
     SELECT id FROM publish_jobs
      WHERE status = 'scheduled'
        AND scheduled_at <= now()
        AND locked_at IS NULL
      ORDER BY scheduled_at
      LIMIT 50
      FOR UPDATE SKIP LOCKED       -- หลาย worker แย่งกันได้ปลอดภัย
 )
RETURNING id;`
```
ได้ id มาแล้วค่อย `LPUSH` เข้า Redis ให้ worker ทำงานจริง

### 8.2 Reaper
งานที่ `locked_at < now() - interval '10 minutes'` แต่ยังไม่จบ → ปลดล็อกกลับเป็น `scheduled` (worker ตายกลางทาง)

### 8.3 Poller
`publish_jobs` ที่ `processing` → poll `status/fetch` แบบ backoff `10s, 20s, 40s, 60s...` สูงสุด 30 นาที เกินนั้น → `failed` (timeout)

### 8.4 Queue
| Queue | งาน | Concurrency |
|---|---|---|
| `q:workflow` | เดิน node | 10 |
| `q:publish` | โพสต์จริง | **3** (กัน rate limit) |
| `q:poll` | เช็คสถานะ | 5 |
| `q:notify` | ส่ง FCM | 10 |

---

## 9. Security

| เรื่อง | ทำอะไร |
|---|---|
| **Token at rest** | AES-256-GCM, key จาก env/KMS, เก็บ nonce แยก, มี `key_version` เพื่อหมุนคีย์ได้ |
| **Refresh rotation** | ทุกครั้งที่ refresh → revoke ตัวเก่าทันที; ถ้าตัวเก่าถูกใช้ซ้ำ = สงสัยรั่ว → revoke ทั้ง session |
| **JWT** | access 15 นาที, refresh 30 วัน เก็บใน secure storage ของมือถือ |
| **Multi-tenant** | ทุก query บังคับ `WHERE user_id = $current` — เขียนเป็น repository layer อย่าปล่อยให้ handler ประกอบ SQL เอง |
| **Webhook** | verify signature ก่อน parse body เสมอ |
| **Rate limit** | ต่อ user ต่อ endpoint |
| **PDPA** | Privacy Policy + ToS + endpoint ลบข้อมูล (Meta บังคับ data deletion callback) |
| **ห้าม** | log access_token / api_key ลง log ทุกกรณี |

---

## 10. Error & Retry Matrix

| อาการ | Retry? | ทำอะไร |
|---|---|---|
| Network / timeout | ✅ | backoff 1m → 5m → 15m → 60m สูงสุด 4 ครั้ง |
| HTTP 5xx | ✅ | เหมือนบน |
| HTTP 429 | ✅ | ตาม `Retry-After`; ถ้าไม่มี ใช้ backoff |
| 401 / token หมดอายุ | ⚠️ | refresh ก่อน 1 ครั้ง แล้วลองใหม่ |
| refresh ไม่สำเร็จ | ❌ | connection → `needs_reauth`, **เลื่อน job ไม่ใช่ fail**, push แจ้ง |
| 400 validation | ❌ | fail ถาวร แสดงข้อความจริงให้ผู้ใช้ |
| TikTok `FAILED` | ❌ | fail + เก็บ reason code + push |
| เกิน 15 โพสต์/วัน | ❌ | กันตั้งแต่ตอนสร้าง job ไม่ปล่อยไปตายที่ API |
| Poll เกิน 30 นาที | ❌ | timeout → `failed` |

**หลัก:** ทุก retry ต้องผ่าน `idempotency_key` เดิม — ห้ามสร้าง job ใหม่

---

## 11. TikTok Audit Checklist (เตรียมก่อนยื่น)

- [ ] Domain + HTTPS ใช้งานได้
- [ ] Domain verification สำหรับ `PULL_FROM_URL` (โดเมนที่โฮสต์วิดีโอ)
- [ ] Privacy Policy URL เข้าถึงได้สาธารณะ
- [ ] Terms of Service URL
- [ ] Composer ครบทั้ง 8 ข้อในหัวข้อ 3.1
- [ ] วิดีโอสาธิต end-to-end: login → เชื่อม TikTok → เลือกวิดีโอ → composer → post → เห็นโพสต์บน TikTok
- [ ] อธิบาย use case ชัดเจน ("เครื่องมือตั้งเวลาโพสต์สำหรับร้านค้าออนไลน์")
- [ ] แสดงการจัดการข้อมูลผู้ใช้และวิธีลบข้อมูล

> ⏱️ **ยื่นให้เร็วที่สุด** — audit ใช้ 2–4 สัปดาห์และมักถูกตีกลับหลายรอบ นาฬิกานี้คือ critical path ตัวจริง สร้างส่วนที่เหลือระหว่างรอ

---

## 12. Build Order

| สัปดาห์ | โค้ด | งานเอกสาร (ขนานกัน) |
|---|---|---|
| **W1** | Go+Gin skeleton, migrations, JWT auth, docker-compose | จดบริษัท, ซื้อ domain |
| **W2** | OAuth TikTok + token vault, R2 presigned upload | Privacy Policy, ToS, data deletion endpoint |
| **W3** | Publisher interface + TikTok publisher, scheduler ticker, poller | สมัคร TikTok app, domain verification |
| **W4** | Flutter: Login, Connections, Composer (สเปก 3.1), Approve | อัดวิดีโอสาธิต |
| **W5** | ต่อให้ครบเส้น + deploy VPS | **🚩 ยื่น audit TikTok** |
| **W6-8** | ระหว่างรอ: Workflow Engine, AI text node, Veo, Meta connector | ตอบ feedback จาก audit |
| **W9** | ผ่าน audit → เปิดขายด้วยมือกับลูกค้า 5-10 ราย | |

**Definition of Done V0.1:**
> เปิดแอปจริง → พิมพ์ไอเดีย → ได้ caption → อัปวิดีโอ → อนุมัติ → ตั้งเวลา +5 นาที → **ปิดแอป** → ได้ push "โพสต์สำเร็จ" → เปิด TikTok เห็นโพสต์นั้นจริง

---

## 13. เรื่องที่ยังต้องยืนยันตอนลงมือ

1. `creator_info/query` คืนชื่อ field อะไรบ้างแน่ (`privacy_level_options`, `comment_disabled`, `max_video_post_duration_sec`) — ยืนยันจากการยิงจริง
2. `PULL_FROM_URL` ต้อง verify domain ของ R2 custom domain หรือของ API — ถ้าติดปัญหา ให้ fallback เป็น `FILE_UPLOAD` แบบ chunked
3. TikTok status values ที่คืนจริงจาก `status/fetch`
4. ราคาแพ็กเกจและโควตา (ยังไม่ล็อก — Buffer อยู่ที่ ~$6/channel/เดือน เป็นหมุดอ้างอิง)
