package provider

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestHTTPTranslationContract(t *testing.T) {
	source := "Run `git status`.\n```sh\ngit status\n```"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" || r.URL.Path != "/translate" || r.Header.Get("Content-Type") != "application/json" {
			t.Error("invalid HTTP contract")
		}
		var request struct {
			Text     string
			Style    string
			Glossary map[string]string
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Error(err)
		}
		if request.Text != source || request.Style != "polite" || request.Glossary["working tree"] != "作業ツリー" {
			t.Errorf("unexpected request: %+v", request)
		}
		json.NewEncoder(w).Encode(map[string]string{"translation": "`git status` を実行してください。\n```sh\ngit status\n```"})
	}))
	defer server.Close()
	p, err := NewHTTP(server.URL+"/translate", "polite", map[string]string{"working tree": "作業ツリー"}, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	var output string
	err = p.Stream(context.Background(), source, func(chunk string) error { output += chunk; return nil })
	if err != nil || !strings.Contains(output, "実行してください") || !strings.Contains(output, "\n```sh\n") {
		t.Fatalf("output=%q err=%v", output, err)
	}
}

func TestHTTPFailures(t *testing.T) {
	for _, test := range []struct {
		name, body, want string
		status           int
	}{
		{"busy", `{"detail":{"code":"busy","message":"再試行してください"}}`, "busy", 503},
		{"invalid", `not-json`, "invalid JSON", 200},
		{"empty", `{"translation":" "}`, "empty translation", 200},
		{"private_error", `private source text`, "HTTP 500", 500},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(test.status); w.Write([]byte(test.body)) }))
			defer server.Close()
			p, _ := NewHTTP(server.URL, "source", nil, time.Second)
			err := p.Stream(context.Background(), "source", func(string) error { t.Fatal("must not emit on failure"); return nil })
			if err == nil || !strings.Contains(err.Error(), test.want) || strings.Contains(err.Error(), "private source text") {
				t.Fatalf("unexpected error: %v", err)
			}
		})
	}
}

func TestHTTPCancellation(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		close(started)
		select {
		case <-r.Context().Done():
		case <-release:
		}
	}))
	defer server.Close()
	defer close(release)
	p, _ := NewHTTP(server.URL, "source", nil, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() {
		done <- p.Stream(ctx, "source", func(string) error { t.Error("cancelled request must not emit"); return nil })
	}()
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("request did not start")
	}
	cancel()
	select {
	case err := <-done:
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("unexpected cancellation: %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("cancellation timed out")
	}
}
