# RelayContent — Google Stitch UX Prompt Pack

ใช้ Prompt Pack นี้ใน **โปรเจกต์ Stitch เดียวกัน** ตามลำดับ ห้ามส่งทุก batch พร้อมกัน
เพราะโมเดลอาจย่อ requirement จำนวนมากเหลือเพียงหน้าตัวอย่างหนึ่งหน้า

อ่าน Product Brief ฉบับเต็มที่ [product-ux-brief-v1.md](product-ux-brief-v1.md)

---

## Prompt 0 — Product Constitution

ส่งข้อความนี้ก่อนเริ่มสร้างหน้าจอ และใช้เป็นกฎของทุก batch

```text
You are designing a complete mobile UX for RelayContent.

PRODUCT

RelayContent is a Thai mobile commerce content platform for TikTok Shop Affiliate
Creators. It helps a creator select a product from My Showcase, create or upload a
video, use AI to prepare the creative, attach a native TikTok Shop product basket,
schedule the post, publish it as a Shoppable Video, and recover failed jobs.

Core promise in Thai:
“เลือกสินค้า สร้างคอนเทนต์ ตั้งเวลา แล้วระบบโพสต์พร้อมตะกร้าให้”

PRIMARY USER

A solo TikTok Shop Affiliate Creator in Thailand who works mainly on a phone and
publishes multiple product videos every week.

UX PRINCIPLES

- Commerce-first: every content item clearly shows its associated product.
- Status-first: always show what needs attention and what the system is doing.
- Human approval: AI output must be reviewed before scheduling or publishing.
- Safe to leave: clearly state when background work continues after closing the app.
- Actionable errors: explain what happened, what remains safe, and what to do next.
- Product truth: price, stock, promotion, and commission come from synchronized data.
- Mobile-native: one-handed use, 48px touch targets, safe areas, keyboard-aware forms.

DESIGN DIRECTION

Create a premium “Calm Commerce Control Room”. Use a Content Relay visual language:
products and content cards move through connected workflow nodes. Use thumbnails,
timelines, progress, layered surfaces, and purposeful motion. Avoid a generic admin
dashboard and avoid wrapping every section in identical grey cards.

GLOBAL NAVIGATION

Use the same bottom navigation on all authenticated root screens:

1. หน้าหลัก
2. สินค้า
3. สร้าง — prominent center action
4. คอนเทนต์
5. โปรไฟล์

OUTPUT RULES

- Mobile artboard size: 390 × 844 px.
- All visible UI copy must be natural Thai.
- Create one separate artboard per requested screen.
- Label every artboard with its exact screen ID and name.
- Never merge multiple screens into one long page.
- Never replace screens created in an earlier batch.
- Do not create a moodboard or another design-system-only board.
- Use realistic Thai product names, prices, commissions, captions, dates, and statuses.
- Include loading, disabled, success, and error treatments requested in each batch.
- Keep all batches visually consistent.
- Preserve enough space for real Thai text and mobile accessibility.

Confirm this constitution by creating no screens yet. Wait for Batch 1.
```

---

## Prompt 1 — Entry and TikTok Shop Setup

```text
Create Batch 1 as 10 separate 390 × 844 mobile artboards.

A01 — Splash / Session Restore
RelayContent identity, Content Relay animation concept, and “กำลังเตรียมห้องควบคุมของคุณ”.

A02 — Onboarding 1
Explain selecting a product from TikTok Shop Showcase.

A02b — Onboarding 2
Explain AI-assisted content creation and human review.

A02c — Onboarding 3
Explain scheduling and publishing with a pinned product basket.

A03 — Login
Email, password, show password, forgot password, Google login, registration link,
and a Content Relay visual.

A04 — Register
Display name, email, password requirements, terms/privacy, Google registration.

A05 — Forgot Password
Email input, send action, confirmation treatment, return to login.

B01 — Connect TikTok Shop
Explain Creator authorization, requested permissions, privacy, and primary connect action.

B03 — Eligibility Check
Show checks for Affiliate Creator eligibility, Showcase access, and video publishing scope.

B04 — Connection Success
Show avatar, Thai @username, connection status, permission summary, last sync,
and “ดูสินค้าใน Showcase”.

Connect the prototype flow from A01 through B04. Do not create screens from later batches.
```

---

## Prompt 2 — Home and Product Discovery

```text
Create Batch 2 as 9 new separate 390 × 844 mobile artboards. Preserve Batch 1.

B05 — Connection Problem
Expired creator token. Explain that drafts and schedules remain safe. Show “เชื่อมใหม่”.

C01 — Home / New User
Show first-product guidance, empty schedule, and a strong “สร้างคลิปแรก” action.

C02 — Home / Active Control Room
Use thumbnails and clear hierarchy. Include ต้องทำ, กำลังสร้าง, รอตรวจ,
ตั้งเวลาไว้, and โพสต์แล้ววันนี้. Every content card must show its product.

C03 — Home / All Clear
Show “ทุกอย่างเรียบร้อย”, next scheduled shoppable video, and weekly summary.

C04 — Notifications
Actionable notifications for AI ready, TikTok reconnect, product unavailable,
publish success, and publish failure.

D01 — My Showcase
Search, category/status filters, product image, price, commission, stock, eligibility,
and “สร้างคอนเทนต์”.

D02 — Product Detail
Gallery, name, current price, discount, stock, commission, shop, synchronized time,
selling points, and “สร้างคอนเทนต์จากสินค้านี้”.

D03 — Product Unavailable
Show an out-of-stock or removed product while preserving linked draft content.
Offer replace product and refresh actions.

D04 — Showcase Empty
Explain how to add products to TikTok Showcase and provide an “เปิด TikTok” action.

Connect Home to Products, Product Detail, Create, Notifications, and Profile destinations.
```

---

## Prompt 3 — AI Content Creation

```text
Create Batch 3 as 10 new separate 390 × 844 mobile artboards. Preserve earlier batches.

E01 — Create Source
Offer three paths: “สร้างด้วย AI จากสินค้า”, “อัปโหลดวิดีโอของฉัน”,
and “เริ่มจากไอเดีย”. Show the currently selected product when applicable.

E02 — Creative Brief
Product summary, objective, audience, tone, duration, format, presenter style,
language, CTA, reference upload, estimated credits, and generate action.

E03 — Content Ideas
Show 4 realistic concepts with hook, structure, duration, visual direction,
and “ใช้ไอเดียนี้”.

E04 — Generation Progress
Show วิเคราะห์สินค้า, Script, Voice, Scenes, Composition, Subtitle, Quality Check.
State clearly that the user can leave and will be notified.

E05 — Variant Review
Compare three video variants with thumbnails, hook, duration, CTA, and credit impact.

E06 — AI Editor
Video timeline and simple actions: change hook, regenerate voice, replace scene,
edit subtitle, shorten video, and preview. Support regenerating one node only.

E06b — AI Product Truth Warning
Show that the current product price changed after generation. Compare old and new data.
Offer update overlays, regenerate affected scenes, or remove visible price.

E06c — AI Generation Failure
Voice generation failed while script and scenes remain safe. Offer retry voice only.

E06d — Insufficient Credits
Show required credits, current credits, purchase action, and return without losing the brief.

E06e — Ready for Review
Final AI video, AI-generated label, product, caption draft, checklist, edit and approve actions.

Connect Product Detail → E01 → E02 → E03 → E04 → E05 → E06 → Ready for Review.
```

---

## Prompt 4 — Upload, Basket and Publishing

```text
Create Batch 4 as 12 new separate 390 × 844 mobile artboards. Preserve earlier batches.

F01 — Select Video
Inviting MP4/MOV picker, 100 MB limit, recent media, selected product, and choose action.

F02 — Upload Progress
Thumbnail, filename, progress, percentage, remaining time, cancel, and safe-to-leave message.

F03 — Video Preview
Playback, replace, trim, duration validation, selected product, and continue action.

F04 — Caption & Product
Caption editor, 2,200 counter, CTA suggestions, selected product card,
Product Anchor title with 30-character counter, replace product, and preview basket.

G01 — TikTok Shop Composer
Creator identity, video, product basket, privacy with no default, comment/duet/stitch,
commercial disclosure, branded content, AI-generated state, policies, and sticky continue action.

G02 — Composer Blocked
Missing privacy and invalid product-anchor examples. Preserve all entered data.

G03 — Post Now or Schedule
Two clear options with video and basket summary.

G04 — Date & Time
Mobile date/time selection, Asia/Bangkok timezone, suggested posting times,
and conflict warning.

G05 — Review & Confirm
Final video, creator, product, basket label, caption, settings, disclosure,
date/time, edit links, and “ยืนยันและตั้งเวลา”.

G06 — Job Accepted
Content card moving into a calendar slot, safe-to-close copy, Home and Detail actions.

G06b — Publishing Now
Workflow progress: เตรียมไฟล์ → อัปโหลด → ผูกตะกร้า → ส่งไป TikTok → ตรวจสถานะ.

G06c — Publish Success
Shoppable video published, thumbnail, product basket, permalink, and “เปิดบน TikTok”.

Connect both AI Ready for Review and Video Upload flows into F04, G01, scheduling,
and publishing results.
```

---

## Prompt 5 — Content Management and Recovery

```text
Create Batch 5 as 10 new separate 390 × 844 mobile artboards. Preserve earlier batches.

H01 — Content Library
Thumbnail-first list with filters: ทั้งหมด, แบบร่าง, กำลังสร้าง, รอตรวจ,
ตั้งเวลาไว้, โพสต์แล้ว, ไม่สำเร็จ. Every item shows its product basket.

H02 — Draft Detail
Video/idea preview, product, last edit, continue, duplicate, and delete actions.

H03 — Processing Detail
Live workflow timeline, completed/current/waiting nodes, background-work message,
cost used, and cancel rules.

H04 — Scheduled Detail
Thumbnail, product, creator, publish time, settings, edit schedule, cancel schedule.

H05 — Published Detail
Video preview, pinned product, publish time, TikTok permalink, lifecycle,
duplicate and create-variant actions.

H06 — Failed Detail / Token Expired
Explain that video, caption, product, and schedule remain safe. Show reconnect and resume.

H06b — Failed Detail / Product Unavailable
Show affected product and replace-product flow while preserving content.

H06c — Failed Detail / Video Rejected
Human-readable reason, expandable technical details, edit video, and retry.

H06d — Publish Status Unknown
Explain that the system is checking TikTok before retrying to prevent duplicate posting.

H06e — Cancel Confirmation
Explain what will stop, what assets remain, and destructive-action confirmation.

Connect Library filters and cards to every detail state and recovery action.
```

---

## Prompt 6 — Profile and Final Consistency Pass

```text
Create Batch 6 as 5 new separate 390 × 844 mobile artboards. Preserve all screens.

I01 — Profile
User identity, TikTok Creator summary, plan/credits, preferences, help, and account settings.

I02 — TikTok Connection
Avatar, @username, creator type, permissions, token health, last sync,
reconnect and disconnect actions.

I03 — Notification Settings
Controls for AI ready, approval needed, upcoming schedule, publish success,
failure, product unavailable, and connection expired.

I04 — Appearance
System/Light/Dark, Reduced Motion, text scaling preview.

I05 — Account & Legal
Email, password, language, timezone, privacy policy, terms, data controls, and sign out.

After creating these screens, perform a consistency pass across every artboard:

- Keep all screens; do not merge or delete any.
- Normalize bottom navigation, headers, spacing, typography, buttons, cards, and sheets.
- Ensure every content item displays a thumbnail and linked product.
- Ensure every asynchronous state says what is happening and whether the app may be closed.
- Ensure every error says what remains safe and provides a recovery action.
- Ensure Thai text fits naturally at 390px width.
- Add light/dark tokens but keep the primary artboards in one consistent theme.
- Add prototype links for the four primary scenarios.
```

---

## Final Audit Prompt

```text
Audit the RelayContent canvas against Batches 1–6.

Return a checklist containing every requested screen ID and mark it Complete or Missing.
Then create each missing screen as a separate 390 × 844 artboard.

Do not replace, merge, summarize, or delete completed screens.
Do not generate another moodboard.

Verify these four clickable end-to-end prototype flows:

1. New user → Connect TikTok → Eligibility → Showcase → Home
2. Product → AI Brief → Idea → Generate → Review → Basket → Schedule → Accepted
3. Upload video → Product → Composer → Post now → Published
4. Token expires → Notification → Failed detail → Reconnect → Resume job
```

