package store

import (
	"sync"
	"time"

	"github.com/dexchats/moderation/internal/ml"
)

type ReportStatus string

const (
	ReportPending  ReportStatus = "pending"
	ReportApproved ReportStatus = "approved"
	ReportRejected ReportStatus = "rejected"
)

type Report struct {
	ID           string            `json:"id"`
	ContentID    string            `json:"content_id"`
	ContentType  ml.ContentType    `json:"content_type"`
	ReporterID   string            `json:"reporter_id"`
	Reason       string            `json:"reason"`
	Status       ReportStatus      `json:"status"`
	ModResult    *ml.ModerationResult `json:"mod_result,omitempty"`
	CreatedAt    time.Time         `json:"created_at"`
	ReviewedAt   *time.Time        `json:"reviewed_at,omitempty"`
	ReviewerID   string            `json:"reviewer_id,omitempty"`
}

type MemoryStore struct {
	mu      sync.RWMutex
	reports map[string]*Report
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		reports: make(map[string]*Report),
	}
}

func (s *MemoryStore) AddReport(r *Report) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.reports[r.ID] = r
}

func (s *MemoryStore) GetPending() []*Report {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var result []*Report
	for _, r := range s.reports {
		if r.Status == ReportPending {
			result = append(result, r)
		}
	}
	return result
}

func (s *MemoryStore) UpdateStatus(id string, status ReportStatus, reviewerID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if r, ok := s.reports[id]; ok {
		r.Status = status
		r.ReviewerID = reviewerID
		now := time.Now()
		r.ReviewedAt = &now
	}
}
