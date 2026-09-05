package tiktok

import "context"

// Privacy level ที่ TikTok คืนมาใน privacy_level_options
//
// บัญชีสาธารณะ: PUBLIC_TO_EVERYONE, MUTUAL_FOLLOW_FRIENDS, SELF_ONLY
// บัญชีส่วนตัว:  FOLLOWER_OF_CREATOR, MUTUAL_FOLLOW_FRIENDS, SELF_ONLY
const (
	PrivacyPublicToEveryone  = "PUBLIC_TO_EVERYONE"
	PrivacyMutualFollow      = "MUTUAL_FOLLOW_FRIENDS"
	PrivacyFollowerOfCreator = "FOLLOWER_OF_CREATOR"
	PrivacySelfOnly          = "SELF_ONLY"
)

// CreatorInfo คือข้อมูลที่หน้า Composer ต้องใช้ render
//
// ⚠️ สำคัญกับการผ่าน audit: TikTok ตรวจว่าแอปแสดงค่าพวกนี้ตรงกับสถานะจริงของบัญชี
// ห้าม cache นาน ห้าม hardcode ตัวเลือก privacy เอง
type CreatorInfo struct {
	AvatarURL string `json:"creator_avatar_url"` // TTL 2 ชั่วโมง ห้ามเก็บถาวร
	Username  string `json:"creator_username"`
	Nickname  string `json:"creator_nickname"`

	// PrivacyLevelOptions คือตัวเลือกเดียวที่ dropdown ได้รับอนุญาตให้แสดง
	PrivacyLevelOptions []string `json:"privacy_level_options"`

	// ถ้าเป็น true ต้อง "disable" ช่องนั้นในหน้า Composer ไม่ใช่แค่ไม่ติ๊ก
	CommentDisabled bool `json:"comment_disabled"`
	DuetDisabled    bool `json:"duet_disabled"`
	StitchDisabled  bool `json:"stitch_disabled"`

	MaxVideoPostDurationSec int `json:"max_video_post_duration_sec"`
}

// CanPublishPublic บอกว่าบัญชีนี้โพสต์สาธารณะได้ไหม
//
// ถ้าแอปยังไม่ผ่าน TikTok audit ตัวเลือกจะเหลือแค่ SELF_ONLY
// แอปมือถืออ่านค่านี้ผ่าน capabilities เพื่อบอกผู้ใช้ล่วงหน้า
// แทนที่จะปล่อยให้กดโพสต์แล้วค่อยเด้ง error
func (c *CreatorInfo) CanPublishPublic() bool {
	for _, opt := range c.PrivacyLevelOptions {
		if opt == PrivacyPublicToEveryone {
			return true
		}
	}
	return false
}

type creatorInfoResponse struct {
	Data CreatorInfo `json:"data"`
}

// QueryCreatorInfo ต้องถูกเรียกทุกครั้งก่อนเปิดหน้า Composer
// เป็นข้อบังคับของ TikTok UX guideline ไม่ใช่แค่เรื่องความสด
func (c *Client) QueryCreatorInfo(ctx context.Context, accessToken string) (*CreatorInfo, error) {
	var resp creatorInfoResponse
	if err := c.doJSON(ctx, CreatorInfoURL, accessToken, nil, &resp); err != nil {
		return nil, err
	}
	return &resp.Data, nil
}
