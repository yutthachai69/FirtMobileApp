package product

import (
	"context"
	"os"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func productTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL is not set")
	}
	pool, err := pgxpool.New(context.Background(), url)
	if err != nil {
		t.Fatalf("connect test database: %v", err)
	}
	t.Cleanup(pool.Close)
	return pool
}

func productTestUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	var id string
	err := pool.QueryRow(context.Background(),
		`INSERT INTO users (email, password_hash, timezone)
		 VALUES ($1, 'x', 'Asia/Bangkok') RETURNING id`,
		"product-"+uuid.NewString()+"@test.local").Scan(&id)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, id)
	})
	return id
}

func TestCatalogIsIsolatedByOwner(t *testing.T) {
	pool := productTestDB(t)
	repo := NewRepository(pool)
	ownerID := productTestUser(t, pool)
	otherID := productTestUser(t, pool)
	ctx := context.Background()

	var productID string
	err := pool.QueryRow(ctx, `
		INSERT INTO products (
			user_id, external_product_id, title, price_baht,
			commission_percent, stock, shop_name, selling_points
		) VALUES ($1, $2, 'Test product', 290, 20, 12, 'Test shop', ARRAY['point'])
		RETURNING id`, ownerID, uuid.NewString()).Scan(&productID)
	if err != nil {
		t.Fatalf("create product: %v", err)
	}

	owned, err := repo.List(ctx, ownerID, 50)
	if err != nil || len(owned) != 1 || owned[0].ID != productID {
		t.Fatalf("owner list = %#v, err = %v", owned, err)
	}
	other, err := repo.List(ctx, otherID, 50)
	if err != nil || len(other) != 0 {
		t.Fatalf("other list = %#v, err = %v", other, err)
	}
	if _, err := repo.Get(ctx, otherID, productID); err != ErrNotFound {
		t.Fatalf("cross-tenant get error = %v, want ErrNotFound", err)
	}
}
