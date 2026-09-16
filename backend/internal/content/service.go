package content

import (
	"context"
	"errors"
	"log/slog"
	"strings"

	"relaycontent/internal/apierror"
)

const maxCaptionRunes = 2200

// MediaAttacher คือส่วนของ media service ที่ content ต้องใช้
// ประกาศเป็น interface ฝั่งผู้ใช้งาน เพื่อไม่ให้ content ผูกกับ media ทั้งก้อน
type MediaAttacher interface {
	Attach(ctx context.Context, userID, assetID, contentID string) error
}

type Service struct {
	repo  *Repository
	media MediaAttacher
	log   *slog.Logger
}

func NewService(repo *Repository, media MediaAttacher, log *slog.Logger) *Service {
	return &Service{repo: repo, media: media, log: log}
}

type CreateInput struct {
	UserID       string
	Title        string
	Caption      string
	Hashtags     []string
	MediaAssetID string
}

func (s *Service) Create(ctx context.Context, in CreateInput) (*Content, error) {
	if err := validateCaption(in.Caption); err != nil {
		return nil, err
	}

	c, err := s.repo.Create(ctx, in.UserID, strings.TrimSpace(in.Title),
		in.Caption, normalizeTags(in.Hashtags))
	if err != nil {
		return nil, err
	}

	if in.MediaAssetID != "" {
		if err := s.media.Attach(ctx, in.UserID, in.MediaAssetID, c.ID); err != nil {
			return nil, err
		}
		// มีวิดีโอแล้ว = พร้อมตั้งเวลาโพสต์ได้
		if err := s.repo.SetStatus(ctx, c.ID, StatusReady); err != nil {
			return nil, err
		}
		c.Status = StatusReady
	}
	return c, nil
}

func (s *Service) Get(ctx context.Context, userID, id string) (*Content, error) {
	c, err := s.repo.Get(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	return c, err
}

func (s *Service) List(ctx context.Context, userID string, status Status, limit int) ([]*Content, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	return s.repo.List(ctx, userID, status, limit)
}

type UpdateInput struct {
	Title    *string
	Caption  *string
	Hashtags []string
}

func (s *Service) Update(ctx context.Context, userID, id string, in UpdateInput) (*Content, error) {
	if in.Caption != nil {
		if err := validateCaption(*in.Caption); err != nil {
			return nil, err
		}
	}

	c, err := s.repo.Update(ctx, userID, id, in.Title, in.Caption, normalizeTags(in.Hashtags))
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	return c, err
}

// ── สิ่งที่ publish/worker เรียกใช้ ───────────────────────────

// EnsureOwned verifies content ownership without revealing whether an ID
// belongs to another account or does not exist.
func (s *Service) EnsureOwned(ctx context.Context, userID, contentID string) error {
	_, err := s.repo.Get(ctx, userID, contentID)
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	return err
}

func (s *Service) CaptionOf(ctx context.Context, contentID string) (string, error) {
	return s.repo.CaptionOf(ctx, contentID)
}

func (s *Service) SetContentStatus(ctx context.Context, contentID, status string) error {
	return s.repo.SetStatus(ctx, contentID, Status(status))
}

func validateCaption(caption string) error {
	// นับเป็น rune เพราะภาษาไทยหนึ่งตัวกินหลายไบต์
	// ถ้านับไบต์ ผู้ใช้ไทยจะพิมพ์ได้สั้นกว่าที่ TikTok อนุญาตจริงราวสามเท่า
	if n := len([]rune(caption)); n > maxCaptionRunes {
		return apierror.ErrValidation.
			WithDetail("field", "caption").
			WithDetail("reason", "caption ยาวเกิน 2,200 ตัวอักษร").
			WithDetail("length", n)
	}
	return nil
}

func normalizeTags(tags []string) []string {
	if tags == nil {
		return nil
	}
	out := make([]string, 0, len(tags))
	seen := make(map[string]bool, len(tags))

	for _, t := range tags {
		t = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(t), "#"))
		if t == "" || seen[t] {
			continue
		}
		seen[t] = true
		out = append(out, t)
	}
	return out
}
