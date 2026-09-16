CREATE TABLE products (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider            text NOT NULL DEFAULT 'tiktok',
    external_product_id text NOT NULL,
    title               text NOT NULL,
    price_baht          integer NOT NULL CHECK (price_baht >= 0),
    commission_percent  integer NOT NULL DEFAULT 0
                        CHECK (commission_percent BETWEEN 0 AND 100),
    stock               integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    shop_name           text NOT NULL DEFAULT '',
    selling_points      text[] NOT NULL DEFAULT '{}',
    discount_percent    integer NOT NULL DEFAULT 0
                        CHECK (discount_percent BETWEEN 0 AND 100),
    image_url           text,
    synced_at           timestamptz NOT NULL DEFAULT now(),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, provider, external_product_id)
);

CREATE INDEX idx_products_user_synced
    ON products (user_id, synced_at DESC);
