# Configuration Reference

All configuration lives in `config/config.yaml`. Environment variable substitution is supported: write `${MY_VAR}` and it will be replaced with the value from `.env` or the process environment.

---

## `application`

```yaml
application:
  name: "Smart Saw Control System"
  version: "2.0.0"
  debug: false        # Enables verbose debug logging
  log_level: "INFO"   # DEBUG | INFO | WARNING | ERROR | CRITICAL
```

---

## `gui`

```yaml
gui:
  enabled: true       # false = headless mode (no window)
  window_title: "Smart Band Saw Control System"
  window_width: 1200  # Note: GUI layout is hard-coded for 1920×1080
  window_height: 800
```

> The GUI is designed for a 1920×1080 touchscreen. The `window_width` / `window_height` settings are currently informational; all widget geometries are absolute pixel values.

---

## `modbus`

```yaml
modbus:
  host: "192.168.1.147"   # PLC IP address — change this for your network
  port: 502               # Standard Modbus TCP port
  timeout: 1.0            # Seconds before a read/write times out
  retry_count: 3
  retry_delay: 1.0
  connect_cooldown: 1.0   # Minimum seconds between reconnection attempts

  read_rate: 10           # Target reads per second (Hz)
  write_rate: 10          # Target writes per second (Hz)
  read_rate_alarm_low: 6  # Log a warning if actual rate drops below this
  write_rate_alarm_low: 5
```

### Register address map

The `registers:` section maps human-readable names to Modbus holding register addresses. These are used by `ModbusReader` and `ModbusWriter`. The PLC encodes decimal values as integers (multiply by 10 or 100), which the reader undoes during scaling.

Key registers:

| Name | Address | Description |
|------|---------|-------------|
| `KAFA_YUKSEKLIK` | 2000 | Head height (raw = mm × 10) |
| `SERIT_MOTOR_AKIM` | 2010 | Band motor current (raw = A × 10) |
| `SERIT_MOTOR_TORK` | 2011 | Band motor torque (raw = % × 10) |
| `INME_MOTOR_AKIM` | 2012 | Descent motor current (raw = A × 10) |
| `TESTERE_DURUMU` | 2030 | Saw state (0–6 integer) |
| `ALARM_STATUS` | 2031 | Fault active flag |
| `ALARM_BILGISI` | 2032 | Alarm bitmask (hex) |
| `INME_HIZI` | 2041 | Descent speed feedback (raw = mm/min × 100) |
| `KESME_HIZI` | 2066 | Cutting speed feedback (raw = mm/min × 10) |

See the full register map in `docs/08-plc-registers.md`.

---

## `control`

```yaml
control:
  default_mode: "manual"   # "manual" or "ml" at startup

  speed_limits:
    kesme_hizi:            # Band cutting speed
      min: 40.0            # m/min
      max: 90.0
    inme_hizi:             # Descent speed
      min: 10.0            # mm/min
      max: 60.0

  speed_presets:           # GUI "Slow / Normal / Fast" buttons
    slow:
      cutting: 46.0        # m/min
      descent: 16.0        # mm/min
    normal:
      cutting: 58.0
      descent: 20.0
    fast:
      cutting: 70.0
      descent: 24.0

  initial_delay:
    enabled: true
    default_delay_ms: 30000   # 30 seconds if inme_hizi is unknown
    min_delay_ms: 5000        # Always wait at least 5 seconds
    target_distance_mm: 25    # Also wait until 25mm of descent
```

The **initial delay** prevents ML from activating on the first millimetres of a cut, where the saw is still entering the material and readings are unstable.

---

## `ml`

```yaml
ml:
  model_path: "data/models/Bagging_dataset_v17_20250509.pkl"
  enabled: true

  katsayi: 1.0              # Global speed multiplier applied to all ML outputs
  min_speed_update_interval: 0.2  # Minimum seconds between speed writes

  buffer_size: 3            # Number of recent samples averaged before ML inference
  torque_buffer_size: 3

  torque_guard:
    enabled: true
    activation_delay_seconds: 5.0     # Wait after ML activates before Torque Guard starts
    height_threshold_mm: 2.5          # Skip first 2.5mm of descent history
    height_lookback_mm: 2.5           # Compare torque against 2.5mm ago
    torque_increase_threshold: 40.0   # Trigger if torque rose >40%
    speed_reduction_factor: 25.0      # Reduce cutting speed by 25% on trigger

  torque_to_current:    # Polynomial: f(tork) = a2*x^2 + a1*x + a0 → converts % torque to A
    a2: 0.015
    a1: -0.278
    a0: 15.656

  write_thresholds:     # Accumulate changes before writing to avoid Modbus spam
    inme_hizi:
      enabled: true
      threshold: 1.0    # Write when accumulated change ≥ 1.0 mm/min
    kesme_hizi:
      enabled: true
      threshold: 0.9    # Write when accumulated change ≥ 0.9 m/min

  speed_restore:
    enabled: true
    restore_on_cutting_end: true  # Restore operator speeds after each cut
```

---

## `database`

```yaml
database:
  sqlite:
    enabled: true
    path: "data/databases/current"   # Directory where .db files are created
    timeout: 30.0
    check_same_thread: false

    write_queues:
      raw_db: 1000       # Max queued writes before blocking
      total_db: 500
      log_db: 200
      ml_db: 200
```

---

## `anomaly_detection`

```yaml
anomaly_detection:
  enabled: true
  window_size: 100          # Rolling window for statistics
  z_score_threshold: 3.0    # Trigger if value is >3 std deviations from mean
  sensors:
    serit_motor_akim_a:
      warning: 15.0         # Log WARNING above this
      critical: 20.0        # Log ERROR above this
    serit_sapmasi:
      warning: 2.0
      critical: 5.0
    # ... one entry per monitored sensor
```

---

## `logging`

```yaml
logging:
  level: "INFO"
  file_enabled: true
  console_enabled: true
  files:
    app: "logs/app.log"
    modbus: "logs/modbus.log"
    database: "logs/database.log"
    control: "logs/control.log"
    iot: "logs/iot.log"
  max_bytes: 10485760     # 10 MB per file
  backup_count: 5         # Keep 5 rotated files
```

---

## `iot`

```yaml
iot:
  enabled: false           # Disabled by default
  type: "mqtt"             # "mqtt" or "http"

  mqtt:
    host: "your-broker"
    port: 1883
    username: "${MQTT_USER}"
    password: "${MQTT_PASS}"
    device_token: "${TB_DEVICE_TOKEN}"

  thingsboard:
    host: "https://your-tb-instance"
    device_token: "${TB_DEVICE_TOKEN}"
```
