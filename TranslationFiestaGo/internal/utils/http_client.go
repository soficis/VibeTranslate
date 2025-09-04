package utils

import (
	"context"
	"crypto/tls"
	"time"

	"github.com/go-resty/resty/v2"
)

// HTTPClient wraps the resty client with custom configuration
type HTTPClient struct {
	client *resty.Client
}

// NewHTTPClient creates a new HTTP client instance
func NewHTTPClient() *HTTPClient {
	client := resty.New()

	// Configure timeouts
	client.SetTimeout(30 * time.Second)
	client.SetRetryCount(3)
	client.SetRetryWaitTime(2 * time.Second)
	client.SetRetryMaxWaitTime(10 * time.Second)

	// Configure TLS
	client.SetTLSClientConfig(&tls.Config{
		InsecureSkipVerify: false,
	})

	// Set common headers
	client.SetHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")

	return &HTTPClient{
		client: client,
	}
}

// Get performs a GET request
func (hc *HTTPClient) Get(ctx context.Context, url string) (*resty.Response, error) {
	return hc.client.R().
		SetContext(ctx).
		Get(url)
}

// Post performs a POST request
func (hc *HTTPClient) Post(ctx context.Context, url string, body interface{}) (*resty.Response, error) {
	return hc.client.R().
		SetContext(ctx).
		SetBody(body).
		Post(url)
}

// SetHeader sets a header for all requests
func (hc *HTTPClient) SetHeader(key, value string) *HTTPClient {
	hc.client.SetHeader(key, value)
	return hc
}

// SetTimeout sets the request timeout
func (hc *HTTPClient) SetTimeout(timeout time.Duration) *HTTPClient {
	hc.client.SetTimeout(timeout)
	return hc
}
