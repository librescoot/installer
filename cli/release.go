package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

const (
	githubRepo = "librescoot/librescoot"
	apiBase    = "https://api.github.com"
)

type ghRelease struct {
	TagName string    `json:"tag_name"`
	Assets  []ghAsset `json:"assets"`
}

type ghAsset struct {
	Name               string `json:"name"`
	Size               int64  `json:"size"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

// findLatestRelease queries GitHub for the latest release matching a channel prefix.
func findLatestRelease(channel string) (string, error) {
	url := fmt.Sprintf("%s/repos/%s/releases", apiBase, githubRepo)
	resp, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("GitHub API request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("GitHub API returned %d", resp.StatusCode)
	}

	var releases []ghRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return "", fmt.Errorf("parsing releases: %w", err)
	}

	for _, r := range releases {
		if strings.HasPrefix(r.TagName, channel+"-") {
			return r.TagName, nil
		}
	}

	return "", fmt.Errorf("no release found for channel %q", channel)
}

// downloadMDBImage downloads the MDB sdimg.gz for a given release tag.
// Returns the local file path. Skips download if the file already exists.
func downloadMDBImage(tag, cacheDir string) (string, error) {
	url := fmt.Sprintf("%s/repos/%s/releases/tags/%s", apiBase, githubRepo, tag)
	resp, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("fetching release %s: %w", tag, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("release %s not found (HTTP %d)", tag, resp.StatusCode)
	}

	var release ghRelease
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return "", fmt.Errorf("parsing release: %w", err)
	}

	// Find the MDB sdimg.gz asset
	var asset *ghAsset
	for i := range release.Assets {
		a := &release.Assets[i]
		if strings.Contains(a.Name, "unu-mdb") && strings.HasSuffix(a.Name, ".sdimg.gz") {
			asset = a
			break
		}
	}
	if asset == nil {
		names := make([]string, len(release.Assets))
		for i, a := range release.Assets {
			names[i] = a.Name
		}
		return "", fmt.Errorf("no MDB sdimg.gz found in release %s (assets: %s)", tag, strings.Join(names, ", "))
	}

	// Check cache
	destDir := filepath.Join(cacheDir, tag)
	destPath := filepath.Join(destDir, asset.Name)

	if info, err := os.Stat(destPath); err == nil && info.Size() == asset.Size {
		logInfo("Using cached: %s (%s)", asset.Name, formatBytes(info.Size()))
		return destPath, nil
	}

	logInfo("Downloading: %s (%s)", asset.Name, formatBytes(asset.Size))

	if err := os.MkdirAll(destDir, 0o755); err != nil {
		return "", fmt.Errorf("creating cache dir: %w", err)
	}

	dlResp, err := http.Get(asset.BrowserDownloadURL)
	if err != nil {
		return "", fmt.Errorf("downloading %s: %w", asset.Name, err)
	}
	defer dlResp.Body.Close()

	if dlResp.StatusCode != 200 {
		return "", fmt.Errorf("download returned HTTP %d", dlResp.StatusCode)
	}

	tmpPath := destPath + ".part"
	f, err := os.Create(tmpPath)
	if err != nil {
		return "", fmt.Errorf("creating file: %w", err)
	}

	written, err := io.Copy(f, &progressReader{
		reader: dlResp.Body,
		total:  asset.Size,
	})
	f.Close()
	if err != nil {
		os.Remove(tmpPath)
		return "", fmt.Errorf("writing file: %w", err)
	}

	if written != asset.Size {
		os.Remove(tmpPath)
		return "", fmt.Errorf("incomplete download: got %d of %d bytes", written, asset.Size)
	}

	if err := os.Rename(tmpPath, destPath); err != nil {
		return "", fmt.Errorf("finalizing download: %w", err)
	}

	fmt.Println() // newline after progress
	logInfo("Saved to: %s", destPath)
	return destPath, nil
}

type progressReader struct {
	reader  io.Reader
	total   int64
	current int64
	lastPct int
}

func (pr *progressReader) Read(p []byte) (int, error) {
	n, err := pr.reader.Read(p)
	pr.current += int64(n)
	if pr.total > 0 {
		pct := int(pr.current * 100 / pr.total)
		if pct != pr.lastPct {
			pr.lastPct = pct
			fmt.Printf("\r    %3d%% (%s / %s)", pct, formatBytes(pr.current), formatBytes(pr.total))
		}
	}
	return n, err
}

func formatBytes(b int64) string {
	switch {
	case b >= 1<<30:
		return fmt.Sprintf("%.1f GB", float64(b)/float64(1<<30))
	case b >= 1<<20:
		return fmt.Sprintf("%.1f MB", float64(b)/float64(1<<20))
	case b >= 1<<10:
		return fmt.Sprintf("%.1f KB", float64(b)/float64(1<<10))
	default:
		return fmt.Sprintf("%d B", b)
	}
}
