package tiktok

import (
	"context"
	"fmt"
	"strings"

	"relaycontent/internal/publisher"
)

const (
	VideoInitURL   = "https://open.tiktokapis.com/v2/post/publish/video/init/"
	StatusFetchURL = "https://open.tiktokapis.com/v2/post/publish/status/fetch/"

	maxTitleRunes = 2200
)

// สถานะดิบที่ TikTok คืนจาก status/fetch
const (
	statusProcessingUpload   = "PROCESSING_UPLOAD"
	statusProcessingDownload = "PROCESSING_DOWNLOAD"
	statusSendToInbox        = "SEND_TO_USER_INBOX"
	statusPublishComplete    = "PUBLISH_COMPLETE"
	statusFailed             = "FAILED"
)

// Publisher ทำ interface publisher.Publisher ให้ TikTok
type Publisher struct{ client *Client }

func NewPublisher(c *Client) *Publisher { return &Publisher{client: c} }

func (p *Publisher) Platform() publisher.Platform { return publisher.PlatformTikTok }

// ── request/response ─────────────────────────────────────────

type postInfo struct {
	Title                 string `json:"title,omitempty"`
	PrivacyLevel          string `json:"privacy_level"`
	DisableDuet           bool   `json:"disable_duet"`
	DisableStitch         bool   `json:"disable_stitch"`
	DisableComment        bool   `json:"disable_comment"`
	VideoCoverTimestampMs int    `json:"video_cover_timestamp_ms,omitempty"`
	BrandContentToggle    bool   `json:"brand_content_toggle"`
	BrandOrganicToggle    bool   `json:"brand_organic_toggle"`
	// IsAIGC ต้องเป็น true เสมอเมื่อวิดีโอมาจาก AI — เป็นข้อกำหนดของ TikTok
	IsAIGC bool `json:"is_aigc"`
}

type sourceInfo struct {
	Source   string `json:"source"`
	VideoURL string `json:"video_url,omitempty"`
}

type initRequest struct {
	PostInfo   postInfo   `json:"post_info"`
	SourceInfo sourceInfo `json:"source_info"`
}

type initResponse struct {
	Data struct {
		PublishID string `json:"publish_id"`
	} `json:"data"`
}

type statusResponse struct {
	Data struct {
		Status     string `json:"status"`
		FailReason string `json:"fail_reason"`
		// ชื่อ field สะกดผิดแบบนี้จริงในฝั่ง TikTok — ห้ามแก้ให้ถูก
		PubliclyAvailablePostID []int64 `json:"publicaly_available_post_id"`
		UploadedBytes           int64   `json:"uploaded_bytes"`
	} `json:"data"`
}

// ── validate ─────────────────────────────────────────────────

// Validate บังคับกฎเดียวกับหน้า Composer อีกรอบที่ฝั่ง server
//
// หน้าจอบังคับกฎพวกนี้อยู่แล้วเพื่อผ่าน audit แต่ client แก้ได้
// ถ้าไม่ตรวจซ้ำ คำขอที่ถูกดัดแปลงจะไปตายที่ TikTok ตอนตีสอง
// แล้วผู้ใช้จะเห็นแค่ "โพสต์ไม่สำเร็จ" โดยไม่รู้สาเหตุ
func (p *Publisher) Validate(opts publisher.Options) error {
	privacy := optString(opts, "privacy_level")
	if privacy == "" {
		return fmt.Errorf("ต้องเลือกว่าใครดูวิดีโอนี้ได้ (privacy_level)")
	}

	switch privacy {
	case PrivacyPublicToEveryone, PrivacyMutualFollow,
		PrivacyFollowerOfCreator, PrivacySelfOnly:
	default:
		return fmt.Errorf("privacy_level %q ไม่ถูกต้อง", privacy)
	}

	// Branded content ตั้งเป็น "เฉพาะฉัน" ไม่ได้ตามนโยบายของ TikTok
	if optBool(opts, "brand_content_toggle") && privacy == PrivacySelfOnly {
		return fmt.Errorf(`Branded content ตั้งเป็น "เฉพาะฉัน" ไม่ได้`)
	}
	return nil
}

// ── publish ──────────────────────────────────────────────────

func (p *Publisher) Publish(ctx context.Context, req publisher.PublishRequest) (*publisher.PublishResult, error) {
	if err := p.Validate(req.Options); err != nil {
		return nil, permanent(err)
	}
	if strings.TrimSpace(req.VideoURL) == "" {
		return nil, permanent(fmt.Errorf("ไม่มี URL ของวิดีโอ"))
	}

	title := req.Caption
	if n := len([]rune(title)); n > maxTitleRunes {
		return nil, permanent(fmt.Errorf("caption ยาว %d ตัวอักษร เกินขีดจำกัด %d", n, maxTitleRunes))
	}

	body := initRequest{
		PostInfo: postInfo{
			Title:                 title,
			PrivacyLevel:          optString(req.Options, "privacy_level"),
			DisableDuet:           optBool(req.Options, "disable_duet"),
			DisableStitch:         optBool(req.Options, "disable_stitch"),
			DisableComment:        optBool(req.Options, "disable_comment"),
			VideoCoverTimestampMs: optInt(req.Options, "video_cover_timestamp_ms"),
			BrandContentToggle:    optBool(req.Options, "brand_content_toggle"),
			BrandOrganicToggle:    optBool(req.Options, "brand_organic_toggle"),
			IsAIGC:                optBool(req.Options, "is_aigc"),
		},
		SourceInfo: sourceInfo{
			// PULL_FROM_URL ให้ TikTok มาดึงไฟล์เอง
			// เราจึงไม่ต้องทำ chunked upload และไม่ต้องแบก bandwidth ของวิดีโอ
			Source:   "PULL_FROM_URL",
			VideoURL: req.VideoURL,
		},
	}

	var resp initResponse
	if err := p.client.doJSON(ctx, VideoInitURL, req.AccessToken, body, &resp); err != nil {
		return nil, err
	}
	if resp.Data.PublishID == "" {
		return nil, permanent(fmt.Errorf("TikTok ไม่ได้คืน publish_id"))
	}
	return &publisher.PublishResult{ExternalPublishID: resp.Data.PublishID}, nil
}

func (p *Publisher) Status(ctx context.Context, accessToken, publishID string) (*publisher.StatusResult, error) {
	var resp statusResponse
	body := map[string]string{"publish_id": publishID}

	if err := p.client.doJSON(ctx, StatusFetchURL, accessToken, body, &resp); err != nil {
		return nil, err
	}

	out := &publisher.StatusResult{FailReason: resp.Data.FailReason}

	switch resp.Data.Status {
	case statusPublishComplete:
		out.State = publisher.StatePublished
		if ids := resp.Data.PubliclyAvailablePostID; len(ids) > 0 {
			out.PostID = fmt.Sprintf("%d", ids[0])
		}
	case statusFailed:
		out.State = publisher.StateFailed
		if out.FailReason == "" {
			out.FailReason = "TikTok ปฏิเสธวิดีโอนี้"
		}
	case statusProcessingUpload, statusProcessingDownload, statusSendToInbox, "":
		out.State = publisher.StateProcessing
	default:
		// สถานะที่ยังไม่รู้จัก ถือว่ากำลังทำงานอยู่ ปลอดภัยกว่าตัดสินว่าล้มเหลว
		out.State = publisher.StateProcessing
	}
	return out, nil
}

// PermalinkFor ประกอบลิงก์โพสต์ — accountName คือ "@username"
func (p *Publisher) PermalinkFor(accountName, postID string) string {
	if postID == "" {
		return ""
	}
	handle := strings.TrimSpace(accountName)
	if handle == "" {
		return ""
	}
	if !strings.HasPrefix(handle, "@") {
		handle = "@" + handle
	}
	return fmt.Sprintf("https://www.tiktok.com/%s/video/%s", handle, postID)
}

// ── helper ───────────────────────────────────────────────────

// permanentError ห่อ error ที่เกิดจากข้อมูลของเราเอง — retry ไปก็ผลเดิม
type permanentError struct{ err error }

func permanent(err error) error                  { return &permanentError{err} }
func (e *permanentError) Error() string          { return e.err.Error() }
func (e *permanentError) Unwrap() error          { return e.err }
func (e *permanentError) Fault() publisher.Fault { return publisher.FaultPermanent }

func optString(o publisher.Options, key string) string {
	if v, ok := o[key].(string); ok {
		return strings.TrimSpace(v)
	}
	return ""
}

func optBool(o publisher.Options, key string) bool {
	v, _ := o[key].(bool)
	return v
}

// optInt รองรับ float64 ด้วย เพราะค่าที่อ่านกลับจาก jsonb จะเป็น float64 เสมอ
func optInt(o publisher.Options, key string) int {
	switch v := o[key].(type) {
	case float64:
		return int(v)
	case int:
		return v
	case int64:
		return int(v)
	default:
		return 0
	}
}
