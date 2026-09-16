// Package product stores the creator's server-verified product catalog.
package product

import "time"

type Product struct {
	ID                string    `json:"id"`
	Provider          string    `json:"provider"`
	ExternalProductID string    `json:"external_product_id"`
	Name              string    `json:"name"`
	PriceBaht         int       `json:"price_baht"`
	CommissionPercent int       `json:"commission_percent"`
	Stock             int       `json:"stock"`
	ShopName          string    `json:"shop_name"`
	SellingPoints     []string  `json:"selling_points"`
	DiscountPercent   int       `json:"discount_percent"`
	ImageURL          string    `json:"image_url,omitempty"`
	SyncedAt          time.Time `json:"synced_at"`
}
