# สถานะงาน 2026-09-05

## อัปเดต: แอป Flutter

เพิ่ม mobile/ สำหรับ Android และ iOS แล้ว มีหน้าล็อกอินอีเมล, สมัครสมาชิก,
หน้าบัญชี, secure storage และการ restore/refresh/logout
ใช้ Flutter SDK 3.47.2 ที่ .tools/flutter (gitignored) และ Noto Sans Thai ที่ฝังในแอป
ดู [คู่มือรันและทดสอบ](../mobile/README.md)

- flutter analyze ผ่าน
- unit/widget tests 9 เคสผ่าน
- HTTP client ทดสอบกับ Backend จริง: register/login/restore/me/logout ผ่าน
- ภาพหน้าจอ 390x844 ตรวจแล้ว อยู่ที่ mobile/.preview/
- Backend ในเครื่องรัน migration ขึ้นเป็น version 2 แล้วระหว่างทดสอบ
- ยังไม่ได้ทดสอบบนมือถือจริงหรือ iOS; ปุ่ม Google ยังรอ client ID
- บัญชีทดสอบรอบ mobile: 493881b2-c7cb-4ad6-aa1a-4dc2589c818c

## อัปเดต: Google Login

เพิ่ม Google Login และการเชื่อม Google เข้าบัญชีอีเมลเดิมแล้ว ดู [วิธีตั้งค่าและ API](google-login.md)
มี migration 000002 เพิ่ม auth_identities; API จะรันเมื่อเปิด DB_AUTO_MIGRATE
Unit tests, PostgreSQL integration test ใน schema ชั่วคราว, vet และ build ผ่าน
ยังต้องตั้ง GOOGLE_CLIENT_ID และทำแอปมือถือก่อนทดสอบ Google จริง

Claude Code หยุดระหว่างทดสอบ media upload เพราะ session limit
Codex ทำต่อและทดสอบกับ PostgreSQL, Redis และ MinIO บนเครื่องแล้ว

## แก้ไขแล้ว

- PostgreSQL บนเครื่องชนพอร์ต 5432 และ 5433 จึงเปลี่ยน compose host port เป็น `${POSTGRES_PORT:-15432}` และ DATABASE_URL ใน .env/.env.example เป็น 127.0.0.1:15432 โดยใช้ volume เดิม
- StorageConfig.Enabled รองรับ R2_ENDPOINT โดยไม่บังคับ R2_ACCOUNT_ID เพื่อให้เปิด MinIO ได้
- เพิ่ม regression test สำหรับ custom endpoint และ credentials ที่ไม่ครบ

## ผลตรวจ

- API health: ok
- สมัครบัญชีทดสอบ → ขอ presigned URL → PUT PNG → complete → ดาวน์โหลด → ลบ asset: ผ่านกับ MinIO
- ยังไม่ได้ทดสอบ Cloudflare R2 หรือ TikTok จริง

## เริ่มระบบสำหรับพัฒนา

รันจาก backend:

```powershell
docker compose --profile localstorage up -d postgres redis minio minio-init
go run ./cmd/api
```

ตั้ง R2_ENDPOINT=http://localhost:9000, R2_ACCESS_KEY_ID=relaycontent,
R2_SECRET_ACCESS_KEY=relaycontent_dev และ R2_BUCKET=relaycontent-media ใน .env สำหรับ MinIO
วิธีนี้รัน API บนเครื่องเพื่อให้ endpoint localhost ใช้ได้ทั้ง API และ client

## งานถัดไปตาม README

- publisher interface + TikTok publisher
- scheduler ticker + reaper + poller
- FCM
- ทดสอบ down migration บนฐานข้อมูลทดสอบแยกต่างหาก

Workspace ยังไม่มี Git repository จึงยังไม่มี commit หรือ diff เทียบกับต้นฉบับ
