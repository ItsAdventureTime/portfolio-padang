package email

import (
	"context"
	"log/slog"
)

type Message struct{ To, Subject, Text, HTML, IdempotencyKey string }

type Sender interface {
	Send(context.Context, Message) error
}

type LogSender struct{ Logger *slog.Logger }

func (s LogSender) Send(_ context.Context, message Message) error {
	s.Logger.Info("email suppressed by log provider", "to", message.To, "subject", message.Subject, "idempotency_key", message.IdempotencyKey)
	return nil
}
