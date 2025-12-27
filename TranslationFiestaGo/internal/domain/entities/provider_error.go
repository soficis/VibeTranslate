package entities

import "fmt"

type ProviderError struct {
	Code    string
	Message string
}

func (e ProviderError) Error() string {
	if e.Code == "" {
		return e.Message
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}
