package registry

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"
)

type ServiceType int

const (
	Required  ServiceType = iota // app cannot function without
	Optional                    // UI degrades gracefully
	Enhanced                    // only when connected
)

type ServiceInfo struct {
	Name         string      `json:"name"`
	Host         string      `json:"host"`
	Type         ServiceType `json:"type"`
	Dependencies []string    `json:"dependencies"`
}

type HealthStatus struct {
	Service  string `json:"service"`
	Status   string `json:"status"` // connected, disconnected, error
	Latency  int64  `json:"latency_ms"`
	Ready    bool   `json:"ready"`
}

type ServiceClient interface {
	Connect() error
	Disconnect() error
	Health() *HealthStatus
	Name() string
}

type Registry struct {
	mu      sync.RWMutex
	clients map[string]ServiceClient
	infos   map[string]*ServiceInfo
	healthy map[string]bool
}

func NewRegistry() *Registry {
	return &Registry{
		clients: make(map[string]ServiceClient),
		infos:   make(map[string]*ServiceInfo),
		healthy: make(map[string]bool),
	}
}

func (r *Registry) Register(info *ServiceInfo, client ServiceClient) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.infos[info.Name] = info
	r.clients[info.Name] = client
}

func (r *Registry) ConnectAll() error {
	r.mu.RLock()
	defer r.mu.RUnlock()

	// Connect in dependency order: Required → Optional → Enhanced
	for _, t := range []ServiceType{Required, Optional, Enhanced} {
		for name, client := range r.clients {
			if r.infos[name].Type != t {
				continue
			}
			if err := client.Connect(); err != nil {
				if t == Required {
					return fmt.Errorf("required service %s: %w", name, err)
				}
				log.Printf("optional service %s unavailable: %v (degraded mode)", name, err)
				r.healthy[name] = false
				continue
			}
			r.healthy[name] = true
		}
	}
	return nil
}

func (r *Registry) HealthCheck(ctx time.Duration) map[string]*HealthStatus {
	r.mu.RLock()
	defer r.mu.RUnlock()

	results := make(map[string]*HealthStatus)
	for name, client := range r.clients {
		start := time.Now()
		status := client.Health()
		status.Latency = time.Since(start).Milliseconds()
		results[name] = status

		r.mu.Lock()
		r.healthy[name] = status.Status == "connected"
		r.mu.Unlock()
	}
	return results
}

func (r *Registry) IsHealthy(name string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.healthy[name]
}

func (r *Registry) HealthyCount() (required, optional int) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for name, healthy := range r.healthy {
		if r.infos[name].Type == Required && healthy {
			required++
		}
		if r.infos[name].Type != Required && healthy {
			optional++
		}
	}
	return
}

// HTTPHealthHandler returns an HTTP handler that reports aggregate health.
func (r *Registry) HTTPHealthHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, req *http.Request) {
		statuses := r.HealthCheck(5 * time.Second)
		allReady := true
		for name, s := range statuses {
			if r.infos[name].Type == Required && s.Status != "connected" {
				allReady = false
			}
		}

		w.Header().Set("Content-Type", "application/json")
		if allReady {
			w.WriteHeader(http.StatusOK)
		} else {
			w.WriteHeader(http.StatusServiceUnavailable)
		}
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":      map[bool]string{true: "ok", false: "degraded"}[allReady],
			"services":    statuses,
		})
	}
}

// SimpleClient is an HTTP-based client for any REST service.
type SimpleClient struct {
	Name   string
	Host   string
	client *http.Client
}

func NewSimpleClient(name, host string) *SimpleClient {
	return &SimpleClient{
		Name: name,
		Host: host,
		client: &http.Client{Timeout: 5 * time.Second},
	}
}

func (c *SimpleClient) Connect() error {
	// Just verify reachability
	resp, err := c.client.Get(fmt.Sprintf("http://%s/health/live", c.Host))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health check returned %d", resp.StatusCode)
	}
	return nil
}

func (c *SimpleClient) Disconnect() error {
	c.client.CloseIdleConnections()
	return nil
}

func (c *SimpleClient) Health() *HealthStatus {
	resp, err := c.client.Get(fmt.Sprintf("http://%s/health/ready", c.Host))
	if err != nil {
		return &HealthStatus{
			Service: c.Name,
			Status:  "disconnected",
		}
	}
	defer resp.Body.Close()
	return &HealthStatus{
		Service: c.Name,
		Status:  "connected",
		Ready:   resp.StatusCode == http.StatusOK,
	}
}

func (c *SimpleClient) ServiceName() string { return c.Name }

func (c *SimpleClient) Get(path string) ([]byte, error) {
	resp, err := c.client.Get(fmt.Sprintf("http://%s%s", c.Host, path))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}

func (c *SimpleClient) Post(path string, body io.Reader) ([]byte, error) {
	resp, err := c.client.Post(
		fmt.Sprintf("http://%s%s", c.Host, path),
		"application/json", body,
	)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}
