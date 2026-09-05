# Google Login และบัญชีกลาง

Backend รองรับ Google ID token ผ่าน OIDC โดยตรวจลายเซ็น RS256, issuer,
audience, expiration, subject และ email_verified ก่อนออก access/refresh token ของ RelayContent
ไลบรารีเก็บ cache public keys และดึงกุญแจใหม่เมื่อ Google หมุนกุญแจ

## ตั้งค่า

1. สร้าง OAuth client ใน Google Cloud สำหรับแอปนี้ และตั้ง consent screen / test users
2. ใส่ Web OAuth client ID ใน `GOOGLE_CLIENT_ID` ของ backend
3. ตอนทำ Android/iOS ให้ตั้ง client ตาม platform และกำหนด server client ID เป็นค่าเดียวกับ backend
4. แอปใช้ Google Sign-In SDK ขอ ID token แล้วส่งให้ backend ผ่าน HTTPS

ไม่ต้องส่ง Google password หรือ client secret ให้แอปหรือ API นี้
หากไม่ตั้ง GOOGLE_CLIENT_ID การล็อกอิน Google จะตอบ 503 PROVIDER_NOT_CONFIGURED
ส่วน email/password ยังทำงานตามเดิม

## เข้าแอป

`POST /v1/auth/google`

```json
{"id_token":"<Google ID token>"}
```

ตอบ 200 `{ "user": {...}, "tokens": { "access_token": "...", "refresh_token": "...", "expires_at": "...", "token_type": "Bearer" } }`
ใช้ token ของ RelayContent กับ API และ refresh/logout แบบเดิม
ห้าม log หรือส่ง ID token ผ่าน URL

ผู้ใช้ใหม่จะได้บัญชี users หนึ่งรายการ และ auth_identities หนึ่งรายการ
บัญชี Google-only ไม่มีรหัสผ่านสำหรับเข้าแอป
การเข้าอีกอุปกรณ์ด้วย Google เดิมจะได้ user ID เดิม แม้อีเมล Google เปลี่ยน

## เชื่อมกับบัญชีอีเมลเดิม

หากอีเมลซ้ำ ระบบตอบ 409 ACCOUNT_LINK_REQUIRED โดยไม่รวมบัญชีให้อัตโนมัติ
ให้เข้าแอปด้วยอีเมลและรหัสผ่านเดิม จากนั้นเรียก:

`POST /v1/auth/google/link` พร้อม `Authorization: Bearer <RelayContent access token>`

```json
{"id_token":"<Google ID token>","password":"<current account password>"}
```

ตอบ 200 `{ "linked": true }` และใช้ Google เข้า user ID เดิมได้ในครั้งต่อไป
ต้องยืนยันรหัสผ่านเดิมทุกครั้งที่เชื่อม จึงไม่พึ่ง access token อย่างเดียว
Google หนึ่งบัญชีเชื่อมได้กับผู้ใช้หนึ่งราย และผู้ใช้หนึ่งรายเชื่อม Google ได้หนึ่งบัญชี
ยังไม่มีฟังก์ชันถอดการเชื่อม/สลับ Google/รวมบัญชีสองราย

## ขอบเขตที่ทำแล้ว

- Migration 000002 เพิ่ม auth_identities โดยคง users.id เป็นบัญชีกลาง
- ล็อกอิน Google และเชื่อมเข้าบัญชีอีเมลเดิม พร้อม rate limit
- Unit tests ตรวจ token หมดอายุ, ลายเซ็นปลอม, issuer/audience ผิด และ claims ที่ขาด
- PostgreSQL integration test ตรวจสร้างบัญชี, login ซ้ำ, email เปลี่ยน, email ชน,
  การเชื่อมแบบยืนยันตัวตน, ป้องกันแย่ง identity และ migration up/down ใน schema ชั่วคราว
- go test / go vet / go build ผ่าน

ยังไม่ได้ทดสอบบัญชี Google จริง เพราะยังไม่มี client ID และแอปมือถือ
ยังไม่ได้ทำ Apple Login, หน้าจอ login และการซิงค์ข้อมูลแบบ realtime/offline
การเชื่อม TikTok เพื่อโพสต์เป็นคนละสิทธิ์กับการเข้าแอป

ทดสอบ PostgreSQL เพิ่มโดยตั้ง TEST_DATABASE_URL แล้วรัน:

```powershell
go test ./internal/user -run TestIdentityRepository -v -count=1
```

แหล่งอ้างอิง:
- https://developers.google.com/identity/sign-in/web/backend-auth
- https://pkg.go.dev/github.com/coreos/go-oidc/v3/oidc
