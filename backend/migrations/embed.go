// Package migrations ฝังไฟล์ .sql ไว้ในไบนารี
// ทำให้ deploy แล้วรัน migration ได้เลย ไม่ต้องก๊อปไฟล์ SQL ตามไปด้วย
package migrations

import "embed"

//go:embed *.sql
var FS embed.FS
