package ml

type ContentType string

const (
	ContentText  ContentType = "text"
	ContentImage ContentType = "image"
	ContentVideo ContentType = "video"
)

type ModerationResult struct {
	ContentID     string   `json:"content_id"`
	ContentType   ContentType `json:"content_type"`
	IsFlagged     bool     `json:"is_flagged"`
	FlagReason    string   `json:"flag_reason,omitempty"`
	Confidence    float64  `json:"confidence"`
	Labels        []string `json:"labels,omitempty"`
	NeedsHumanReview bool  `json:"needs_human_review"`
}

type ModerationPipeline struct {
	// In production: ONNX Runtime + Triton inference server
	textThreshold    float64
	imageThreshold   float64
}

func NewModerationPipeline() *ModerationPipeline {
	return &ModerationPipeline{
		textThreshold:  0.85,
		imageThreshold: 0.90,
	}
}

func (p *ModerationPipeline) ModerateText(contentID, text string) *ModerationResult {
	// Production: call ONNX model via Triton
	// Model categories: toxicity, harassment, hate_speech, spam, violence, sexual, self_harm
	result := &ModerationResult{
		ContentID:   contentID,
		ContentType: ContentText,
	}

	// Demo logic: flag if contains certain keywords
	flags := p.checkTextFlags(text)
	if len(flags) > 0 {
		result.IsFlagged = true
		result.FlagReason = flags[0]
		result.Confidence = 0.92
		result.Labels = flags
	}

	return result
}

func (p *ModerationPipeline) ModerateImage(contentID, imageURL string) *ModerationResult {
	// Production: call vision model (NSFW, violence, hate symbols)
	result := &ModerationResult{
		ContentID:   contentID,
		ContentType: ContentImage,
	}
	return result
}

func (p *ModerationPipeline) checkTextFlags(text string) []string {
	var flags []string
	// In production: NLP model
	// For now, demo keyword matching
	keywords := map[string]string{
		"spam":  "Potential spam detected",
		"scam":  "Potential scam content",
		"nsfw":  "NSFW content detected",
	}

	for word, reason := range keywords {
		if contains(text, word) {
			flags = append(flags, reason)
		}
	}
	return flags
}

func contains(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
