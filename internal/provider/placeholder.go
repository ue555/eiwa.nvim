package provider

import (
	"context"
	"time"
)

type Placeholder struct {
	Delay time.Duration
}

func (p Placeholder) Stream(ctx context.Context, _ string, emit func(string) error) error {
	chunks := []string{
		"Translation ",
		"backend ",
		"is not implemented yet.",
	}

	for index, chunk := range chunks {
		if index > 0 && p.Delay > 0 {
			timer := time.NewTimer(p.Delay)
			select {
			case <-ctx.Done():
				timer.Stop()
				return ctx.Err()
			case <-timer.C:
			}
		}
		if err := emit(chunk); err != nil {
			return err
		}
	}
	return nil
}
