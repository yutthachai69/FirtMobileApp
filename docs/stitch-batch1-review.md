# RelayContent — Stitch Batch 1 UX Review

**วันที่ตรวจ:** 7 กันยายน 2026  
**โฟลเดอร์ต้นฉบับ:** `stitch_relaycontent_mobile_ux_design/`  
**ผลตรวจรอบแรก:** ผ่านด้านทิศทางภาพ แต่ต้องแก้ UX และข้อมูลก่อนสร้าง Batch 2  
**ผลตรวจชุดแก้ไข:** พร้อมไป Batch 2 แบบมีเงื่อนไข — ขอ export ภาพ A01 Splash เพิ่ม

## Re-review ชุดแก้ไข

ตรวจจาก `stitch_relaycontent_mobile_ux_review/` เวลา 13:16–13:17

| รายการแก้ | ผล |
|---|---|
| ทุก screen เป็น viewport 390 × 844 | ผ่านสำหรับ PNG ทั้ง 9 ไฟล์ที่ส่งมา |
| ใช้ Noto Sans Thai สำหรับข้อความไทย | ผ่าน |
| ใช้ `creator.video.write` | ผ่าน |
| ใช้ `creator.showcase.read` | ผ่าน |
| ลบ `showcase.product.bind` | ผ่าน |
| ลบ TikTok Channel ID จาก Register | ผ่าน |
| Forgot Password ใช้อีเมล RelayContent | ผ่าน |
| ลบ Partner badge และคำกล่าวอ้าง Official Partner | ผ่าน |
| Navigation เป็น หน้าหลัก/สินค้า/สร้าง/คอนเทนต์/โปรไฟล์ | ผ่านใน DESIGN.md |
| ลดศัพท์ระบบที่ไม่ช่วยผู้ใช้ | ผ่าน มี micro-label เหลือเล็กน้อยตาม visual identity |
| A01 Splash มี HTML และ PNG | **ยังขาด `screen.png`** |

### ข้อสังเกตที่ไม่ขวาง Batch 2

- A03 Login, A04 Register และ B01 Connect อ่านง่ายและใช้พื้นที่มือถือดีขึ้นชัดเจน
- B03 Eligibility ยาวกว่าหนึ่ง viewport ในเชิงเนื้อหา ซึ่งยอมรับได้หาก implementation เป็น scroll
  และ sticky action ไม่บังข้อมูลท้ายหน้า
- ข้อความเรื่อง stock และข้อมูลสินค้าให้ถือเป็น UX assumption จนกว่าจะตรวจ response จริงจาก
  Showcase API ในตลาดไทย
- คำอย่าง `SECURE AUTH`, `AUTH: READY` และ `SYNC: LIVE OAUTH` เหลือประมาณหนึ่งจุดต่อหน้า
  สามารถเก็บเป็นรายละเอียดของแบรนด์ได้ แต่ห้ามเพิ่มความหนาแน่นใน batch ถัดไป

### Gate ก่อนส่ง Batch 2

1. Export `a01_splash/screen.png` ขนาด 390 × 844 ให้ครบ
2. ใช้ Design System จากโฟลเดอร์ `stitch_relaycontent_mobile_ux_review/` เป็น source of truth
3. ส่ง Prompt 2 จาก `docs/stitch-ux-prompt-v1.md`
4. ตรวจว่า Batch 2 ได้ 9 artboards แยกกันก่อนเริ่ม Batch 3

---

## สิ่งที่ทำได้ดี

- ส่งมอบ Batch 1 ครบ 10 หน้าจอพร้อม HTML และ PNG
- Visual identity ชัดกว่าแอปเดิมมาก
- แนว Calm Commerce Control Room และ Content Relay มองเห็นได้จริง
- สี Cyan, Rose และ Mint แยก information, action และ success ได้ดี
- มี product card, commission, stock, approval และ basket อยู่ในเรื่องราวตั้งแต่ onboarding
- Connection flow มีการอธิบาย permission, eligibility และ success state
- Touch target และ safe-area โดยรวมเหมาะกับมือถือ
- หน้า Connection Success มี next action ชัด

---

## Blockers ที่ต้องแก้ก่อน Batch 2

### 1. Artboard size ไม่สม่ำเสมอ

Requirement คือ 390 × 844 แต่ไฟล์ที่ส่งมามี:

| หน้าจอ | ขนาด |
|---|---:|
| A01 | 390 × 844 |
| A02 | 390 × 844 |
| A02b | 390 × 844 |
| A02c | 706 × 1600 |
| A03 | 706 × 1600 |
| A04 | 701 × 1600 |
| A05 | 390 × 844 |
| B01 | 706 × 1600 |
| B03 | 390 × 1054 |
| B04 | 390 × 844 |

ต้องปรับทุกหน้าเป็น logical viewport 390 × 844 และใช้ scrolling ภายในเมื่อเนื้อหายาว
ห้ามเพิ่มความสูง artboard เพื่อทำให้ทุกอย่างอยู่ในภาพเดียว

### 2. ฟอนต์ไม่เหมาะกับภาษาไทย

Design system ใช้ Inter สำหรับ heading และ Be Vietnam Pro สำหรับ body ทั้งที่สองฟอนต์
ไม่ได้เป็น Thai-first typeface ภาพที่ได้จึงใช้ fallback ต่างกันระหว่างหน้า และหัวข้อภาษาไทย
มีบุคลิกคล้าย serif โดยไม่ได้ตั้งใจ

ให้เปลี่ยนเป็น:

- **Noto Sans Thai** สำหรับ UI ภาษาไทยทั้งหมด
- **Inter** เฉพาะตัวเลข, SKU, API code และ Latin metrics

กำหนด Thai line-height อย่างน้อย 1.45–1.55 และห้ามบังคับ uppercase/tracking กว้างกับข้อความไทย

### 3. ใช้ API scope ผิด

หน้า B03 แสดง `video.publish` และ `showcase.product.bind` ซึ่งไม่ใช่ scope ที่กำหนดไว้สำหรับ
TikTok Shop Creator flow นี้

UX ต้องใช้ชื่อจริง:

- `creator.video.write`
- `creator.showcase.read`

ในหน้าที่ผู้ใช้ทั่วไปเห็น ให้แปลเป็น:

- “เผยแพร่วิดีโอพร้อมตะกร้า”
- “อ่านสินค้าใน Showcase”

ชื่อ scope จริงแสดงใน expandable technical details เท่านั้น

### 4. Registration ขอ TikTok Channel ID ผิดขั้นตอน

หน้า A04 มี `TikTok Channel ID` ข้าง Display Name แต่การสมัคร RelayContent ต้องใช้เพียง:

- ชื่อที่ใช้แสดง
- อีเมล
- รหัสผ่าน
- ยอมรับ Terms และ Privacy

TikTok identity ต้องได้จาก OAuth ใน B01–B04 ห้ามให้ผู้ใช้พิมพ์เอง

### 5. Forgot Password ผูกกับ TikTok ผิดระบบ

หน้า A05 ใช้ label “อีเมลบัญชี TikTok Affiliate” ทั้งที่กำลัง reset รหัสผ่าน RelayContent
ให้แก้เป็น “อีเมลที่ใช้สมัคร RelayContent” และอธิบายว่าจะส่งลิงก์รีเซ็ตบัญชี RelayContent

### 6. แสดงสถานะ TikTok Shop Partner โดยยังไม่ได้รับสิทธิ์

หน้า A01 และ B01 ใช้ข้อความหรือ badge ที่ทำให้เข้าใจว่า RelayContent เป็น TikTok Shop Partner
อย่างเป็นทางการ ห้ามแสดงจนกว่าจะได้รับอนุมัติจริง

แก้เป็นคำกลาง:

- “เชื่อมต่อผ่าน TikTok Shop API”
- “การเชื่อมต่อแบบ OAuth”

ลบ `Partner` badge และข้อความรับรองมาตรฐานที่ยังพิสูจน์ไม่ได้

### 7. Navigation ใน Design System ผิดจาก IA

DESIGN.md กำหนด 4 tabs: Dashboard, Relay Flow, Products, Analytics แต่ Product Brief ล็อกไว้ 5 จุด:

1. หน้าหลัก
2. สินค้า
3. สร้าง — center action
4. คอนเทนต์
5. โปรไฟล์

ต้องแก้ Design System ก่อนสร้างหน้าหลักใน Batch 2

---

## Major Improvements

### ลดศัพท์เทคนิคใน consumer UI

ข้อความเช่น `NODE-TH-BKK02`, `SECURE RELAY`, `ENGINE V2.4`, `RELAY_CORE ONLINE`,
`API 200 OK` และ `Creator Node Hub` สร้างบรรยากาศได้ แต่มีจำนวนมากจนผู้ใช้รู้สึกว่ากำลัง
ใช้ developer console

เก็บศัพท์ลักษณะนี้เป็น visual micro-detail ไม่เกินหนึ่งจุดต่อหน้า และใช้ภาษาเกี่ยวกับงานจริงเป็นหลัก:

- สินค้าพร้อม
- กำลังสร้างคลิป
- รอตรวจ
- ตั้งเวลาแล้ว
- ปักตะกร้าสำเร็จ

### ลดความหนาแน่นของ Onboarding

Onboarding ควรเข้าใจได้ภายใน 3–5 วินาทีต่อหน้า ปัจจุบันมี card, badge, status และคำอธิบายหลายชั้น
ควรเหลือ:

- ภาพหลักหนึ่งภาพ
- ข้อความหลักหนึ่งประโยค
- คำอธิบายไม่เกินสองบรรทัด
- CTA เดียว

### ไม่รับปากข้อมูลที่ API ยังไม่ยืนยัน

ข้อความต่อไปนี้ต้องใช้ถ้อยคำระมัดระวังจนกว่าจะผ่าน feasibility test:

- ซิงก์ราคาและสต็อกแบบ real-time
- รายงาน conversion และยอดขายรายชั่วโมง
- Auto-dispatch พร้อมตะกร้าทุกกรณี

ใช้ “อัปเดตล่าสุด”, “ข้อมูลที่ TikTok อนุญาตให้เข้าถึง” และ “ตรวจสอบก่อนเผยแพร่” แทน

### รักษาความอ่านง่าย

- Body text บางจุดเล็กเกินไปสำหรับมือถือ
- Cyan ตัวเล็กบนพื้นดำอ่านยากเมื่อ brightness ต่ำ
- หน้า B03 ตัดหัวข้อด้วย ellipsis แม้เป็นข้อมูลสำคัญ
- Sticky CTA ต้องไม่บังเนื้อหาเมื่อเปิด keyboard หรือใช้ text scaling
- ทดสอบที่ text scale 1.0, 1.3 และ 1.5

---

## Screen-Level Notes

| Screen | สถานะ | สิ่งที่ต้องแก้ |
|---|---|---|
| A01 Splash | แก้เล็กน้อย | ลด telemetry copy, ลบ Partner claim, ทำ loading copy ให้สั้น |
| A02 Onboarding 1 | แก้เล็กน้อย | ลดข้อมูลในการ์ดและเลิกใช้คำว่า sync real-time จนยืนยัน API |
| A02b Onboarding 2 | แก้เล็กน้อย | ลด badge และรายละเอียด AI ให้ focus ที่ผู้ใช้ตรวจอนุมัติ |
| A02c Onboarding 3 | แก้หลัก | ปรับ viewport, ลด copy และเลิกใช้ภาพ dashboard desktop ในวิดีโอ |
| A03 Login | แก้หลัก | ปรับ viewport/font, ลด system jargon, อย่า prefill credential ใน final design |
| A04 Register | แก้หลัก | ลบ TikTok Channel ID, ปรับ viewport/font และ spacing |
| A05 Forgot Password | แก้หลัก | เปลี่ยนจาก TikTok email เป็น RelayContent email |
| B01 Connect | แก้หลัก | ลบ Partner claim, แก้ permission copy และลดคำรับรองที่เกินจริง |
| B03 Eligibility | แก้หลัก | แก้ scope, viewport, truncation และแยก user copy จาก technical detail |
| B04 Success | ผ่านแบบมีแก้ | ลดข้อความเทคนิคและใช้ next action ไป Showcase เป็น primary |

---

## Correction Prompt for Stitch

ส่ง Prompt นี้ในโปรเจกต์เดิมก่อนเริ่ม Batch 2:

```text
Revise Batch 1 before creating any new screens.

Preserve the Calm Commerce Control Room identity, dark palette, Content Relay concept,
and the overall screen set. Apply these corrections to all Batch 1 screens and to the
shared design system.

MANDATORY CORRECTIONS

1. Normalize every mobile artboard to exactly 390 × 844 logical pixels.
   Long content must scroll inside the viewport. Do not use 706 × 1600, 701 × 1600,
   390 × 1054, or any other canvas size.

2. Use Noto Sans Thai for every Thai heading, body, button, label, and input.
   Use Inter only for numbers, SKU values, API scope names, and Latin metrics.
   Use Thai line height between 1.45 and 1.55. Do not apply uppercase or wide tracking
   to Thai copy.

3. Correct TikTok Shop Creator scopes:
   - creator.video.write
   - creator.showcase.read
   Remove the invented scope showcase.product.bind and do not use the generic
   Content Posting scope video.publish for the Shoppable Video flow.
   Show plain Thai permission descriptions by default and place raw scope names inside
   optional technical details.

4. On A04 Register, remove TikTok Channel ID. RelayContent registration contains only:
   display name, email, password, terms/privacy, create account, and Google registration.
   TikTok identity is obtained later through OAuth and must never be typed manually.

5. On A05 Forgot Password, replace “อีเมลบัญชี TikTok Affiliate” with
   “อีเมลที่ใช้สมัคร RelayContent”. This screen resets the RelayContent password.

6. Remove all unverified official-partner claims and Partner badges.
   Replace them with neutral copy such as “เชื่อมต่อผ่าน TikTok Shop API” and
   “การเชื่อมต่อแบบ OAuth”. Do not imply that RelayContent is already an approved or
   official TikTok Shop Partner.

7. Update the global authenticated navigation to exactly five destinations:
   หน้าหลัก, สินค้า, สร้าง (prominent center action), คอนเทนต์, โปรไฟล์.
   Remove the previous Dashboard / Relay Flow / Products / Analytics four-tab model.

8. Reduce developer-console language. Terms such as NODE-TH-BKK02, SECURE RELAY,
   ENGINE V2.4, RELAY_CORE ONLINE, API 200 OK, and Creator Node Hub may appear as
   one subtle decorative micro-detail per screen at most. Primary copy must describe
   user tasks and outcomes in natural Thai.

9. Simplify each onboarding screen to one main visual, one headline, no more than two
   lines of supporting copy, and one primary action.

10. Do not promise real-time price, stock, hourly conversion, or sales analytics until
    API access is verified. Use “อัปเดตล่าสุด” and “ข้อมูลที่ได้รับอนุญาตจาก TikTok”.

11. Ensure no important heading is truncated. Support text scales 1.0, 1.3, and 1.5.
    Keep sticky actions clear of the keyboard, content, and bottom safe area.

OUTPUT

- Revise the existing 10 Batch 1 screens in place.
- Keep every screen ID and label.
- Return a checklist confirming each correction.
- Do not create Batch 2 yet.
```

---

## Gate ก่อนเริ่ม Batch 2

เริ่ม Batch 2 ได้เมื่อ:

- ทุก artboard เป็น 390 × 844
- ภาษาไทยใช้ Noto Sans Thai สม่ำเสมอ
- A04 ไม่มี TikTok Channel ID
- A05 ใช้ RelayContent email
- B03 ใช้ scope จริง
- ไม่มี official Partner claim
- Navigation ใน DESIGN.md ตรงกับ IA 5 จุด
- ไม่มีหัวข้อสำคัญถูกตัด
- Onboarding อ่านจบเร็วและมี CTA เดียว
