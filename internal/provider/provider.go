package provider

import "context"

type Provider interface {
	Stream(ctx context.Context, content string, emit func(string) error) error
}
