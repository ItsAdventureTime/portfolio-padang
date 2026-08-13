package httpapi

import "testing"

func TestAttachmentObjectValidation(t *testing.T) {
	if contentType, extension, ok := attachmentObject("drawing.pdf", "application/pdf", 1024); !ok || contentType != "application/pdf" || extension != ".pdf" {
		t.Fatalf("valid attachment rejected: %q %q %v", contentType, extension, ok)
	}
	for _, input := range []struct {
		name, contentType string
		size              int64
	}{
		{"../drawing.pdf", "application/pdf", 1024},
		{"drawing.exe", "application/pdf", 1024},
		{"drawing.pdf", "application/pdf", maxAttachmentSize + 1},
		{"drawing.pdf", "application/octet-stream", 1024},
	} {
		if _, _, ok := attachmentObject(input.name, input.contentType, input.size); ok {
			t.Fatalf("invalid attachment accepted: %#v", input)
		}
	}
}
