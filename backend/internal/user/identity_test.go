package user

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"os"
	"relaycontent/migrations"
	"testing"
)

func TestIdentityRepository(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("set TEST_DATABASE_URL for isolated-schema PostgreSQL integration test")
	}
	ctx := context.Background()
	admin, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer admin.Close()
	schema := "identity_test_" + uuid.New().String()
	schemaName := `"` + schema + `"`
	if _, err = admin.Exec(ctx, `CREATE SCHEMA `+schemaName); err != nil {
		t.Fatal(err)
	}
	defer admin.Exec(ctx, `DROP SCHEMA `+schemaName+` CASCADE`)
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		t.Fatal(err)
	}
	cfg.ConnConfig.RuntimeParams["search_path"] = schemaName + ",public"
	db, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	_, err = db.Exec(ctx, `CREATE TABLE users(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),email text UNIQUE NOT NULL,password_hash text NOT NULL,display_name text,timezone text NOT NULL DEFAULT 'Asia/Bangkok',status text NOT NULL DEFAULT 'active',created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now())`)
	if err != nil {
		t.Fatal(err)
	}
	up, err := migrations.FS.ReadFile("000002_auth_identities.up.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec(ctx, string(up)); err != nil {
		t.Fatal(err)
	}
	repo := NewRepository(db)
	first, err := repo.ResolveIdentity(ctx, "google", "subject-1", "first@example.com", "First", "")
	if err != nil {
		t.Fatal(err)
	}
	again, err := repo.ResolveIdentity(ctx, "google", "subject-1", "changed@example.com", "Changed", "")
	if err != nil || again.ID != first.ID {
		t.Fatalf("identity must survive email changes: %v", err)
	}
	_, err = repo.ResolveIdentity(ctx, "google", "subject-2", "first@example.com", "", "")
	if !errors.Is(err, ErrIdentityConflict) {
		t.Fatalf("must not merge by email: %v", err)
	}
	local, err := repo.Create(ctx, "local@example.com", "password-hash", "Local", "Asia/Bangkok")
	if err != nil {
		t.Fatal(err)
	}
	linked, err := repo.ResolveIdentity(ctx, "google", "subject-2", "first@example.com", "", local.ID)
	if err != nil || linked.ID != local.ID {
		t.Fatalf("explicit link: %v", err)
	}
	_, err = repo.ResolveIdentity(ctx, "google", "subject-1", "first@example.com", "", local.ID)
	if !errors.Is(err, ErrIdentityConflict) {
		t.Fatalf("must not steal identity: %v", err)
	}
	_, err = repo.ResolveIdentity(ctx, "google", "subject-3", "third@example.com", "", local.ID)
	if !errors.Is(err, ErrIdentityConflict) {
		t.Fatalf("must not replace existing provider link: %v", err)
	}
	down, err := migrations.FS.ReadFile("000002_auth_identities.down.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec(ctx, string(down)); err != nil {
		t.Fatal(err)
	}
}
