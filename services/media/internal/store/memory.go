package store

import (
	"sync"
	"time"

	"github.com/notjustdex/media/internal/pipeline"
)

type UploadRecord struct {
	ID        string          `json:"id"`
	UserID    string          `json:"user_id"`
	Asset     *pipeline.MediaAsset `json:"asset"`
	CreatedAt time.Time       `json:"created_at"`
}

type MemoryStore struct {
	mu      sync.RWMutex
	uploads map[string]*UploadRecord
	assets  map[string]*pipeline.MediaAsset
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		uploads: make(map[string]*UploadRecord),
		assets:  make(map[string]*pipeline.MediaAsset),
	}
}

func (s *MemoryStore) AddUpload(record *UploadRecord) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.uploads[record.ID] = record
	s.assets[record.Asset.ID] = record.Asset
}

func (s *MemoryStore) GetUpload(id string) *UploadRecord {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.uploads[id]
}

func (s *MemoryStore) GetAsset(id string) *pipeline.MediaAsset {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.assets[id]
}

func (s *MemoryStore) UpdateAssetStatus(assetID, status string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if asset, ok := s.assets[assetID]; ok {
		asset.Status = status
	}
}
