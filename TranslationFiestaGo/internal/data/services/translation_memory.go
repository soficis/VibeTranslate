package services

import (
	"container/list"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"translationfiestago/internal/domain/entities"
)

// TranslationMemory stores previously translated strings with LRU caching.
type TranslationMemory struct {
	cache           map[string]*list.Element
	lruList         *list.List
	cacheSize       int
	persistencePath string
	metrics         TMetrics
}

type TMEntry struct {
	Source      string    `json:"source"`
	Translation string    `json:"translation"`
	TargetLang  string    `json:"target_lang"`
	ProviderID  string    `json:"provider_id"`
	AccessTime  time.Time `json:"access_time"`
}

type TMetrics struct {
	Hits         int     `json:"hits"`
	Misses       int     `json:"misses"`
	TotalLookups int     `json:"total_lookups"`
	TotalTime    float64 `json:"total_time"`
}

func NewTranslationMemory(cacheSize int, persistencePath string) *TranslationMemory {
	tm := &TranslationMemory{
		cache:           make(map[string]*list.Element),
		lruList:         list.New(),
		cacheSize:       cacheSize,
		persistencePath: persistencePath,
		metrics:         TMetrics{},
	}
	tm.loadCache()
	return tm
}

func (tm *TranslationMemory) getKey(source, targetLang, providerID string) string {
	return source + ":" + targetLang + ":" + providerID
}

func (tm *TranslationMemory) Lookup(source, targetLang, providerID string) (string, bool) {
	key := tm.getKey(source, targetLang, providerID)
	if elem, exists := tm.cache[key]; exists {
		tm.lruList.MoveToFront(elem)
		tm.metrics.Hits++
		tm.metrics.TotalLookups++
		return elem.Value.(*TMEntry).Translation, true
	}
	tm.metrics.Misses++
	tm.metrics.TotalLookups++
	return "", false
}

func (tm *TranslationMemory) Store(source, targetLang, providerID, translation string) {
	key := tm.getKey(source, targetLang, providerID)
	entry := &TMEntry{
		Source:      source,
		Translation: translation,
		TargetLang:  targetLang,
		ProviderID:  providerID,
		AccessTime:  time.Now(),
	}

	if elem, exists := tm.cache[key]; exists {
		tm.lruList.MoveToFront(elem)
		elem.Value = entry
	} else {
		newElem := tm.lruList.PushFront(entry)
		tm.cache[key] = newElem
		if tm.lruList.Len() > tm.cacheSize {
			last := tm.lruList.Back()
			if last != nil {
				delete(tm.cache, tm.getKey(last.Value.(*TMEntry).Source, last.Value.(*TMEntry).TargetLang, last.Value.(*TMEntry).ProviderID))
				tm.lruList.Remove(last)
			}
		}
	}
	tm.persist()
}

func (tm *TranslationMemory) GetStats() map[string]interface{} {
	stats := make(map[string]interface{})
	stats["hits"] = tm.metrics.Hits
	stats["misses"] = tm.metrics.Misses
	stats["total_lookups"] = tm.metrics.TotalLookups
	stats["hit_rate"] = float64(tm.metrics.Hits) / float64(max(1, tm.metrics.TotalLookups))
	stats["avg_lookup_time"] = tm.metrics.TotalTime / float64(max(1, tm.metrics.TotalLookups))
	stats["cache_size"] = tm.lruList.Len()
	stats["max_size"] = tm.cacheSize
	return stats
}

func (tm *TranslationMemory) ClearCache() {
	tm.cache = make(map[string]*list.Element)
	tm.lruList.Init()
	tm.metrics = TMetrics{}
	tm.persist()
}

func (tm *TranslationMemory) persist() {
	data := map[string]interface{}{
		"config": map[string]interface{}{
			"max_size": tm.cacheSize,
		},
		"cache":   []TMEntry{},
		"metrics": tm.metrics,
	}

	for elem := tm.lruList.Front(); elem != nil; elem = elem.Next() {
		data["cache"] = append(data["cache"].([]TMEntry), *elem.Value.(*TMEntry))
	}

	bytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fmt.Printf("Failed to marshal cache: %v\\n", err)
		return
	}

	if err := os.WriteFile(tm.persistencePath, bytes, 0644); err != nil {
		fmt.Printf("Failed to write cache file: %v\\n", err)
	}
}

func (tm *TranslationMemory) loadCache() {
	bytes, err := os.ReadFile(tm.persistencePath)
	if err != nil {
		if !os.IsNotExist(err) {
			fmt.Printf("Failed to read cache file: %v\\n", err)
		}
		return
	}

	var data map[string]interface{}
	if err := json.Unmarshal(bytes, &data); err != nil {
		fmt.Printf("Failed to unmarshal cache: %v\\n", err)
		return
	}

	if config, ok := data["config"].(map[string]interface{}); ok {
		if size, ok := config["max_size"].(float64); ok {
			tm.cacheSize = int(size)
		}
	}

	if metricsData, ok := data["metrics"].(map[string]interface{}); ok {
		if h, ok := metricsData["hits"].(float64); ok {
			tm.metrics.Hits = int(h)
		}
		if m, ok := metricsData["misses"].(float64); ok {
			tm.metrics.Misses = int(m)
		}
		if tl, ok := metricsData["total_lookups"].(float64); ok {
			tm.metrics.TotalLookups = int(tl)
		}
		if tt, ok := metricsData["total_time"].(float64); ok {
			tm.metrics.TotalTime = tt
		}
	}

	tm.cache = make(map[string]*list.Element)
	tm.lruList = list.New()
	for _, entryData := range data["cache"].([]interface{}) {
		entryMap := entryData.(map[string]interface{})
		t, err := time.Parse(time.RFC3339, entryMap["access_time"].(string))
		if err != nil {
			continue
		}
		entry := &TMEntry{
			Source:      entryMap["source"].(string),
			Translation: entryMap["translation"].(string),
			TargetLang:  entryMap["target_lang"].(string),
			AccessTime:  t,
		}
		entry.ProviderID, _ = entryMap["provider_id"].(string)
		entry.ProviderID = entities.NormalizeProviderID(entry.ProviderID)
		key := tm.getKey(entry.Source, entry.TargetLang, entry.ProviderID)
		elem := tm.lruList.PushFront(entry)
		tm.cache[key] = elem
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
