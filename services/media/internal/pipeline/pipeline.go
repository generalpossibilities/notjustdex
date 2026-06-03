package pipeline

import (
	"fmt"
	"os/exec"
	"path/filepath"
)

type MediaType string

const (
	MediaVideo MediaType = "video"
	MediaImage MediaType = "image"
)

type MediaAsset struct {
	ID          string   `json:"id"`
	UploadID    string   `json:"upload_id"`
	Type        MediaType `json:"type"`
	OriginalURL string   `json:"original_url"`
	HLSURL      string   `json:"hls_url,omitempty"`
	ThumbnailURL string  `json:"thumbnail_url,omitempty"`
	Status      string   `json:"status"` // pending, processing, ready, failed
}

type Pipeline struct {
	InputDir  string
	OutputDir string
	CDNBase   string
}

func NewPipeline(inputDir, outputDir, cdnBase string) *Pipeline {
	return &Pipeline{
		InputDir:  inputDir,
		OutputDir: outputDir,
		CDNBase:   cdnBase,
	}
}

func (p *Pipeline) ProcessVideo(assetID, inputPath string) error {
	outputDir := filepath.Join(p.OutputDir, assetID)

	// 1. Transcode to HLS (adaptive bitrate)
	playlistPath := filepath.Join(outputDir, "master.m3u8")
	cmd := exec.Command("ffmpeg",
		"-i", inputPath,
		"-vf", "scale=w=640:h=360:force_original_aspect_ratio=decrease",
		"-c:v", "h264",
		"-b:v", "800k",
		"-c:a", "aac",
		"-b:a", "128k",
		"-f", "hls",
		"-hls_time", "6",
		"-hls_playlist_type", "vod",
		"-master_pl_name", "master.m3u8",
		filepath.Join(outputDir, "stream_%v.m3u8"),
	)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("transcode failed: %w\n%s", err, output)
	}

	// 2. Generate thumbnail
	thumbPath := filepath.Join(outputDir, "thumb.jpg")
	thumbCmd := exec.Command("ffmpeg",
		"-i", inputPath,
		"-ss", "00:00:01",
		"-vframes", "1",
		"-vf", "scale=640:-1",
		thumbPath,
	)
	if output, err := thumbCmd.CombinedOutput(); err != nil {
		return fmt.Errorf("thumbnail failed: %w\n%s", err, output)
	}

	return nil
}

func (p *Pipeline) CDNURL(assetID, filename string) string {
	return fmt.Sprintf("%s/media/%s/%s", p.CDNBase, assetID, filename)
}
