package product

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("product: product not found")

type Repository struct{ db *pgxpool.Pool }

func NewRepository(db *pgxpool.Pool) *Repository { return &Repository{db: db} }

const columns = `id, provider, external_product_id, title, price_baht,
	commission_percent, stock, shop_name, selling_points, discount_percent,
	COALESCE(image_url,''), synced_at`

func (r *Repository) List(ctx context.Context, userID string, limit int) ([]*Product, error) {
	rows, err := r.db.Query(ctx, `SELECT `+columns+`
		FROM products WHERE user_id = $1
		ORDER BY synced_at DESC, created_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("product: list: %w", err)
	}
	defer rows.Close()

	items := make([]*Product, 0)
	for rows.Next() {
		item, err := scan(rows)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *Repository) Get(ctx context.Context, userID, id string) (*Product, error) {
	item, err := scan(r.db.QueryRow(ctx,
		`SELECT `+columns+` FROM products WHERE id = $1 AND user_id = $2`, id, userID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return item, err
}

type scanner interface{ Scan(...any) error }

func scan(row scanner) (*Product, error) {
	var item Product
	err := row.Scan(&item.ID, &item.Provider, &item.ExternalProductID, &item.Name,
		&item.PriceBaht, &item.CommissionPercent, &item.Stock, &item.ShopName,
		&item.SellingPoints, &item.DiscountPercent, &item.ImageURL, &item.SyncedAt)
	if err != nil {
		return nil, err
	}
	if item.SellingPoints == nil {
		item.SellingPoints = []string{}
	}
	return &item, nil
}
