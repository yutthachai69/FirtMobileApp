package database

import (
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"strings"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
)

// Migrate รัน migration ทั้งหมดที่ยังไม่ได้รัน
//
// ใช้ golang-migrate เพราะจัดการ dirty state ได้ (migration ตายกลางคัน)
// ซึ่งเป็นเรื่องที่ migrator เขียนเองมักพลาด และเจ็บตอน production
func Migrate(databaseURL string, files fs.FS, log *slog.Logger) error {
	src, err := iofs.New(files, ".")
	if err != nil {
		return fmt.Errorf("migrate: อ่านไฟล์ migration ไม่ได้: %w", err)
	}

	m, err := migrate.NewWithSourceInstance("iofs", src, toPgxURL(databaseURL))
	if err != nil {
		return fmt.Errorf("migrate: เชื่อมต่อไม่ได้: %w", err)
	}
	defer func() {
		srcErr, dbErr := m.Close()
		if srcErr != nil {
			log.Warn("ปิด migration source ไม่สำเร็จ", "err", srcErr)
		}
		if dbErr != nil {
			log.Warn("ปิด migration db ไม่สำเร็จ", "err", dbErr)
		}
	}()

	before, dirty, _ := m.Version()
	if dirty {
		return fmt.Errorf("migrate: schema อยู่ในสถานะ dirty ที่ version %d "+
			"— ต้องแก้ด้วยมือก่อน (migrate force <version>)", before)
	}

	switch err := m.Up(); {
	case errors.Is(err, migrate.ErrNoChange):
		log.Info("schema เป็นเวอร์ชันล่าสุดแล้ว", "version", before)
	case err != nil:
		return fmt.Errorf("migrate: รันไม่สำเร็จ: %w", err)
	default:
		after, _, _ := m.Version()
		log.Info("รัน migration สำเร็จ", "from", before, "to", after)
	}
	return nil
}

// toPgxURL เปลี่ยน scheme ให้ตรงกับ driver ที่ golang-migrate ลงทะเบียนไว้ (pgx5)
func toPgxURL(url string) string {
	for _, prefix := range []string{"postgresql://", "postgres://"} {
		if strings.HasPrefix(url, prefix) {
			return "pgx5://" + strings.TrimPrefix(url, prefix)
		}
	}
	return url
}
