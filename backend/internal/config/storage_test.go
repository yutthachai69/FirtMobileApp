package config

import "testing"

func TestStorageEnabledWithCustomEndpoint(t *testing.T) {
	cfg := StorageConfig{
		R2Endpoint:    "http://localhost:9000",
		R2AccessKeyID: "test", R2SecretAccessKey: "test", R2Bucket: "media",
	}
	if !cfg.Enabled() {
		t.Fatal("custom storage endpoint must work without an R2 account ID")
	}
	cfg.R2SecretAccessKey = ""
	if cfg.Enabled() {
		t.Fatal("custom endpoint must still require credentials")
	}
}
