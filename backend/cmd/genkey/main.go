// Command genkey สร้าง encryption key ใหม่สำหรับ ENCRYPTION_KEYS
//
//	go run ./cmd/genkey          → คีย์ใหม่ 1 อัน
//	go run ./cmd/genkey -v 2     → พิมพ์ในรูปแบบพร้อมวางต่อท้าย
//
// การหมุนคีย์: เพิ่ม version ใหม่ต่อท้ายโดย "ห้ามลบของเก่า"
// เพราะแถวที่เข้ารหัสด้วยคีย์เก่ายังต้องถอดได้อยู่
package main

import (
	"flag"
	"fmt"
	"os"

	"relaycontent/pkg/crypto"
)

func main() {
	version := flag.Int("v", 1, "key version")
	flag.Parse()

	key, err := crypto.GenerateKey()
	if err != nil {
		fmt.Fprintf(os.Stderr, "สร้างคีย์ไม่สำเร็จ: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("%d:%s\n", *version, key)
}
