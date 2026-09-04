package agent

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sync"

	"github.com/ue555/eiwa.nvim/internal/protocol"
	"github.com/ue555/eiwa.nvim/internal/provider"
)

type Server struct {
	provider provider.Provider

	mu      sync.Mutex
	output  sync.Mutex
	active  map[string]context.CancelFunc
	wg      sync.WaitGroup
	encoder *json.Encoder
}

func New(translationProvider provider.Provider) *Server {
	return &Server{
		provider: translationProvider,
		active:   make(map[string]context.CancelFunc),
	}
}

func (s *Server) Run(ctx context.Context, input io.Reader, output io.Writer) error {
	s.encoder = json.NewEncoder(output)
	scanner := bufio.NewScanner(input)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)

	for scanner.Scan() {
		var request protocol.Request
		if err := json.Unmarshal(scanner.Bytes(), &request); err != nil {
			s.emit(protocol.Event{Type: protocol.EventError, Message: "invalid request: " + err.Error()})
			continue
		}

		switch request.Type {
		case protocol.RequestSubmit:
			s.submit(ctx, request)
		case protocol.RequestCancel:
			s.cancel(request.ID)
		case protocol.RequestShutdown:
			s.shutdown()
			return nil
		default:
			s.emit(protocol.Event{
				Type:    protocol.EventError,
				ID:      request.ID,
				Message: fmt.Sprintf("unsupported request type %q", request.Type),
			})
		}
	}

	s.shutdown()
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read requests: %w", err)
	}
	return nil
}

func (s *Server) submit(parent context.Context, request protocol.Request) {
	if request.ID == "" {
		s.emit(protocol.Event{Type: protocol.EventError, Message: "submit request requires an id"})
		return
	}
	if request.Content == "" {
		s.emit(protocol.Event{Type: protocol.EventError, ID: request.ID, Message: "submit request requires content"})
		return
	}

	ctx, cancel := context.WithCancel(parent)
	s.mu.Lock()
	if _, exists := s.active[request.ID]; exists {
		s.mu.Unlock()
		cancel()
		s.emit(protocol.Event{Type: protocol.EventError, ID: request.ID, Message: "request id is already active"})
		return
	}
	s.active[request.ID] = cancel
	s.mu.Unlock()

	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		defer func() {
			s.mu.Lock()
			delete(s.active, request.ID)
			s.mu.Unlock()
			cancel()
		}()

		if err := s.emit(protocol.Event{Type: protocol.EventStarted, ID: request.ID}); err != nil {
			return
		}

		err := s.provider.Stream(ctx, request.Content, func(content string) error {
			return s.emit(protocol.Event{
				Type:    protocol.EventAssistantDelta,
				ID:      request.ID,
				Content: content,
			})
		})
		if errors.Is(err, context.Canceled) {
			s.emit(protocol.Event{Type: protocol.EventCancelled, ID: request.ID})
			return
		}
		if err != nil {
			s.emit(protocol.Event{Type: protocol.EventError, ID: request.ID, Message: err.Error()})
			return
		}
		s.emit(protocol.Event{Type: protocol.EventAssistantDone, ID: request.ID})
	}()
}

func (s *Server) cancel(id string) {
	s.mu.Lock()
	cancel := s.active[id]
	s.mu.Unlock()
	if cancel == nil {
		s.emit(protocol.Event{Type: protocol.EventError, ID: id, Message: "request is not active"})
		return
	}
	cancel()
}

func (s *Server) shutdown() {
	s.mu.Lock()
	for _, cancel := range s.active {
		cancel()
	}
	s.mu.Unlock()
	s.wg.Wait()
}

func (s *Server) emit(event protocol.Event) error {
	s.output.Lock()
	defer s.output.Unlock()
	return s.encoder.Encode(event)
}
