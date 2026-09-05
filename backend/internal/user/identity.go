package user

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

var ErrIdentityConflict = errors.New("identity already linked or email requires sign-in")

// ResolveIdentity never merges users by email. An existing account must be
// authenticated before a new login identity can be attached to it.
func (r *Repository) ResolveIdentity(ctx context.Context, provider, subject, email, name, linkUserID string) (*User, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	// Serialize concurrent first logins for the same provider identity.
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, provider+":"+subject); err != nil {
		return nil, err
	}
	var id string
	err = tx.QueryRow(ctx, `SELECT user_id FROM auth_identities WHERE provider=$1 AND subject=$2`, provider, subject).Scan(&id)
	if err == nil {
		if linkUserID != "" && id != linkUserID {
			return nil, ErrIdentityConflict
		}
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	} else {
		id = linkUserID
		if id == "" {
			// Empty hash intentionally disables password login for Google-only users.
			err = tx.QueryRow(ctx, `INSERT INTO users(email,password_hash,display_name) VALUES($1,'',NULLIF($2,'')) RETURNING id`, email, name).Scan(&id)
			if err != nil {
				return nil, identityError(err)
			}
		}
		_, err = tx.Exec(ctx, `INSERT INTO auth_identities(provider,subject,user_id) VALUES($1,$2,$3)`, provider, subject, id)
		if err != nil {
			return nil, identityError(err)
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.GetByID(ctx, id)
}

func identityError(err error) error {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == uniqueViolation {
		return ErrIdentityConflict
	}
	return err
}
