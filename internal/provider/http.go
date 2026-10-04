package provider

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// HTTP bridges the agent's event protocol to the eiwa translation API.
// The API returns a complete translation, so emit is called once per response.
type HTTP struct {
	Endpoint string
	Style    string
	Glossary map[string]string
	Client   *http.Client
}

func NewHTTP(endpoint, style string, glossary map[string]string, timeout time.Duration) (*HTTP, error) {
	u, err := url.Parse(endpoint)
	if err != nil || u.Host == "" || (u.Scheme != "http" && u.Scheme != "https") {
		return nil, fmt.Errorf("API endpoint must be an absolute HTTP or HTTPS URL")
	}
	if style != "source" && style != "polite" && style != "plain" {
		return nil, fmt.Errorf("API style must be source, polite, or plain")
	}
	if timeout <= 0 {
		return nil, fmt.Errorf("API timeout must be positive")
	}
	return &HTTP{Endpoint: endpoint, Style: style, Glossary: glossary, Client: &http.Client{Timeout: timeout}}, nil
}

func (p *HTTP) Stream(ctx context.Context, content string, emit func(string) error) error {
	body, err := json.Marshal(struct {
		Text     string            `json:"text"`
		Style    string            `json:"style"`
		Glossary map[string]string `json:"glossary,omitempty"`
	}{content, p.Style, p.Glossary})
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.Endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	response, err := p.Client.Do(req)
	if err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("translation API connection failed; check the API server and endpoint: %w", err)
	}
	defer response.Body.Close()
	const maxResponse = 2 * 1024 * 1024
	data, err := io.ReadAll(io.LimitReader(response.Body, maxResponse+1))
	if err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("read translation API response: %w", err)
	}
	if len(data) > maxResponse {
		return fmt.Errorf("translation API response exceeds 2 MiB")
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		var failure struct {
			Detail struct {
				Code    string `json:"code"`
				Message string `json:"message"`
			} `json:"detail"`
		}
		if json.Unmarshal(data, &failure) == nil && failure.Detail.Message != "" {
			return fmt.Errorf("translation API HTTP %d (%s): %s", response.StatusCode, failure.Detail.Code, failure.Detail.Message)
		}
		return fmt.Errorf("translation API HTTP %d", response.StatusCode)
	}
	var result struct {
		Translation string `json:"translation"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		return fmt.Errorf("translation API returned invalid JSON")
	}
	if strings.TrimSpace(result.Translation) == "" {
		return fmt.Errorf("translation API returned an empty translation")
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	return emit(result.Translation)
}
