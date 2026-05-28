# Architecture

## Service Layers

The system is structured in clean layers, each with a single responsibility.

```
┌─────────────────────────────────────────────────────────────────┐
│  Presentation (src/gui/)                                        │
│  PySide6 fullscreen GUI, 7 pages, Qt Signals/Slots              │
└────────────────────────────┬────────────────────────────────────┘
                             │ get_latest_data() / callbacks
┌────────────────────────────▼────────────────────────────────────┐
│  Processing Pipeline (src/services/processing/)                 │
│  DataProcessingPipeline — 10 Hz loop                            │
│  • Reads Modbus → scales values → runs ML → detects anomalies   │
│  • Writes speed commands back to PLC                            │
│  • Stores data in SQLite                                        │
└──────┬─────────────┬────────────────────┬───────────────────────┘
       │             │                    │
┌──────▼──────┐ ┌────▼──────┐  ┌─────────▼──────────┐
│  Modbus     │ │  Database │  │  ML / Control      │
│  TCP/PLC    │ │  (SQLite) │  │  (src/services/    │
│  (reader /  │ │  4 files  │  │   control/)        │
│   writer)   │ │           │  │                    │
└─────────────┘ └───────────┘  └────────────────────┘
                                         │
                               ┌─────────▼──────────┐
                               │  ML Model          │
                               │  (Bagging .pkl)    │
                               └────────────────────┘
       │
┌──────▼──────┐
│  IoT        │
│  MQTT /     │
│  ThingsBoard│
└─────────────┘
```

---

## Concurrency Model

This is the trickiest part of the codebase. Three concurrency primitives are in play simultaneously:

### 1. AsyncIO Event Loop (main thread)

Runs almost everything non-GUI:
- Modbus TCP reads and writes (10 Hz each)
- IoT/MQTT telemetry publishing
- PostgreSQL (if enabled)
- The data processing pipeline loop

### 2. Qt GUI Thread (separate thread)

The PySide6 GUI runs on its own thread, started by `ApplicationLifecycle`. It must never be called from the asyncio thread directly.

**Communication between asyncio and Qt:**
- The pipeline calls `data_pipeline.get_latest_data()` — a thread-safe snapshot
- GUI timers (QTimer at 200ms) call `get_latest_data()` to poll for updates
- For the reverse direction (GUI → PLC), GUI handlers call `MachineControl` methods which post coroutines via `asyncio.run_coroutine_threadsafe()`

### 3. Background Threads

- **SQLite write thread** — A single dedicated writer thread per database, fed via a thread-safe queue. This avoids SQLite's "check same thread" limitation.
- **Camera capture thread** — OpenCV frame capture runs as a daemon thread.
- **Detection worker thread** — YOLO inference runs in a separate thread.
- **Backup process** — Daily database backups run in a separate Python process (via `multiprocessing`).

### Summary Table

| What | Concurrency | Why |
|------|------------|-----|
| Modbus reads/writes | asyncio | pymodbus is async-native |
| MQTT publishing | asyncio | aiomqtt is async-native |
| Data pipeline loop | asyncio | Needs to coordinate with Modbus |
| GUI rendering | Qt thread | Qt requirement |
| SQLite writes | Dedicated writer thread | SQLite write serialization |
| SQLite reads | Thread-local connections | Thread-safe read concurrency |
| Camera capture | Daemon thread | OpenCV blocking I/O |
| ML inference | Runs inline in asyncio | Model is fast enough (<1ms) |
| Daily backups | Separate process | Isolation from main app |

---

## Application Startup Sequence

`ApplicationLifecycle.start()` in `src/core/lifecycle.py` starts services in this order:

1. **Load configuration** — Parse `config/config.yaml` with env var substitution
2. **Setup logging** — Create log files under `logs/`
3. **Initialize databases** — Create/verify SQLite schemas for all 4 databases
4. **Connect Modbus** — Attempt TCP connection to PLC (non-blocking; retries in background)
5. **Start control manager** — Initialize Manual/ML mode state machine
6. **Start IoT services** — Connect MQTT broker (optional, skipped if not configured)
7. **Start data pipeline** — Launch 10 Hz asyncio loop
8. **Start camera** — If camera config is present and enabled
9. **Launch GUI** — Start Qt application on a separate thread

**Shutdown** (on SIGINT/SIGTERM or pressing Q in the GUI) reverses this order, waiting up to 10 seconds for database write queues to drain.

---

## Data Flow: One Pipeline Tick (10 Hz)

Every 100ms, `DataProcessingPipeline._process_tick()` does:

```
1. Read Modbus registers (async)
   └─► ~40 registers in one batch read

2. Scale raw values
   └─► Divide by 10/100 where PLC encodes decimals as integers

3. Detect saw state transition
   └─► IDLE → CUTTING: start new cutting session (increment kesim_id)
   └─► CUTTING → other: end cutting session, save to DB

4. Run ML inference (if in ML mode and initial delay has passed)
   └─► Features: [band_current, band_deviation, cutting_speed, descent_speed]
   └─► Output: recommended speed multiplier
   └─► Apply Torque Guard checks
   └─► Accumulate speed change until threshold; write to Modbus

5. Run anomaly detection
   └─► 9 detectors (one per sensor type), statistical Z-score / IQR methods

6. Write to SQLite (async, via write queue)
   └─► raw.db: raw register values
   └─► total.db: scaled values + ML outputs + anomaly flags

7. Publish to IoT (if connected)
   └─► Batch telemetry to ThingsBoard

8. Update thread-safe snapshot
   └─► GUI polls this via get_latest_data() at its own 200ms rate
```

---

## Key Design Decisions

### Why are database keys in Turkish?

The dict keys in the data pipeline (e.g., `testere_durumu`, `serit_kesme_hizi`) match the SQLite column names and the Modbus register naming conventions from the original hardware documentation. Changing them would require a coordinated database migration, so they were deliberately left as-is during the English translation. See `docs/07-translation.md`.

### Why four databases instead of one?

Each database has a different write pattern and retention policy:
- `raw.db` — Every single Modbus poll (high volume, potentially trimmed)
- `total.db` — Processed + ML data (medium volume, long retention)
- `log.db` — Application logs (append-only, separate from sensor data)
- `ml.db` — ML prediction audit trail (only written during ML mode)

Keeping them separate avoids write contention and makes it easy to delete or archive one without affecting others.

### Why a singleton for MachineControl?

`MachineControl` (in `src/services/control/machine_control.py`) is a singleton because it manages a single Modbus connection to the physical machine. Multiple GUI pages need to issue commands (start cutting, set speed, etc.) without stepping on each other. The singleton ensures all commands go through one serialized interface.

### Why does the GUI poll instead of being pushed to?

PySide6 requires all widget updates to happen on the Qt thread. Rather than routing every data update through Qt signals (which requires careful signal/slot wiring across threads), each page controller uses a `QTimer` to poll `data_pipeline.get_latest_data()` at its own rate (typically 200–500ms). The pipeline always returns the most recent complete snapshot, so no data is lost.
