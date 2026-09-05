package storage

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

type R2Config struct {
	AccountID       string
	AccessKeyID     string
	SecretAccessKey string
	Bucket          string

	// Endpoint ทับ URL ที่สร้างจาก AccountID
	// มีไว้ให้ชี้ไป MinIO ตอน dev เพื่อทดสอบ flow อัปโหลดจริงโดยไม่ต้องมีบัญชี Cloudflare
	Endpoint string
}

func (c R2Config) Enabled() bool {
	hasHost := c.AccountID != "" || c.Endpoint != ""
	return hasHost && c.AccessKeyID != "" && c.SecretAccessKey != "" && c.Bucket != ""
}

type R2 struct {
	client  *s3.Client
	presign *s3.PresignClient
	bucket  string
}

func NewR2(cfg R2Config) (*R2, error) {
	if !cfg.Enabled() {
		return nil, ErrNotConfigured
	}

	endpoint := cfg.Endpoint
	if endpoint == "" {
		endpoint = fmt.Sprintf("https://%s.r2.cloudflarestorage.com", cfg.AccountID)
	}

	client := s3.New(s3.Options{
		// R2 ไม่มีแนวคิดเรื่อง region — SDK บังคับให้ใส่ จึงใช้ "auto"
		Region:       "auto",
		BaseEndpoint: aws.String(endpoint),
		Credentials: credentials.NewStaticCredentialsProvider(
			cfg.AccessKeyID, cfg.SecretAccessKey, ""),
		// path-style ปลอดภัยกว่าเมื่อชี้ endpoint เอง
		UsePathStyle: true,
	})

	return &R2{
		client:  client,
		presign: s3.NewPresignClient(client),
		bucket:  cfg.Bucket,
	}, nil
}

func (r *R2) PresignPut(
	ctx context.Context, key, contentType string, size int64, ttl time.Duration,
) (*PresignedUpload, error) {
	// ใส่ ContentLength ลงในลายเซ็นด้วย ทำให้ client อัปไฟล์ใหญ่กว่าที่ขอไม่ได้
	// ถ้าเซ็นแค่ URL เปล่า ๆ ใครก็ยัดไฟล์ขนาดเท่าไหร่ก็ได้จนกว่า TTL จะหมด
	req, err := r.presign.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(r.bucket),
		Key:           aws.String(key),
		ContentType:   aws.String(contentType),
		ContentLength: aws.Int64(size),
	}, s3.WithPresignExpires(ttl))
	if err != nil {
		return nil, fmt.Errorf("storage: สร้าง presigned PUT ไม่สำเร็จ: %w", err)
	}

	headers := map[string]string{
		"Content-Type":   contentType,
		"Content-Length": strconv.FormatInt(size, 10),
	}
	// header อื่นที่ SDK เซ็นไว้ต้องส่งไปด้วย ไม่งั้นลายเซ็นไม่ตรง
	for k, v := range req.SignedHeader {
		if len(v) > 0 {
			headers[k] = v[0]
		}
	}

	return &PresignedUpload{
		URL:       req.URL,
		Headers:   headers,
		ExpiresAt: time.Now().Add(ttl),
	}, nil
}

func (r *R2) PresignGet(ctx context.Context, key string, ttl time.Duration) (string, error) {
	req, err := r.presign.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(r.bucket),
		Key:    aws.String(key),
	}, s3.WithPresignExpires(ttl))
	if err != nil {
		return "", fmt.Errorf("storage: สร้าง presigned GET ไม่สำเร็จ: %w", err)
	}
	return req.URL, nil
}

func (r *R2) Head(ctx context.Context, key string) (*ObjectInfo, error) {
	out, err := r.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(r.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		var notFound *types.NotFound
		if errors.As(err, &notFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("storage: อ่านข้อมูลไฟล์ไม่สำเร็จ: %w", err)
	}

	info := &ObjectInfo{}
	if out.ContentLength != nil {
		info.Size = *out.ContentLength
	}
	if out.ContentType != nil {
		info.ContentType = *out.ContentType
	}
	if out.ETag != nil {
		info.ETag = *out.ETag
	}
	return info, nil
}

func (r *R2) Delete(ctx context.Context, key string) error {
	if _, err := r.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(r.bucket),
		Key:    aws.String(key),
	}); err != nil {
		return fmt.Errorf("storage: ลบไฟล์ไม่สำเร็จ: %w", err)
	}
	return nil
}
