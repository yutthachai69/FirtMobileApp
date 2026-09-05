package crypto

import (
	"bytes"
	"testing"
)

func mustKey(t *testing.T) string {
	t.Helper()
	k, err := GenerateKey()
	if err != nil {
		t.Fatalf("GenerateKey: %v", err)
	}
	return k
}

func mustVault(t *testing.T, spec string) *Vault {
	t.Helper()
	v, err := NewVault(spec)
	if err != nil {
		t.Fatalf("NewVault(%q): %v", spec, err)
	}
	return v
}

func TestEncryptDecryptRoundTrip(t *testing.T) {
	v := mustVault(t, "1:"+mustKey(t))
	secret := []byte("act.tiktok-access-token-ตัวอย่าง")

	ct, nonce, ver, err := v.Encrypt(secret)
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}
	if ver != 1 {
		t.Fatalf("key version = %d, want 1", ver)
	}
	if bytes.Contains(ct, secret) {
		t.Fatal("ciphertext ยังมี plaintext อยู่ข้างใน")
	}

	got, err := v.Decrypt(ct, nonce, ver)
	if err != nil {
		t.Fatalf("Decrypt: %v", err)
	}
	if !bytes.Equal(got, secret) {
		t.Fatalf("ถอดได้ %q want %q", got, secret)
	}
}

// nonce ต้องไม่ซ้ำ ไม่งั้น GCM เสียความปลอดภัยทันที
func TestEncryptUsesFreshNonce(t *testing.T) {
	v := mustVault(t, "1:"+mustKey(t))

	_, nonce1, _, _ := v.Encrypt([]byte("same"))
	_, nonce2, _, _ := v.Encrypt([]byte("same"))

	if bytes.Equal(nonce1, nonce2) {
		t.Fatal("เข้ารหัสสองครั้งได้ nonce เดียวกัน")
	}
}

// นี่คือพฤติกรรมที่ทำให้หมุนคีย์ได้: เข้ารหัสของใหม่ด้วยคีย์ล่าสุด แต่ยังถอดของเก่าได้
func TestKeyRotation(t *testing.T) {
	key1, key2 := mustKey(t), mustKey(t)

	// ก่อนหมุน — มีแค่ version 1
	v1 := mustVault(t, "1:"+key1)
	oldCT, oldNonce, oldVer, err := v1.Encrypt([]byte("token เก่า"))
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}

	// หลังหมุน — เพิ่ม version 2 โดยยังเก็บ version 1 ไว้
	v2 := mustVault(t, "1:"+key1+",2:"+key2)

	if v2.CurrentVersion() != 2 {
		t.Fatalf("CurrentVersion = %d, want 2", v2.CurrentVersion())
	}

	_, _, newVer, err := v2.Encrypt([]byte("token ใหม่"))
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}
	if newVer != 2 {
		t.Fatalf("ของใหม่ใช้ key version %d, want 2", newVer)
	}

	got, err := v2.Decrypt(oldCT, oldNonce, oldVer)
	if err != nil {
		t.Fatalf("ถอดของเก่าไม่ได้หลังหมุนคีย์: %v", err)
	}
	if string(got) != "token เก่า" {
		t.Fatalf("ถอดได้ %q", got)
	}
}

// ถ้าลบคีย์เก่าออกจาก ENCRYPTION_KEYS แถวเก่าจะถอดไม่ได้อีกเลย
func TestDecryptFailsWhenOldKeyRemoved(t *testing.T) {
	key1 := mustKey(t)
	v1 := mustVault(t, "1:"+key1)
	ct, nonce, ver, _ := v1.Encrypt([]byte("token เก่า"))

	v2 := mustVault(t, "2:"+mustKey(t)) // ลบ version 1 ทิ้ง

	if _, err := v2.Decrypt(ct, nonce, ver); err == nil {
		t.Fatal("คาดว่าจะ error เมื่อไม่มีคีย์เวอร์ชันเดิมแล้ว")
	}
}

func TestDecryptWithUnknownVersion(t *testing.T) {
	v := mustVault(t, "1:"+mustKey(t))
	ct, nonce, _, _ := v.Encrypt([]byte("x"))

	if _, err := v.Decrypt(ct, nonce, 99); err == nil {
		t.Fatal("คาดว่าจะ error เมื่อ key version ไม่รู้จัก")
	}
}

func TestDecryptTamperedCiphertext(t *testing.T) {
	v := mustVault(t, "1:"+mustKey(t))
	ct, nonce, ver, _ := v.Encrypt([]byte("token ที่ต้องไม่ถูกแก้"))

	ct[0] ^= 0xFF // แก้ไบต์เดียว GCM ต้องจับได้

	if _, err := v.Decrypt(ct, nonce, ver); err == nil {
		t.Fatal("GCM ต้องปฏิเสธ ciphertext ที่ถูกแก้ไข")
	}
}

func TestNewVaultRejectsBadSpec(t *testing.T) {
	cases := map[string]string{
		"ว่างเปล่า":         "",
		"ไม่มี version":     "AAAA",
		"version ไม่ใช่เลข":  "abc:" + "AAAA",
		"version เป็นศูนย์": "0:AAAA",
		"base64 พัง":        "1:!!!not-base64!!!",
		"คีย์สั้นเกินไป":      "1:AAAAAAAAAAAAAAAAAAAAAAAAAAAA",
	}

	for name, spec := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := NewVault(spec); err == nil {
				t.Fatalf("คาดว่าจะ error สำหรับ spec %q", spec)
			}
		})
	}
}

func TestNewVaultRejectsDuplicateVersion(t *testing.T) {
	spec := "1:" + mustKey(t) + ",1:" + mustKey(t)
	if _, err := NewVault(spec); err == nil {
		t.Fatal("คาดว่าจะ error เมื่อ key version ซ้ำ")
	}
}

func TestStringHelpers(t *testing.T) {
	v := mustVault(t, "1:"+mustKey(t))

	ct, nonce, ver, err := v.EncryptString("sk-proj-ตัวอย่าง")
	if err != nil {
		t.Fatalf("EncryptString: %v", err)
	}

	got, err := v.DecryptString(ct, nonce, ver)
	if err != nil {
		t.Fatalf("DecryptString: %v", err)
	}
	if got != "sk-proj-ตัวอย่าง" {
		t.Fatalf("ได้ %q", got)
	}
}
