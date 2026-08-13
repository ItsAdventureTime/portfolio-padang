package openapi

import (
	"encoding/json"
	"fmt"

	_ "embed"
	"gopkg.in/yaml.v3"
)

// Document is the canonical API contract served by the runtime endpoint.
// Keep openapi.yaml as the single source for generated client types and docs.
//
//go:embed openapi.yaml
var Document []byte

func JSON() ([]byte, error) {
	var value any
	if err := yaml.Unmarshal(Document, &value); err != nil {
		return nil, err
	}
	value = normalize(value)
	encoded, err := json.Marshal(value)
	if err != nil {
		return nil, fmt.Errorf("encode OpenAPI document: %w", err)
	}
	return encoded, nil
}

func normalize(value any) any {
	switch typed := value.(type) {
	case map[string]any:
		result := make(map[string]any, len(typed))
		for key, item := range typed {
			result[key] = normalize(item)
		}
		return result
	case map[any]any:
		result := make(map[string]any, len(typed))
		for key, item := range typed {
			result[fmt.Sprint(key)] = normalize(item)
		}
		return result
	case []any:
		for index := range typed {
			typed[index] = normalize(typed[index])
		}
	}
	return value
}
