package agent

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"strings"
	"testing"

	"github.com/ue555/eiwa.nvim/internal/protocol"
	"github.com/ue555/eiwa.nvim/internal/provider"
)

type providerFunc func(context.Context, string, func(string) error) error

func (fn providerFunc) Stream(ctx context.Context, content string, emit func(string) error) error {
	return fn(ctx, content, emit)
}

func TestSubmitStreamsEvents(t *testing.T) {
	input := strings.NewReader(`{"type":"submit","id":"request-1","content":"hello"}` + "\n")
	var output bytes.Buffer
	server := New(provider.Placeholder{})

	if err := server.Run(context.Background(), input, &output); err != nil {
		t.Fatal(err)
	}

	decoder := json.NewDecoder(&output)
	var events []protocol.Event
	for {
		var event protocol.Event
		if err := decoder.Decode(&event); err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			t.Fatal(err)
		}
		events = append(events, event)
	}

	if len(events) != 5 {
		t.Fatalf("got %d events, want 5: %#v", len(events), events)
	}
	if events[0].Type != protocol.EventStarted {
		t.Fatalf("first event = %q, want %q", events[0].Type, protocol.EventStarted)
	}
	if events[len(events)-1].Type != protocol.EventAssistantDone {
		t.Fatalf("last event = %q, want %q", events[len(events)-1].Type, protocol.EventAssistantDone)
	}

	var content strings.Builder
	for _, event := range events {
		if event.Type == protocol.EventAssistantDelta {
			content.WriteString(event.Content)
		}
	}
	if got, want := content.String(), "Translation backend is not implemented yet."; got != want {
		t.Fatalf("content = %q, want %q", got, want)
	}
}

func TestInvalidRequestReturnsError(t *testing.T) {
	input := strings.NewReader(`{"type":"unknown","id":"request-1"}` + "\n")
	var output bytes.Buffer
	server := New(provider.Placeholder{})

	if err := server.Run(context.Background(), input, &output); err != nil {
		t.Fatal(err)
	}

	var event protocol.Event
	if err := json.NewDecoder(&output).Decode(&event); err != nil {
		t.Fatal(err)
	}
	if event.Type != protocol.EventError {
		t.Fatalf("event type = %q, want %q", event.Type, protocol.EventError)
	}
}

func TestCancelStopsActiveRequest(t *testing.T) {
	input := strings.NewReader(
		`{"type":"submit","id":"request-1","content":"hello"}` + "\n" +
			`{"type":"cancel","id":"request-1"}` + "\n",
	)
	var output bytes.Buffer
	blocking := providerFunc(func(ctx context.Context, _ string, _ func(string) error) error {
		<-ctx.Done()
		return ctx.Err()
	})
	server := New(blocking)

	if err := server.Run(context.Background(), input, &output); err != nil {
		t.Fatal(err)
	}

	decoder := json.NewDecoder(&output)
	var event protocol.Event
	var cancelled bool
	for {
		if err := decoder.Decode(&event); err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			t.Fatal(err)
		}
		if event.Type == protocol.EventCancelled {
			cancelled = true
		}
	}
	if !cancelled {
		t.Fatal("cancelled event was not emitted")
	}
}
