package email

import (
	"context"

	resend "github.com/resend/resend-go/v3"
)

type ResendSender struct {
	Client *resend.Client
	From   string
}

func NewResendSender(apiKey, from string) *ResendSender {
	return &ResendSender{Client: resend.NewClient(apiKey), From: from}
}

func (s ResendSender) Send(_ context.Context, message Message) error {
	_, err := s.Client.Emails.Send(&resend.SendEmailRequest{From: s.From, To: []string{message.To}, Subject: message.Subject, Text: message.Text, Html: message.HTML, Headers: map[string]string{"Idempotency-Key": message.IdempotencyKey}})
	return err
}
