// Package crypto เข้ารหัส token ของแพลตฟอร์ม (TikTok / Meta / OpenAI key) ก่อนเก็บลง DB
//
// ทำไมต้องมี: เราถือ token ของบัญชี TikTok ลูกค้า ถ้าฐานข้อมูลรั่ว = ธุรกิจลูกค้าโดนยึดบัญชี
// ห้ามเก็บเป็น plain text เด็ดขาด
//
// ออกแบบให้รองรับ key rotation ตั้งแต่แรก: แต่ละ row เก็บ key_version ไว้
// ทำให้หมุนคีย์ได้โดยไม่ต้อง re-encrypt ทั้งฐานพร้อมกันในคราวเดียว
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
)

const KeySize = 32 // AES-256

var (
	ErrNoKeys           = errors.New("crypto: ไม่มี encryption key ที่ใช้งานได้")
	ErrUnknownKeyVer    = errors.New("crypto: ไม่รู้จัก key version นี้")
	ErrMalformedKeySpec = errors.New("crypto: รูปแบบ ENCRYPTION_KEYS ไม่ถูกต้อง")
)

// Vault ถือคีย์ทั้งหมดที่ระบบรู้จัก และเลือกคีย์ล่าสุดสำหรับเข้ารหัสของใหม่
type Vault struct {
	aeads      map[int]cipher.AEAD
	currentVer int
}

// NewVault รับ spec รูปแบบ "1:<base64 32 bytes>,2:<base64 32 bytes>"
// version ที่มีเลขสูงสุดจะถูกใช้เข้ารหัสของใหม่ ที่เหลือเก็บไว้ถอดรหัสของเก่า
func NewVault(spec string) (*Vault, error) {
	v := &Vault{aeads: make(map[int]cipher.AEAD)}

	for _, part := range strings.Split(spec, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}

		verStr, keyB64, ok := strings.Cut(part, ":")
		if !ok {
			return nil, fmt.Errorf("%w: ต้องเป็น <version>:<base64key>", ErrMalformedKeySpec)
		}

		ver, err := strconv.Atoi(strings.TrimSpace(verStr))
		if err != nil || ver < 1 {
			return nil, fmt.Errorf("%w: version ต้องเป็นจำนวนเต็มบวก ได้ %q", ErrMalformedKeySpec, verStr)
		}
		if _, dup := v.aeads[ver]; dup {
			return nil, fmt.Errorf("%w: key version %d ซ้ำ", ErrMalformedKeySpec, ver)
		}

		key, err := base64.StdEncoding.DecodeString(strings.TrimSpace(keyB64))
		if err != nil {
			return nil, fmt.Errorf("%w: ถอด base64 ของ version %d ไม่ได้: %v", ErrMalformedKeySpec, ver, err)
		}
		if len(key) != KeySize {
			return nil, fmt.Errorf("%w: key version %d ต้องยาว %d ไบต์ ได้ %d",
				ErrMalformedKeySpec, ver, KeySize, len(key))
		}

		block, err := aes.NewCipher(key)
		if err != nil {
			return nil, fmt.Errorf("crypto: สร้าง cipher ของ version %d ไม่ได้: %w", ver, err)
		}
		aead, err := cipher.NewGCM(block)
		if err != nil {
			return nil, fmt.Errorf("crypto: สร้าง GCM ของ version %d ไม่ได้: %w", ver, err)
		}

		v.aeads[ver] = aead
		if ver > v.currentVer {
			v.currentVer = ver
		}
	}

	if len(v.aeads) == 0 {
		return nil, ErrNoKeys
	}
	return v, nil
}

// CurrentVersion คืน key version ที่ใช้เข้ารหัสของใหม่
func (v *Vault) CurrentVersion() int { return v.currentVer }

// Encrypt เข้ารหัสด้วยคีย์ล่าสุด คืน ciphertext, nonce และ key version ที่ใช้
// เก็บทั้งสามค่าลง DB (ดูคอลัมน์ *_ct, *_nonce, key_version)
func (v *Vault) Encrypt(plaintext []byte) (ciphertext, nonce []byte, keyVersion int, err error) {
	aead, ok := v.aeads[v.currentVer]
	if !ok {
		return nil, nil, 0, ErrNoKeys
	}

	nonce = make([]byte, aead.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, nil, 0, fmt.Errorf("crypto: สุ่ม nonce ไม่ได้: %w", err)
	}

	ciphertext = aead.Seal(nil, nonce, plaintext, nil)
	return ciphertext, nonce, v.currentVer, nil
}

// Decrypt ถอดรหัสด้วยคีย์ตาม version ที่บันทึกไว้
func (v *Vault) Decrypt(ciphertext, nonce []byte, keyVersion int) ([]byte, error) {
	aead, ok := v.aeads[keyVersion]
	if !ok {
		return nil, fmt.Errorf("%w: %d (ตรวจว่า ENCRYPTION_KEYS ยังมีคีย์เก่าอยู่หรือไม่)",
			ErrUnknownKeyVer, keyVersion)
	}
	if len(nonce) != aead.NonceSize() {
		return nil, fmt.Errorf("crypto: nonce ยาว %d ไบต์ แต่ต้องการ %d", len(nonce), aead.NonceSize())
	}

	plaintext, err := aead.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		// ไม่คืนรายละเอียดออกไป เพราะ error ของ GCM บอกใบ้ได้
		return nil, errors.New("crypto: ถอดรหัสไม่สำเร็จ (คีย์ผิดหรือข้อมูลถูกแก้ไข)")
	}
	return plaintext, nil
}

func (v *Vault) EncryptString(s string) (ciphertext, nonce []byte, keyVersion int, err error) {
	return v.Encrypt([]byte(s))
}

func (v *Vault) DecryptString(ciphertext, nonce []byte, keyVersion int) (string, error) {
	b, err := v.Decrypt(ciphertext, nonce, keyVersion)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// GenerateKey สร้างคีย์ใหม่แบบ base64 พร้อมใส่ ENCRYPTION_KEYS
// ใช้ผ่าน: go run ./cmd/genkey
func GenerateKey() (string, error) {
	key := make([]byte, KeySize)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(key), nil
}
