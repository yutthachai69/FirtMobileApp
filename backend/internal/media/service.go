package media

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"relaycontent/internal/apierror"
	"relaycontent/pkg/storage"
)

type Limits struct {
	MaxVideoBytes  int64
	MaxImageBytes  int64
	UploadURLTTL   time.Duration
	DownloadURLTTL time.Duration
}

type Service struct {
	repo    *Repository
	store   storage.Storage
	limits  Limits
	log     *slog.Logger
}

func NewService(repo *Repository, store storage.Storage, limits Limits, log *slog.Logger) *Service {
	return &Service{repo: repo, store: store, limits: limits, log: log}
}

func (s *Service) Enabled() bool { return s.store != nil }

func (s *Service) Limits() Limits { return s.limits }

type UploadRequest struct {
	UserID    string
	Kind      Kind
	Mime      string
	SizeBytes int64
	Source    Source
}

// CreateUploadURL จองที่บน storage แล้วออก presigned PUT ให้มือถือ
//
// ลำดับสำคัญ: สร้างแถวใน DB ก่อนออก URL
// ถ้าออก URL ก่อนแล้วเขียน DB พลาด จะมีไฟล์ลอยบน storage ที่ไม่มีใครรู้จัก
func (s *Service) CreateUploadURL(ctx context.Context, req UploadRequest) (*Asset, *storage.PresignedUpload, error) {
	if s.store == nil {
		return nil, nil, apierror.ErrProviderNotConfigured
	}

	if err := s.validate(req); err != nil {
		return nil, nil, err
	}

	mime := normalizeMime(req.Mime)
	ext, _ := extensionFor(req.Kind, mime)

	source := req.Source
	if source == "" {
		source = SourceUpload
	}

	// key แยกตามผู้ใช้ ทำให้ลบไฟล์ทั้งหมดของคนหนึ่งได้ง่ายตอนขอลบบัญชี (PDPA)
	key := fmt.Sprintf("users/%s/media/%s.%s", req.UserID, uuid.NewString(), ext)

	asset, err := s.repo.Create(ctx, CreateParams{
		UserID:     req.UserID,
		Kind:       req.Kind,
		Source:     source,
		StorageKey: key,
		Mime:       mime,
		SizeBytes:  req.SizeBytes,
	})
	if err != nil {
		return nil, nil, err
	}

	upload, err := s.store.PresignPut(ctx, key, mime, req.SizeBytes, s.limits.UploadURLTTL)
	if err != nil {
		// ทำเครื่องหมายว่าล้มเหลว เพื่อให้แถวนี้ไม่ค้างเป็น pending ตลอดไป
		_ = s.repo.MarkFailed(ctx, asset.ID)
		return nil, nil, err
	}
	return asset, upload, nil
}

// CompleteUpload ยืนยันว่าอัปโหลดเสร็จแล้ว
//
// **ต้อง HEAD ไปเช็คของจริงเสมอ** ห้ามเชื่อคำบอกของ client
// ไม่งั้นแอปที่ถูกดัดแปลงจะกด complete โดยไม่เคยอัปไฟล์ขึ้นมาเลย
// แล้วเราจะไปพังตอนส่ง URL ให้ TikTok ดึง ซึ่งแก้ยากกว่ามาก
func (s *Service) CompleteUpload(ctx context.Context, userID, assetID string, p CompleteParams) (*Asset, error) {
	if s.store == nil {
		return nil, apierror.ErrProviderNotConfigured
	}

	asset, err := s.repo.Get(ctx, userID, assetID)
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	if asset.Status == StatusUploaded {
		return s.withPublicURL(ctx, asset) // เรียกซ้ำถือว่าสำเร็จ
	}

	info, err := s.store.Head(ctx, asset.storageKey)
	if errors.Is(err, storage.ErrNotFound) {
		return nil, apierror.ErrValidation.
			WithDetail("reason", "ยังไม่พบไฟล์บนเซิร์ฟเวอร์ กรุณาอัปโหลดใหม่")
	}
	if err != nil {
		return nil, err
	}

	// ขนาดจริงต้องตรงกับที่จองไว้ ไม่งั้นแปลว่าอัปไม่ครบหรืออัปคนละไฟล์
	if info.Size != asset.SizeBytes {
		s.log.Warn("ขนาดไฟล์ไม่ตรงกับที่จองไว้",
			"asset_id", asset.ID, "expected", asset.SizeBytes, "actual", info.Size)
		return nil, apierror.ErrValidation.
			WithDetail("reason", "ไฟล์อัปโหลดไม่สมบูรณ์ กรุณาลองใหม่").
			WithDetail("expected_bytes", asset.SizeBytes).
			WithDetail("actual_bytes", info.Size)
	}

	p.SizeBytes = info.Size
	updated, err := s.repo.MarkUploaded(ctx, userID, assetID, p)
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	s.log.Info("อัปโหลดสำเร็จ", "asset_id", updated.ID, "bytes", updated.SizeBytes)
	return s.withPublicURL(ctx, updated)
}

// Attach ผูกไฟล์เข้ากับคอนเทนต์ ใช้ตอนสร้างคอนเทนต์จากวิดีโอที่อัปไว้แล้ว
func (s *Service) Attach(ctx context.Context, userID, assetID, contentID string) error {
	if err := s.repo.AttachToContent(ctx, userID, assetID, contentID); errors.Is(err, ErrNotFound) {
		return apierror.ErrValidation.
			WithDetail("field", "media_asset_id").
			WithDetail("reason", "ไม่พบไฟล์ หรือไฟล์ยังอัปโหลดไม่เสร็จ")
	} else if err != nil {
		return err
	}
	return nil
}

// VideoURLForContent คืน URL ชั่วคราวของวิดีโอในคอนเทนต์ ให้ปลายทางมาดึงไปโพสต์
//
// TTL ต้องนานพอให้ TikTok ดาวน์โหลดจนจบ ดูค่า DOWNLOAD_URL_TTL
// worker เรียกตอนจะโพสต์จริง ไม่ใช่ตอนสร้างงาน — URL จะได้ยังไม่หมดอายุ
func (s *Service) VideoURLForContent(ctx context.Context, contentID string) (string, error) {
	if s.store == nil {
		return "", apierror.ErrProviderNotConfigured
	}

	asset, err := s.repo.PrimaryVideo(ctx, contentID)
	if errors.Is(err, ErrNotFound) {
		return "", apierror.ErrValidation.
			WithDetail("reason", "คอนเทนต์นี้ยังไม่มีวิดีโอที่อัปโหลดเสร็จ")
	}
	if err != nil {
		return "", err
	}
	return s.store.PresignGet(ctx, asset.storageKey, s.limits.DownloadURLTTL)
}

func (s *Service) Get(ctx context.Context, userID, id string) (*Asset, error) {
	asset, err := s.repo.Get(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return s.withPublicURL(ctx, asset)
}

func (s *Service) Delete(ctx context.Context, userID, id string) error {
	asset, err := s.repo.Get(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	if err != nil {
		return err
	}

	if s.store != nil {
		if err := s.store.Delete(ctx, asset.storageKey); err != nil {
			// ลบบน storage ไม่สำเร็จก็ลบ record ต่อ ไฟล์กำพร้าเก็บกวาดทีหลังได้
			s.log.Warn("ลบไฟล์บน storage ไม่สำเร็จ", "asset_id", id, "err", err)
		}
	}
	return s.repo.Delete(ctx, userID, id)
}

// withPublicURL เติม URL อ่านชั่วคราว
//
// URL นี้ใช้สองอย่าง: ให้แอปแสดง preview และ **ให้ TikTok ดึงไฟล์ไปโพสต์**
// (PULL_FROM_URL) จึงต้องมีอายุนานพอให้ TikTok ดาวน์โหลดจนจบ
func (s *Service) withPublicURL(ctx context.Context, a *Asset) (*Asset, error) {
	if s.store == nil || a.Status != StatusUploaded {
		return a, nil
	}

	url, err := s.store.PresignGet(ctx, a.storageKey, s.limits.DownloadURLTTL)
	if err != nil {
		return nil, err
	}
	expires := time.Now().Add(s.limits.DownloadURLTTL)

	a.PublicURL = url
	a.PublicURLExpiresAt = &expires
	return a, nil
}

func (s *Service) validate(req UploadRequest) error {
	if _, ok := extensionFor(req.Kind, req.Mime); !ok {
		return apierror.ErrValidation.
			WithDetail("field", "mime").
			WithDetail("reason", fmt.Sprintf("ไม่รองรับไฟล์ชนิด %q สำหรับ %s", req.Mime, req.Kind))
	}

	if req.SizeBytes <= 0 {
		return apierror.ErrValidation.
			WithDetail("field", "size_bytes").
			WithDetail("reason", "ต้องระบุขนาดไฟล์")
	}

	limit := s.limits.MaxImageBytes
	if req.Kind == KindVideo {
		limit = s.limits.MaxVideoBytes
	}
	if req.SizeBytes > limit {
		return apierror.ErrValidation.
			WithDetail("field", "size_bytes").
			WithDetail("reason", fmt.Sprintf("ไฟล์ใหญ่เกิน %d MB", limit/(1<<20))).
			WithDetail("max_bytes", limit)
	}
	return nil
}
