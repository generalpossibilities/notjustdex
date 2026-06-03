package index

import (
	"strings"
	"sync"
)

type SearchResult struct {
	ID       string  `json:"id"`
	Type     string  `json:"type"` // user, post, mini_app
	Title    string  `json:"title"`
	Subtitle string  `json:"subtitle,omitempty"`
	Score    float64 `json:"score"`
	Avatar   string  `json:"avatar,omitempty"`
}

type DocType string

const (
	DocUser    DocType = "user"
	DocPost    DocType = "post"
	DocMiniApp DocType = "mini_app"
)

type Document struct {
	ID      string   `json:"id"`
	Type    DocType  `json:"type"`
	Title   string   `json:"title"`
	Content string   `json:"content"`
	Tags    []string `json:"tags"`
}

type MemoryIndex struct {
	mu      sync.RWMutex
	docs    []*Document
}

func NewMemoryIndex() *MemoryIndex {
	return &MemoryIndex{}
}

func (idx *MemoryIndex) Index(doc *Document) {
	idx.mu.Lock()
	defer idx.mu.Unlock()
	idx.docs = append(idx.docs, doc)
}

func (idx *MemoryIndex) Search(query string, limit int) []*SearchResult {
	idx.mu.RLock()
	defer idx.mu.RUnlock()

	query = strings.ToLower(query)
	var results []*SearchResult

	for _, doc := range idx.docs {
		score := 0.0
		lowerTitle := strings.ToLower(doc.Title)
		lowerContent := strings.ToLower(doc.Content)

		if strings.Contains(lowerTitle, query) {
			score += 10.0
		}
		if strings.Contains(lowerContent, query) {
			score += 5.0
		}
		for _, tag := range doc.Tags {
			if strings.Contains(strings.ToLower(tag), query) {
				score += 3.0
			}
		}
		if score > 0 {
			results = append(results, &SearchResult{
				ID:    doc.ID,
				Type:  string(doc.Type),
				Title: doc.Title,
				Score: score,
			})
		}
	}

	if len(results) > limit {
		results = results[:limit]
	}
	return results
}
