package product

import (
	"context"
	"errors"

	"relaycontent/internal/apierror"
)

type Service struct{ repo *Repository }

func NewService(repo *Repository) *Service { return &Service{repo: repo} }

func (s *Service) List(ctx context.Context, userID string, limit int) ([]*Product, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	return s.repo.List(ctx, userID, limit)
}

func (s *Service) Get(ctx context.Context, userID, id string) (*Product, error) {
	item, err := s.repo.Get(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return nil, apierror.ErrNotFound
	}
	return item, err
}
