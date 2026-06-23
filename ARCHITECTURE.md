# NotJustDex Architecture Contract

Every module MUST be connectable and disconnectable. This document defines the dependency graph,
graceful degradation contracts, and wiring interface for every service and package.

---

## 1. Service Dependency Graph

```
Required ─── App cannot start or is unusable without this
Optional ─── UI tab/feature disappears; app still functional
Enhanced ─── Visible only when connected; no degradation
```

### Go Services

| Service | Type | Dependencies | When Disconnected |
|---------|------|-------------|-------------------|
| `auth` | Required | none | Login/register unavailable |
| `users` | Required | `auth` | No profile, no wallet |
| `chat` | Optional | `users`, `notifications` | Chat tab hidden |
| `feed` | Optional | `users` | Feed tab hidden |
| `notifications` | Optional | none | Activity tab shows "offline" state |
| `media` | Optional | `users` | Video/image upload falls back to URL paste |
| `moderation` | Optional | none | Content posted unchecked; flagged later |
| `search` | Enhanced | `users` | Search bar uses local index |
| `creator_economy` | Enhanced | `users` | Tip/subscribe buttons hidden |
| `analytics` | Enhanced | none | Tracking silently dropped |
| `dao` | Enhanced | `users` | DAO tab hidden |

### Flutter Packages

| Package | Type | Fallback |
|---------|------|----------|
| `identity_kernel` | Required | — |
| `design_system` | Required | Material 3 defaults |
| `in_app_browser` | Optional | Opens URL in system browser |
| `mini_app_runtime` | Optional | Mini app store tab hidden |

### Flutter UI Modules (by tab)

| Tab | Service | Disconnected Behavior |
|-----|---------|----------------------|
| Feed | `feed` | Empty state: "Connect to see content" + retry button |
| Chat | `chat` | Tab hidden; bottom nav shows 4 tabs |
| Discover | — | Works offline (installed apps); store disabled |
| Activity | `notifications` | Empty state: "Notifications offline" |
| Profile | `users` | Cached profile; toast "Could not update" |

---

## 2. Connect/Disconnect Contract

### Every Go service exposes:
```
GET  /health          → {"status":"ok","dependencies":{...}}
GET  /health/ready    → 200 when all required deps are up
GET  /health/live     → 200 when process is alive
```

### Every Go client implements:
```
Connect() error           // dial + handshake
Disconnect() error        // graceful shutdown
Health() HealthStatus     // connection state
```

### Graceful degradation macros:
```go
// CallWithFallback tries primary, then fallback, then returns error
func CallWithFallback[T any](primary, fallback func() (T, error)) (T, error)
```

---

## 3. Wiring Interface

### Go: ServiceClient interface

```go
type ServiceClient interface {
    Connect() error
    Disconnect() error
    Health() *HealthStatus
    Name() string
}

type HealthStatus struct {
    Service  string `json:"service"`
    Status   string `json:"status"` // connected, disconnected, error
    Latency  int64  `json:"latency_ms"`
}
```

### Flutter: Module interface

```dart
abstract class AppModule {
  String get name;
  bool get isAvailable;        // based on feature flag + connectivity
  Widget? get tabWidget;       // null = hide from nav entirely
  Map<String, GoRoute> get routes;  // empty = no routes added
  Future<void> onConnect();    // called when backend available
  void onDisconnect();         // called when connection lost
}
```

### Each module controls its own routes + tab visibility.
### Router is built at startup by scanning all registered modules.

---

## 4. State Flow

```
App Start
  ├─ Load feature flags (YAML/env)
  ├─ Health check each service in dependency order
  │   ├─ If Required fails → show error screen + retry
  │   ├─ If Optional fails → set flag "disconnected"
  │   └─ If Enhanced fails → silent disable
  ├─ Build router from enabled modules
  ├─ Build bottom nav from enabled tab modules
  └─ Enter HomeShell
       │
       ├─ Each module subscribes to connectivity changes
       ├─ On reconnect → refresh data, show snackbar
       └─ On disconnect → show offline state, queue writes
```

---

## 5. Feature Flag System

```yaml
# config/features.yaml — loaded at app start
features:
  feed:
    enabled: true
    service_host: "feed:8083"
  chat:
    enabled: true
    service_host: "chat:8085"
  mini_apps:
    enabled: true
  notifications:
    enabled: true
  creator_economy:
    enabled: false  # launch gate
```

Each module reads its flag and self-configures. No hardcoded dependencies.

---

## 6. Degradation Examples

### Chat tab when `chat` service is down:
- Bottom nav shows 4 tabs (no Chat)
- If user navigates to /chat directly → redirects to /home
- Incoming messages queued in local Hive/Isar; sent when reconnected

### Feed when `feed` service is down:
- Feed tab shows cached items from last session
- Pull-to-refresh shows "Feed unavailable — pull to retry"
- New feed items queued locally

### Notifications when disconnected:
- Activity tab shows "Notifications offline" with reconnect button
- Unread badge shows 0
- Notifications queued server-side; delivered on reconnect

### Mini apps when `mini_app_runtime` package not installed:
- Discover tab still shows search + store
- Mini app cards in feed show "Open in App Store" instead
- Mini app store page hidden
