package services

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/utils"
)

const defaultLocalServiceURL = "http://127.0.0.1:5055"
const defaultLocalServiceScript = "TranslationFiestaLocal/local_service.py"

type LocalServiceClient struct {
	httpClient *utils.HTTPClient
	logger     *utils.Logger
	baseURL    string
	autoStart  bool
	startMu    sync.Mutex
	started    bool
}

type localServiceError struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	Retryable bool   `json:"retryable"`
}

type localTranslateResponse struct {
	TranslatedText string             `json:"translated_text"`
	SourceLang     string             `json:"source_lang"`
	TargetLang     string             `json:"target_lang"`
	Backend        string             `json:"backend"`
	Error          *localServiceError `json:"error,omitempty"`
}

type localHealthResponse struct {
	Status  string `json:"status"`
	Backend string `json:"backend"`
}

func NewLocalServiceClient(httpClient *utils.HTTPClient) *LocalServiceClient {
	client := &LocalServiceClient{
		httpClient: httpClient,
		logger:     utils.GetLogger(),
	}
	client.refreshFromEnv()
	return client
}

func (c *LocalServiceClient) Translate(ctx context.Context, text, sourceLang, targetLang string) (*entities.TranslationResult, error) {
	c.refreshFromEnv()
	if err := c.ensureAvailable(ctx); err != nil {
		return nil, err
	}

	payload := map[string]string{
		"text":        text,
		"source_lang": sourceLang,
		"target_lang": targetLang,
	}

	resp, err := c.httpClient.Post(ctx, c.baseURL+"/translate", payload)
	if err != nil {
		return nil, fmt.Errorf("local service request failed: %w", err)
	}

	if resp.StatusCode() != 200 {
		return nil, c.parseError(resp.Body(), resp.StatusCode())
	}

	var parsed localTranslateResponse
	if err := json.Unmarshal(resp.Body(), &parsed); err != nil {
		return nil, fmt.Errorf("local service response invalid: %w", err)
	}
	if parsed.Error != nil {
		return nil, fmt.Errorf("local service error: %s", parsed.Error.Message)
	}

	translated := strings.TrimSpace(parsed.TranslatedText)
	if translated == "" {
		return nil, fmt.Errorf("local service returned empty translation")
	}

	resSource := parsed.SourceLang
	if resSource == "" {
		resSource = sourceLang
	}
	resTarget := parsed.TargetLang
	if resTarget == "" {
		resTarget = targetLang
	}

	return &entities.TranslationResult{
		TranslatedText: translated,
		SourceLang:     resSource,
		TargetLang:     resTarget,
		Timestamp:      time.Now(),
	}, nil
}

func (c *LocalServiceClient) ModelsStatus(ctx context.Context) (string, error) {
	c.refreshFromEnv()
	if err := c.ensureAvailable(ctx); err != nil {
		return "", err
	}
	resp, err := c.httpClient.Get(ctx, c.baseURL+"/models")
	if err != nil {
		return "", fmt.Errorf("local models status failed: %w", err)
	}
	if resp.StatusCode() != 200 {
		return "", c.parseError(resp.Body(), resp.StatusCode())
	}
	return string(resp.Body()), nil
}

func (c *LocalServiceClient) ModelsVerify(ctx context.Context) (string, error) {
	c.refreshFromEnv()
	if err := c.ensureAvailable(ctx); err != nil {
		return "", err
	}
	resp, err := c.httpClient.Post(ctx, c.baseURL+"/models/verify", map[string]string{})
	if err != nil {
		return "", fmt.Errorf("local models verify failed: %w", err)
	}
	if resp.StatusCode() != 200 {
		return "", c.parseError(resp.Body(), resp.StatusCode())
	}
	return string(resp.Body()), nil
}

func (c *LocalServiceClient) ModelsRemove(ctx context.Context) (string, error) {
	c.refreshFromEnv()
	if err := c.ensureAvailable(ctx); err != nil {
		return "", err
	}
	resp, err := c.httpClient.Post(ctx, c.baseURL+"/models/remove", map[string]string{})
	if err != nil {
		return "", fmt.Errorf("local models remove failed: %w", err)
	}
	if resp.StatusCode() != 200 {
		return "", c.parseError(resp.Body(), resp.StatusCode())
	}
	return string(resp.Body()), nil
}

func (c *LocalServiceClient) ModelsInstallDefault(ctx context.Context) (string, error) {
	c.refreshFromEnv()
	if err := c.ensureAvailable(ctx); err != nil {
		return "", err
	}
	resp, err := c.httpClient.Post(ctx, c.baseURL+"/models/install", map[string]string{})
	if err != nil {
		return "", fmt.Errorf("local models install failed: %w", err)
	}
	if resp.StatusCode() != 200 {
		return "", c.parseError(resp.Body(), resp.StatusCode())
	}
	return string(resp.Body()), nil
}

func (c *LocalServiceClient) ensureAvailable(ctx context.Context) error {
	c.refreshFromEnv()
	if err := c.checkHealth(ctx); err == nil {
		return nil
	}
	if !c.autoStart {
		return fmt.Errorf("local service unavailable and autostart disabled")
	}

	if err := c.startLocalService(); err != nil {
		return err
	}

	return c.waitForHealth(ctx, 10, 250*time.Millisecond)
}

func (c *LocalServiceClient) waitForHealth(ctx context.Context, attempts int, delay time.Duration) error {
	var lastErr error
	for i := 0; i < attempts; i++ {
		if err := c.checkHealth(ctx); err == nil {
			return nil
		} else {
			lastErr = err
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(delay):
		}
	}
	if lastErr != nil {
		return lastErr
	}
	return fmt.Errorf("local service did not become healthy")
}

func (c *LocalServiceClient) checkHealth(ctx context.Context) error {
	c.refreshFromEnv()
	resp, err := c.httpClient.Get(ctx, c.baseURL+"/health")
	if err != nil {
		return fmt.Errorf("local service health check failed: %w", err)
	}
	if resp.StatusCode() != 200 {
		return fmt.Errorf("local service health check HTTP %d", resp.StatusCode())
	}
	var payload localHealthResponse
	if err := json.Unmarshal(resp.Body(), &payload); err != nil {
		return fmt.Errorf("local service health response invalid: %w", err)
	}
	if strings.ToLower(payload.Status) != "ok" {
		return fmt.Errorf("local service status %s", payload.Status)
	}
	return nil
}

func (c *LocalServiceClient) refreshFromEnv() {
	baseURL := strings.TrimSpace(os.Getenv("TF_LOCAL_URL"))
	if baseURL == "" {
		baseURL = defaultLocalServiceURL
	}
	c.baseURL = strings.TrimRight(baseURL, "/")

	autoStart := true
	if raw, ok := os.LookupEnv("TF_LOCAL_AUTOSTART"); ok {
		value := strings.ToLower(strings.TrimSpace(raw))
		if value == "0" || value == "false" || value == "no" {
			autoStart = false
		}
	}
	c.autoStart = autoStart
}

func (c *LocalServiceClient) startLocalService() error {
	c.startMu.Lock()
	defer c.startMu.Unlock()

	if c.started {
		return nil
	}

	scriptPath := strings.TrimSpace(os.Getenv("TF_LOCAL_SCRIPT"))
	if scriptPath == "" {
		scriptPath = defaultLocalServiceScript
	}
	scriptPath = filepath.Clean(scriptPath)
	if !filepath.IsAbs(scriptPath) {
		if cwd, err := os.Getwd(); err == nil {
			scriptPath = filepath.Join(cwd, scriptPath)
		}
	}

	python := strings.TrimSpace(os.Getenv("PYTHON"))
	if python == "" {
		python = "python"
	}

	cmd := exec.Command(python, scriptPath, "serve")
	cmd.Env = os.Environ()
	cmd.Dir = filepath.Dir(scriptPath)
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start local service: %w", err)
	}
	_ = cmd.Process.Release()
	c.started = true
	c.logger.Info("Local service start requested: %s", scriptPath)
	return nil
}

func (c *LocalServiceClient) parseError(body []byte, statusCode int) error {
	var payload struct {
		Error *localServiceError `json:"error"`
	}
	if err := json.Unmarshal(body, &payload); err == nil && payload.Error != nil {
		return fmt.Errorf("local service error (%s): %s", payload.Error.Code, payload.Error.Message)
	}
	return fmt.Errorf("local service HTTP %d", statusCode)
}
