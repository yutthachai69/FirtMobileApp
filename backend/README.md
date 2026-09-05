# RelayContent — Backend

Google Login: ดู [การตั้งค่าและ API](../docs/google-login.md) สำหรับ `/v1/auth/google` และ `/v1/auth/google/link`

Go + Gin API และ background worker สำหรับ RelayContent
ออกแบบไว้ที่ [`../docs/system-design-v1.md`](../docs/system-design-v1.md)

---

## เริ่มใช้งาน

```bash
cd backend
cp .env.example .env          # แล้วแก้ค่าใน .env
go run ./cmd/genkey           # เอาผลไปใส่ ENCRYPTION_KEYS

docker compose up -d --build
curl http://localhost:8080/health
```

ควรได้:
```json
{"checks":{"postgres":"ok","redis":"ok"},"status":"ok","version":"dev"}
```

### รันบนเครื่องโดยตรง (ไม่ผ่าน Docker)

```bash
docker compose up -d postgres redis    # เอาแค่ dependency
go run ./cmd/api
go run ./cmd/worker                    # อีกหน้าต่างหนึ่ง
```

> **Postgres publish ที่พอร์ต `15432` ไม่ใช่ 5432** (ตั้งด้วย `POSTGRES_PORT`)
> เพราะเครื่อง dev มักมี PostgreSQL ติดตั้งไว้แล้วและจอง 5432 อยู่
> ถ้าชี้ `DATABASE_URL` ไป 5432 จะไปต่อ Postgres ตัวอื่นแล้วงงว่าทำไม auth ไม่ผ่าน

### ทดสอบ media upload โดยยังไม่มีบัญชี Cloudflare

```bash
docker compose --profile localstorage up -d   # MinIO = S3 จำลอง
# .env ตั้ง R2_ENDPOINT=http://localhost:9000 ไว้แล้ว
```

MinIO console: http://localhost:9001 (`relaycontent` / `relaycontent_dev`)

> presigned URL ที่ได้จะชี้ไป `localhost:9000` จึงใช้ได้เมื่อ **รัน API บนเครื่อง**
> ถ้ารัน API ใน container ให้ใช้ R2 จริง (ตั้ง `R2_ACCOUNT_ID` แล้วเว้น `R2_ENDPOINT`)

---

## คำสั่งที่ใช้บ่อย

| งาน | คำสั่ง |
|---|---|
| build | `go build ./...` |
| test | `go test ./... -race -count=1` |
| vet | `go vet ./...` |
| ขึ้นทั้ง stack | `docker compose up -d --build` |
| ดู log | `docker compose logs -f api worker` |
| เข้า psql | `docker compose exec postgres psql -U relaycontent -d relaycontent` |
| ลบทุกอย่างรวม data | `docker compose down -v` |

มี `Makefile` ให้ด้วยถ้าเครื่องมี `make`

---

## Endpoint ตอนนี้

| Method | Path | ทำอะไร | Rate limit |
|---|---|---|---|
| GET | `/health/live` | process ยังอยู่ไหม (ไม่แตะ dependency) | — |
| GET | `/health/ready` | พร้อมรับ traffic ไหม (ping Postgres + Redis) | — |
| GET | `/health` | ทางลัดของ ready | — |
| GET | `/v1/ping` | ทดสอบ | — |
| POST | `/v1/auth/register` | สมัคร → คืน user + tokens | 10/ชม. ต่อ IP |
| POST | `/v1/auth/login` | เข้าสู่ระบบ | 10/นาที ต่อ IP |
| POST | `/v1/auth/refresh` | ต่ออายุ + rotate refresh token | 60/นาที ต่อ IP |
| POST | `/v1/auth/logout` | revoke refresh token | — |
| GET | `/v1/auth/me` | ข้อมูลผู้ใช้ปัจจุบัน (ต้องมี Bearer) | — |
| POST | `/v1/auth/google` | เข้าสู่ระบบด้วย Google `id_token` | 10/นาที ต่อ IP |
| POST | `/v1/auth/google/link` | ผูก Google กับบัญชีเดิม (ต้องยืนยันรหัสผ่าน) | 10/นาที ต่อ IP |
| GET | `/v1/media/limits` | เพดานขนาดไฟล์ + mime ที่รองรับ | — |
| POST | `/v1/media/upload-url` | ขอ presigned PUT → **มือถืออัปตรงขึ้น storage** | — |
| POST | `/v1/media/:id/complete` | ยืนยันอัปเสร็จ (ระบบ HEAD เช็คของจริง) | — |
| GET | `/v1/media/:id` | ข้อมูลไฟล์ + `public_url` ชั่วคราว | — |
| DELETE | `/v1/media/:id` | ลบไฟล์ | — |
| POST | `/v1/contents` | สร้างคอนเทนต์ + ผูกวิดีโอ | — |
| GET | `/v1/contents` | รายการ (filter ด้วย `?status=`) | — |
| GET/PATCH | `/v1/contents/:id` | ดู / แก้ caption, hashtags | — |
| POST | `/v1/publish-jobs` | **ตั้งเวลาโพสต์** (ต้องมี `Idempotency-Key`) | — |
| GET | `/v1/publish-jobs` | รายการงานโพสต์ | — |
| GET | `/v1/publish-jobs/:id` | สถานะงาน + `permalink` | — |
| POST | `/v1/publish-jobs/:id/cancel` | ยกเลิก (เฉพาะที่ยังไม่ส่ง) | — |
| POST | `/v1/publish-jobs/:id/retry` | ลองใหม่ (ใช้ key เดิม ไม่เกิดโพสต์ซ้ำ) | — |
| POST/DELETE | `/v1/devices` | ลงทะเบียน/ถอน FCM token | — |
| GET | `/v1/notifications` | รายการแจ้งเตือน (`?unread=true`) | — |
| POST | `/v1/notifications/read-all` | ทำเครื่องหมายว่าอ่านแล้ว | — |
| POST | `/v1/oauth/tiktok/start` | ขอ `authorize_url` เริ่มเชื่อม TikTok | — |
| GET | `/v1/oauth/tiktok/callback` | **TikTok เรียก** → เด้งกลับแอปด้วย deep link | — |
| GET | `/v1/connections` | รายการบัญชีที่เชื่อมไว้ + `capabilities` | — |
| DELETE | `/v1/connections/:id` | ถอนสิทธิ์ที่ TikTok แล้วลบ | — |
| GET | `/v1/connections/:id/creator-info` | **ข้อมูลสดสำหรับหน้า Composer** | — |

`live` กับ `ready` แยกกันเพราะ orchestrator ใช้คนละความหมาย —
live ล้ม = ควรรีสตาร์ต, ready ล้ม = ถอดออกจาก load balancer ชั่วคราว

### รูปแบบ error เดียวทั้งระบบ

```json
{"error": {"code": "VALIDATION_ERROR",
           "message": "ข้อมูลที่ส่งมาไม่ถูกต้อง",
           "details": {"field": "password", "reason": "รหัสผ่านต้องยาวอย่างน้อย 8 ตัวอักษร"}}}
```

`code` ให้แอปตัดสินใจ (เช่น `CONNECTION_NEEDS_REAUTH` → พาไปหน้า Connections)
`message` เป็นภาษาไทยที่แสดงให้ผู้ใช้เห็นได้เลย

---

## โครงสร้าง

```
cmd/
  api/        HTTP API
  worker/     scheduler + publisher + poller (W3)
  genkey/     สร้าง encryption key

internal/
  config/     โหลด env, ตายตั้งแต่บูตถ้าค่าจำเป็นขาด
  database/   postgres pool, redis client, migration runner
  health/     liveness / readiness
  httpserver/ gin server, middleware, graceful shutdown

pkg/
  crypto/     envelope encryption AES-256-GCM + key rotation
  logger/     slog (JSON บน production, text บน dev)

migrations/   SQL แบบ golang-migrate ฝังไว้ในไบนารี
```

---

## หลักการที่ยึดไว้

**Postgres เป็นเจ้าของงาน Redis เป็นแค่ท่อ**
งานที่ตั้งเวลาไว้ทั้งหมดอยู่ใน `publish_jobs` ถ้า Redis หายทั้งตัวยังกู้งานได้ครบ
Redis delayed job หายได้ตอน restart หรือโดน evict → โพสต์ไม่ออกโดยไม่มีใครรู้

**Token ของแพลตฟอร์มห้ามเป็น plain text**
`platform_connections` เก็บ ciphertext + nonce + `key_version` แยกกัน
หมุนคีย์ได้โดยไม่ต้อง re-encrypt ทั้งฐานพร้อมกัน — เพิ่ม version ใหม่ต่อท้าย **ห้ามลบของเก่า**

**`idempotency_key` บน `publish_jobs` เป็น UNIQUE**
ถ้า worker retry แล้วยิงซ้ำ ผู้ใช้จะได้โพสต์ซ้ำบน TikTok ซึ่ง **กู้ไม่ได้**

**ตายตั้งแต่บูตดีกว่าพังตอนรัน**
config ที่ขาด, `ENCRYPTION_KEYS` ที่พัง, DB ต่อไม่ได้ → process ไม่ขึ้นเลย

**`cost_micros` เป็น bigint ไม่ใช่ float**
ห้ามใช้ float กับเงิน

---

**Refresh token rotation + ตรวจจับการใช้ซ้ำ**
refresh token เป็น random string ไม่ใช่ JWT (ต้อง revoke ได้ทันที) และ DB เก็บแค่ sha256
ทุกครั้งที่ refresh จะออกตัวใหม่แล้ว revoke ตัวเก่าใน transaction เดียว
ถ้าตัวเก่าถูกนำมาใช้อีก = สัญญาณว่า token รั่ว → **ตัดทุกเซสชันของผู้ใช้คนนั้นทิ้ง**

---

## การเชื่อม TikTok

```
แอป: POST /v1/oauth/tiktok/start        → {authorize_url}
     เปิด authorize_url ใน in-app browser
ผู้ใช้: กดอนุญาตบน tiktok.com
TikTok: GET /v1/oauth/tiktok/callback?code=..&state=..
        backend แลก code → เข้ารหัสเก็บ token → ถาม creator_info
        302 → relaycontent://oauth/tiktok?status=success&connection_id=..
แอป: ref.invalidate(connectionsProvider)
```

**แอปไม่เคยเห็น access token ของ TikTok** — callback วิ่งเข้า backend ไม่ใช่เข้าแอป

**`state` เก็บใน Redis อายุ 10 นาที ใช้ครั้งเดียว** (`GETDEL` แบบ atomic)
มันคือตัวผูก callback เข้ากับผู้ใช้ที่เริ่ม flow และกัน CSRF ไปพร้อมกัน

**PKCE เปิดไว้เป็นค่าเริ่มต้น** — `code_verifier` เก็บคู่กับ state ปิดได้ด้วย `TIKTOK_USE_PKCE=false`

**TikTok หมุน refresh token ทุกครั้งที่ refresh** — โค้ดจึงบันทึกทับทั้งคู่เสมอ
ถ้าเก็บแต่ตัวเก่า ครั้งถัดไปจะต่ออายุไม่ได้และผู้ใช้ต้องเชื่อมใหม่โดยไม่มีสาเหตุชัดเจน

**`capabilities` มาจาก `creator_info` จริง ไม่ใช่ค่า hardcode**
```json
{"can_publish_public": false, "privacy_level_options": ["SELF_ONLY"],
 "comment_disabled": false, "max_video_duration_sec": 600, "max_posts_per_day": 15}
```
`can_publish_public` จะเป็น `false` จนกว่า TikTok app จะผ่าน audit — แอปอ่านค่านี้ไปบอกผู้ใช้ล่วงหน้า

**ยังไม่ได้ตั้งค่า TikTok ก็บูตได้** — endpoint ที่เกี่ยวตอบ `503 PROVIDER_NOT_CONFIGURED`
ทำให้พัฒนาส่วนอื่นต่อได้ระหว่างรอ app ผ่านการอนุมัติ

---

## Google Sign-In

`POST /v1/auth/google` รับ `id_token` จากแอป ยืนยันลายเซ็นกับ Google ผ่าน OIDC
(`GOOGLE_CLIENT_ID` ต้องตรงกับ audience ของ token ไม่งั้นถูกปฏิเสธทุกใบ)

**ระบบไม่ merge บัญชีด้วยอีเมลโดยอัตโนมัติ** — ถ้าอีเมลนั้นมีบัญชีรหัสผ่านอยู่แล้ว
จะตอบ `409 ACCOUNT_LINK_REQUIRED` ให้ผู้ใช้ล็อกอินบัญชีเดิมแล้วเรียก `/auth/google/link`
พร้อมยืนยันรหัสผ่านก่อน ป้องกันการยึดบัญชีด้วยอีเมลซ้ำ

ผู้ใช้ที่สมัครผ่าน Google จะมี `password_hash` เป็นค่าว่าง = **ล็อกอินด้วยรหัสผ่านไม่ได้**
(bcrypt ปฏิเสธ hash ว่างเสมอ)

การ login ครั้งแรกพร้อมกันหลาย request ถูกกันด้วย `pg_advisory_xact_lock`
ไม่งั้นจะสร้าง user ซ้ำสองแถว

---

## Media upload

```
แอป: POST /v1/media/upload-url  {kind, mime, size_bytes}
     → {asset, upload:{url, headers, expires_at}}
แอป: PUT ตรงขึ้น storage ด้วย headers ที่ให้มา (ไม่ผ่าน Go API)
แอป: POST /v1/media/:id/complete {duration_ms, width, height}
     → backend HEAD เช็คว่าไฟล์มีจริงและขนาดตรง → status=uploaded
```

**ขนาดไฟล์ถูกผูกไว้ในลายเซ็น** (`Content-Length`) — client อัปเกินที่จองไว้ไม่ได้
storage จะปฏิเสธตั้งแต่ชั้น signature ไม่ต้องรอมาจับตอน complete

**`complete` ต้อง HEAD เช็คของจริงเสมอ** ห้ามเชื่อ client
ไม่งั้นแอปที่ถูกดัดแปลงจะกด complete โดยไม่เคยอัปไฟล์ แล้วไปพังตอน TikTok ดึงไฟล์

`public_url` เป็น presigned GET อายุ `DOWNLOAD_URL_TTL` (ค่าเริ่มต้น 2 ชม.)
ต้องนานพอให้ TikTok ดึงไฟล์จนจบ ไม่ใช่แค่พอให้แอปดู preview

---

## Scheduler & Worker

```
ผู้ใช้: POST /v1/publish-jobs {content_id, connection_id, scheduled_at, platform_options}
        → publish_jobs (scheduled)  ... ผู้ใช้ปิดแอปได้

worker ทุก 10 วิ: ClaimDue()  — FOR UPDATE SKIP LOCKED
        → queued → uploading → เรียก publisher.Publish()
        → processing (เก็บ external_publish_id, ปลดล็อกให้ poller)

worker ทุก 10 วิ: ClaimPollable()
        → publisher.Status() → published / failed / ยังประมวลผล (เลื่อน next_run_at)

worker ทุก 5 นาที: ReleaseStale() — ปลดล็อกงานของ worker ที่ตายกลางทาง
```

**ไม่มีคิวใน Redis** — งานทั้งหมดอยู่ใน `publish_jobs` และหยิบด้วย `FOR UPDATE SKIP LOCKED`
ซึ่งกระจายงานข้าม worker หลายตัวได้อย่างปลอดภัยอยู่แล้ว
การใส่ Redis คั่นกลางจะเพิ่มจุดที่งานหายได้โดยไม่ได้อะไรกลับมาที่ขนาดนี้
(Redis ยังใช้กับ rate limit และ OAuth state เหมือนเดิม)

**`ClaimDue` ต้องเช็ค `next_run_at` ด้วย** — ถ้าเช็คแค่ `scheduled_at`
งานที่เพิ่งล้มเหลวจะถูกหยิบซ้ำทุก 10 วินาที เท่ากับยิงใส่ปลายทางจนโดน rate limit
(บั๊กนี้เคยเกิดจริงและถูกจับได้ตอนทดสอบ — มีเทสกันไว้แล้ว)

**Retry backoff:** 1 → 5 → 15 → 60 นาที สูงสุด 4 ครั้ง
**Poll backoff:** 10 → 20 → 30 → 60 วินาที หมดเวลาที่ 30 นาที

### การจำแนกความผิดพลาด

| แบบ | เกิดเมื่อ | ทำอะไร |
|---|---|---|
| `FaultRetryable` | เน็ตล่ม, 5xx, 429 | ลองใหม่ตาม backoff |
| `FaultPermanent` | ข้อมูลผิด, วิดีโอไม่ผ่านเกณฑ์ | ล้มเหลวทันที ไม่ลองซ้ำ |
| `FaultAuth` | token ใช้ไม่ได้ | **เลื่อนงาน ไม่ทำให้ล้มเหลว** + แจ้งให้เชื่อมบัญชีใหม่ |

`FaultAuth` ไม่นับเป็น attempt และไม่ทำให้งานตาย —
ผู้ใช้แค่ต้องกดเชื่อมบัญชีใหม่ ไม่ควรเสียโพสต์ไปด้วย

### กันการโพสต์ซ้ำ

- `publish_jobs.idempotency_key` เป็น **UNIQUE** — ยิงซ้ำได้ผลเดิม ไม่เกิดงานใหม่
- โพสต์ซ้ำบน TikTok **กู้คืนไม่ได้** ลบไม่ทัน คนเห็นแล้ว จึงกันที่ระดับฐานข้อมูล

### กันการแจ้งเตือนซ้ำ

`NotifyOnce` ใช้ unique index (migration 000003) ไม่ใช่ SELECT-แล้วค่อย-INSERT
เพราะ worker ทำงานขนานกัน ถ้าเช็คก่อนเขียน ทุกตัวจะเช็คไม่เจอพร้อมกันแล้วต่างคนต่างเขียน
(บั๊กนี้ก็เคยเกิดจริงตอนทดสอบ — งานสองชิ้นบน connection เดียวกันส่ง push สองอัน)

### FCM ยังไม่ได้ต่อ

`notification.Service` รับ `Pusher` เป็น `nil` อยู่ = บันทึกการแจ้งเตือนลง DB
แต่ยังไม่ส่ง push จริง แอปดึงผ่าน `GET /v1/notifications` ได้แล้ว
พอมี Firebase service account ค่อยใส่ implementation เข้าไปโดยไม่ต้องแตะโค้ดส่วนอื่น

---

## การทดสอบ

```bash
go test ./... -count=1                    # unit tests

# integration tests ของ scheduler (ยิง SQL จริง)
TEST_DATABASE_URL="postgres://relaycontent:relaycontent_dev@127.0.0.1:15432/relaycontent?sslmode=disable" \
  go test ./internal/publish/ -count=1 -v
```

เทสของ `internal/publish` ยิงกับ Postgres จริงเพราะสิ่งที่ต้องพิสูจน์คือ **ตัว SQL เอง**
(`FOR UPDATE SKIP LOCKED`, การนับวันตาม timezone) การ mock ฐานข้อมูลจะทดสอบแค่โค้ด Go
แต่ไม่ได้ทดสอบสิ่งที่พังจริง — มีเทสที่ยิง 4 worker แย่งงาน 12 ชิ้นพร้อมกัน
เพื่อพิสูจน์ว่าไม่มีงานถูกหยิบซ้ำ

---

## ยังไม่ได้ทำ

- [x] publisher interface + TikTok publisher (init + status/fetch + validate)
- [x] scheduler ticker (`FOR UPDATE SKIP LOCKED`) + reaper + poller
- [x] contents / publish-jobs / notifications API
- [ ] **ต่อ FCM จริง** — ต้องมี Firebase service account
- [ ] ทดสอบกับ TikTok จริง (รอสมัคร developer app)
- [ ] ยังไม่ได้ทดสอบ down migration
- [ ] Workflow Engine + AI connector (V0.2)
