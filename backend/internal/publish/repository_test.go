package publish

import (
	"context"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"relaycontent/internal/publisher"
)

// เทสชุดนี้ยิงกับ Postgres จริง เพราะสิ่งที่ต้องพิสูจน์คือ **ตัว SQL เอง**
// (FOR UPDATE SKIP LOCKED, index ที่ใช้, การนับวันตาม timezone)
// การ mock ฐานข้อมูลจะทดสอบแค่โค้ด Go แต่ไม่ได้ทดสอบสิ่งที่พังจริง
//
//	TEST_DATABASE_URL=postgres://... go test ./internal/publish/

func testDB(t *testing.T) *pgxpool.Pool {
	t.Helper()

	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("ข้ามเทส: ไม่ได้ตั้ง TEST_DATABASE_URL")
	}

	pool, err := pgxpool.New(context.Background(), url)
	if err != nil {
		t.Fatalf("ต่อฐานข้อมูลไม่ได้: %v", err)
	}
	t.Cleanup(pool.Close)

	if err := pool.Ping(context.Background()); err != nil {
		t.Fatalf("ping ไม่ผ่าน: %v", err)
	}
	return pool
}

// fixture สร้าง user + content + connection ที่จำเป็นต่อการมี publish_job
func fixture(t *testing.T, pool *pgxpool.Pool) (userID, contentID, connID string) {
	t.Helper()
	ctx := context.Background()
	email := "pubtest-" + uuid.NewString() + "@test.local"

	err := pool.QueryRow(ctx,
		`INSERT INTO users (email, password_hash, timezone)
		 VALUES ($1,'x','Asia/Bangkok') RETURNING id`, email).Scan(&userID)
	if err != nil {
		t.Fatalf("สร้าง user ไม่สำเร็จ: %v", err)
	}

	if err := pool.QueryRow(ctx,
		`INSERT INTO contents (user_id, caption, status)
		 VALUES ($1,'ทดสอบ','ready') RETURNING id`, userID).Scan(&contentID); err != nil {
		t.Fatalf("สร้าง content ไม่สำเร็จ: %v", err)
	}

	if err := pool.QueryRow(ctx,
		`INSERT INTO platform_connections
		     (user_id, provider, kind, external_account_id, display_name, key_version)
		 VALUES ($1,'tiktok','publisher',$2,'@tester',1) RETURNING id`,
		userID, uuid.NewString()).Scan(&connID); err != nil {
		t.Fatalf("สร้าง connection ไม่สำเร็จ: %v", err)
	}

	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID)
	})
	return userID, contentID, connID
}

func newJob(t *testing.T, r *Repository, userID, contentID, connID string, at time.Time) *Job {
	t.Helper()

	job, err := r.Create(context.Background(), CreateParams{
		UserID:         userID,
		ContentID:      contentID,
		ConnectionID:   connID,
		Platform:       publisher.PlatformTikTok,
		Options:        publisher.Options{"privacy_level": "SELF_ONLY"},
		ScheduledAt:    at,
		IdempotencyKey: uuid.NewString(),
	})
	if err != nil {
		t.Fatalf("สร้างงานไม่สำเร็จ: %v", err)
	}
	return job
}

func TestCreateRejectsDuplicateIdempotencyKey(t *testing.T) {
	pool := testDB(t)
	r := NewRepository(pool)
	userID, contentID, connID := fixture(t, pool)

	key := uuid.NewString()
	params := CreateParams{
		UserID: userID, ContentID: contentID, ConnectionID: connID,
		Platform: publisher.PlatformTikTok, ScheduledAt: time.Now(),
		IdempotencyKey: key,
	}

	if _, err := r.Create(context.Background(), params); err != nil {
		t.Fatalf("ครั้งแรกต้องสำเร็จ: %v", err)
	}

	// นี่คือสิ่งที่กันโพสต์ซ้ำบน TikTok ซึ่งกู้คืนไม่ได้
	if _, err := r.Create(context.Background(), params); err != ErrDuplicate {
		t.Fatalf("ครั้งที่สองต้องได้ ErrDuplicate ได้ %v", err)
	}
}

func TestClaimDueOnlyPicksJobsThatAreReady(t *testing.T) {
	pool := testDB(t)
	r := NewRepository(pool)
	userID, contentID, connID := fixture(t, pool)
	ctx := context.Background()

	past := newJob(t, r, userID, contentID, connID, time.Now().Add(-time.Minute))
	future := newJob(t, r, userID, contentID, connID, time.Now().Add(time.Hour))

	ids, err := r.ClaimDue(ctx, "w1", 50)
	if err != nil {
		t.Fatalf("ClaimDue: %v", err)
	}

	claimed := make(map[string]bool, len(ids))
	for _, id := range ids {
		claimed[id] = true
	}

	if !claimed[past.ID] {
		t.Fatal("งานที่ถึงเวลาแล้วต้องถูกหยิบ")
	}
	if claimed[future.ID] {
		t.Fatal("งานที่ยังไม่ถึงเวลาต้องไม่ถูกหยิบ")
	}

	// หยิบแล้วต้องกลายเป็น queued และถูกล็อกไว้
	got, _ := r.GetForWorker(ctx, past.ID)
	if got.Status != StatusQueued {
		t.Fatalf("สถานะหลังหยิบ = %s want queued", got.Status)
	}
}

// นี่คือหัวใจของการ scale worker หลายตัว: งานหนึ่งต้องถูกหยิบโดย worker เดียวเท่านั้น
func TestClaimDueNeverHandsSameJobToTwoWorkers(t *testing.T) {
	pool := testDB(t)
	r := NewRepository(pool)
	userID, contentID, connID := fixture(t, pool)
	ctx := context.Background()

	const jobCount = 12
	mine := make(map[string]bool, jobCount)
	for range jobCount {
		mine[newJob(t, r, userID, contentID, connID, time.Now().Add(-time.Minute)).ID] = true
	}

	const workers = 4
	var (
		mu      sync.Mutex
		seen    = map[string]string{} // job id -> worker ที่หยิบไป
		wg      sync.WaitGroup
		dupErrs []string
	)

	for range workers {
		wg.Add(1)
		go func(name string) {
			defer wg.Done()

			ids, err := r.ClaimDue(ctx, name, jobCount)
			if err != nil {
				return
			}

			mu.Lock()
			defer mu.Unlock()
			for _, id := range ids {
				if !mine[id] {
					continue // งานของเทสอื่นที่รันคู่กัน
				}
				if prev, dup := seen[id]; dup {
					dupErrs = append(dupErrs, id+" ถูกหยิบโดย "+prev+" และ "+name)
				}
				seen[id] = name
			}
		}(uuid.NewString()[:8])
	}
	wg.Wait()

	if len(dupErrs) > 0 {
		t.Fatalf("มีงานถูกหยิบซ้ำ: %v", dupErrs)
	}
	if len(seen) != jobCount {
		t.Fatalf("หยิบได้ %d งาน จากทั้งหมด %d", len(seen), jobCount)
	}
}

// ถ้า ClaimDue ไม่ดู next_run_at งานที่เพิ่งล้มเหลวจะถูกหยิบซ้ำทุกรอบ ticker
// เท่ากับยิงซ้ำใส่ปลายทางทุก 10 วินาที จนโดน rate limit
func TestClaimDueRespectsRetryBackoff(t *testing.T) {
	pool := testDB(t)
	r := NewRepository(pool)
	userID, contentID, connID := fixture(t, pool)
	ctx := context.Background()

	job := newJob(t, r, userID, contentID, connID, time.Now().Add(-time.Minute))

	// จำลองว่าเพิ่งล้มเหลว แล้วตั้งเวลาลองใหม่อีก 5 นาที
	if err := r.Reschedule(ctx, job.ID, time.Now().Add(5*time.Minute),
		map[string]any{"code": "RETRYING"}); err != nil {
		t.Fatalf("Reschedule: %v", err)
	}

	ids, err := r.ClaimDue(ctx, "w1", 50)
	if err != nil {
		t.Fatalf("ClaimDue: %v", err)
	}
	if contains(ids, job.ID) {
		t.Fatal("งานที่รอ backoff อยู่ต้องยังไม่ถูกหยิบ")
	}

	// พอถึงเวลาแล้วต้องถูกหยิบ
	if _, err := pool.Exec(ctx,
		`UPDATE publish_jobs SET next_run_at = now() - interval '1 second' WHERE id = $1`,
		job.ID); err != nil {
		t.Fatalf("เลื่อน next_run_at ไม่สำเร็จ: %v", err)
	}

	ids, _ = r.ClaimDue(ctx, "w1", 50)
	if !contains(ids, job.ID) {
		t.Fatal("ถึงเวลา retry แล้วต้องถูกหยิบ ไม่งั้นงานจะค้างตลอดไป")
	}
}

func TestReleaseStaleUnlocksAbandonedJobs(t *testing.T) {
	pool := testDB(t)
	r := NewRepository(pool)
	userID, contentID, connID := fixture(t, pool)
	ctx := context.Background()

	job := newJob(t, r, userID, contentID, connID, time.Now().Add(-time.Minute))
	if _, err := r.ClaimDue(ctx, "dead-worker", 50); err != nil {
		t.Fatalf("ClaimDue: %v", err)
	}

	// จำลองว่า worker ตายไปนานแล้ว
	if _, err := pool.Exec(ctx,
		`UPDATE publish_jobs SET locked_at = now() - interval '1 hour' WHERE id = $1`,
		job.ID); err != nil {
		t.Fatalf("ตั้ง locked_at ไม่สำเร็จ: %v", err)
	}

	if _, err := r.ReleaseStale(ctx, 10*time.Minute); err != nil {
		t.Fatalf("ReleaseStale: %v", err)
	}

	got, _ := r.GetForWorker(ctx, job.ID)
	if got.Status != StatusScheduled {
		t.Fatalf("งานที่ถูกทิ้งต้องกลับเป็น scheduled ได้ %s", got.Status)
	}

	// และต้องถูกหยิบไปทำใหม่ได้
	ids, _ := r.ClaimDue(ctx, "w2", 50)
	found := false
	for _, id := range ids {
		if id == job.ID {
			found = true
		}
	}
	if !found {
		t.Fatal("งานที่ปลดล็อกแล้วต้องถูกหยิบไปทำใหม่ได้")
	}
}

func TestCancelOnlyBeforeHandoff(t *testing.T) {
	pool := testDB(t)
	r := NewRepository(pool)
	userID, contentID, connID := fixture(t, pool)
	ctx := context.Background()

	job := newJob(t, r, userID, contentID, connID, time.Now().Add(time.Hour))
	if err := r.Cancel(ctx, userID, job.ID); err != nil {
		t.Fatalf("ยกเลิกงานที่ยังไม่ส่งต้องได้: %v", err)
	}

	// ส่งไปแล้วยกเลิกไม่ได้ เพราะปลายทางทำงานไปแล้ว
	sent := newJob(t, r, userID, contentID, connID, time.Now().Add(time.Hour))
	if err := r.MarkProcessing(ctx, sent.ID, "pub_123"); err != nil {
		t.Fatalf("MarkProcessing: %v", err)
	}
	if err := r.Cancel(ctx, userID, sent.ID); err != ErrNotFound {
		t.Fatalf("งานที่ส่งไปแล้วต้องยกเลิกไม่ได้ ได้ %v", err)
	}
}

func TestMarkProcessingReleasesLockForPoller(t *testing.T) {
	pool := testDB(t)
	r := NewRepository(pool)
	userID, contentID, connID := fixture(t, pool)
	ctx := context.Background()

	job := newJob(t, r, userID, contentID, connID, time.Now().Add(-time.Minute))
	if _, err := r.ClaimDue(ctx, "w1", 50); err != nil {
		t.Fatalf("ClaimDue: %v", err)
	}
	if err := r.MarkProcessing(ctx, job.ID, "pub_abc"); err != nil {
		t.Fatalf("MarkProcessing: %v", err)
	}

	// ตอนนี้ยังไม่ถึงเวลา poll (next_run_at = +10s)
	if ids, _ := r.ClaimPollable(ctx, "w1", 50); contains(ids, job.ID) {
		t.Fatal("ยังไม่ถึงเวลา poll ต้องยังไม่ถูกหยิบ")
	}

	if _, err := pool.Exec(ctx,
		`UPDATE publish_jobs SET next_run_at = now() - interval '1 second' WHERE id = $1`,
		job.ID); err != nil {
		t.Fatalf("เลื่อน next_run_at ไม่สำเร็จ: %v", err)
	}

	ids, err := r.ClaimPollable(ctx, "w1", 50)
	if err != nil {
		t.Fatalf("ClaimPollable: %v", err)
	}
	if !contains(ids, job.ID) {
		t.Fatal("ถึงเวลา poll แล้วต้องถูกหยิบ — ถ้าไม่ถูกหยิบ งานจะค้าง processing ตลอดไป")
	}
}

func TestCountTodayUsesUserTimezone(t *testing.T) {
	pool := testDB(t)
	r := NewRepository(pool)
	userID, contentID, connID := fixture(t, pool)
	ctx := context.Background()

	newJob(t, r, userID, contentID, connID, time.Now())

	n, err := r.CountToday(ctx, connID, "Asia/Bangkok")
	if err != nil {
		t.Fatalf("CountToday: %v", err)
	}
	if n != 1 {
		t.Fatalf("นับได้ %d want 1", n)
	}

	// งานที่ยกเลิกแล้วต้องไม่กินโควตา
	cancelled := newJob(t, r, userID, contentID, connID, time.Now())
	if err := r.Cancel(ctx, userID, cancelled.ID); err != nil {
		t.Fatalf("Cancel: %v", err)
	}

	n, _ = r.CountToday(ctx, connID, "Asia/Bangkok")
	if n != 1 {
		t.Fatalf("งานที่ยกเลิกแล้วไม่ควรถูกนับ — ได้ %d want 1", n)
	}
}

func contains(ids []string, want string) bool {
	for _, id := range ids {
		if id == want {
			return true
		}
	}
	return false
}
