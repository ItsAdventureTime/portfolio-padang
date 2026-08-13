package storage

import (
	"context"
	"errors"
	"path"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/itsadventuretime/padang-erp/backend/internal/config"
)

var ErrNotConfigured = errors.New("B2 storage is not configured")
var ErrInvalidObject = errors.New("invalid storage object")

type Object struct {
	Key, ContentType string
	Size             int64
}

type Service interface {
	PresignUpload(context.Context, Object) (string, error)
	PresignDownload(context.Context, string) (string, error)
}

type B2S3Service struct {
	Endpoint, Bucket, Prefix string
	Configured               bool
	presigner                *s3.PresignClient
}

func NewB2Service(ctx context.Context, cfg config.Config) (B2S3Service, error) {
	if strings.TrimSpace(cfg.B2KeyID) == "" || strings.TrimSpace(cfg.B2ApplicationKey) == "" {
		return B2S3Service{Endpoint: cfg.B2Endpoint, Bucket: cfg.B2Bucket, Prefix: cfg.B2Prefix}, nil
	}
	awsCfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion("us-west-001"), awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(cfg.B2KeyID, cfg.B2ApplicationKey, "")))
	if err != nil {
		return B2S3Service{}, err
	}
	client := s3.NewFromConfig(awsCfg, func(options *s3.Options) {
		options.BaseEndpoint = aws.String(cfg.B2Endpoint)
		options.UsePathStyle = true
	})
	return B2S3Service{Endpoint: cfg.B2Endpoint, Bucket: cfg.B2Bucket, Prefix: cfg.B2Prefix, Configured: true, presigner: s3.NewPresignClient(client)}, nil
}

func (s B2S3Service) PresignUpload(ctx context.Context, object Object) (string, error) {
	if !s.Configured || s.presigner == nil {
		return "", ErrNotConfigured
	}
	if object.Size <= 0 || object.Size > 50*1024*1024 || strings.TrimSpace(object.ContentType) == "" || !validKey(object.Key) {
		return "", ErrInvalidObject
	}
	key := strings.TrimPrefix(s.Prefix+object.Key, "/")
	result, err := s.presigner.PresignPutObject(ctx, &s3.PutObjectInput{Bucket: aws.String(s.Bucket), Key: aws.String(key), ContentType: aws.String(object.ContentType), ContentLength: aws.Int64(object.Size)}, s3.WithPresignExpires(time.Hour))
	if err != nil {
		return "", err
	}
	return result.URL, nil
}

func validKey(key string) bool {
	return key != "" && !strings.HasPrefix(key, "/") && !strings.Contains(key, "\\") && path.Clean(key) == key && !strings.Contains(key, "..")
}

func (s B2S3Service) PresignDownload(ctx context.Context, key string) (string, error) {
	if !s.Configured || s.presigner == nil {
		return "", ErrNotConfigured
	}
	key = strings.TrimPrefix(s.Prefix+key, "/")
	result, err := s.presigner.PresignGetObject(ctx, &s3.GetObjectInput{Bucket: aws.String(s.Bucket), Key: aws.String(key)}, s3.WithPresignExpires(time.Hour))
	if err != nil {
		return "", err
	}
	return result.URL, nil
}
