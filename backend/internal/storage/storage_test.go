package storage

import "testing"

func TestValidKey(t *testing.T) {
	for _, key := range []string{"project/123/file.pdf", "attachments/a/b.png"} {
		if !validKey(key) {
			t.Fatalf("valid key rejected: %q", key)
		}
	}
	for _, key := range []string{"", "/absolute/file.pdf", "../file.pdf", "project/../file.pdf", `project\file.pdf`} {
		if validKey(key) {
			t.Fatalf("unsafe key accepted: %q", key)
		}
	}
}
