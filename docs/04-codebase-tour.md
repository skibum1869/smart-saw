# Codebase Tour

A file-by-file walkthrough of every meaningful source file, grouped by layer.

---

## Entry Points

### `run.py`
The script you actually run (`python run.py`). Sets up the Python path and calls `src.main`.

### `src/main.py`
Registers SIGINT/SIGTERM signal handlers, creates `ApplicationLifecycle`, and runs the asyncio event loop. If the app crashes, the exit code propagates to the shell.

---

## Core (`src/core/`)

### `config.py`
Loads `config/config.yaml` using PyYAML. Substitutes `${VAR}` placeholders with environment variables from `.env`. Returns a plain dict — no typed schema enforcement.

### `constants.py`
Defines the `SawState` enum (machine states 0–6), `ControlMode` enum (MANUAL / ML), speed write thresholds, torque guard parameters, and other numeric constants. Anything that appears as a magic number in the codebase should be defined here.

### `lifecycle.py`
The master orchestrator. `ApplicationLifecycle.start()` creates every service in the right order and wires them together. `stop()` shuts everything down in reverse. This is the only place where service dependencies are assembled — nothing else calls constructors directly.

### `logger.py`
Sets up Python's `logging` module with colored console output (`colorlog`) and separate rotating file handlers per subsystem (modbus, database, control, iot). Called once at startup from `lifecycle.py`.

### `exceptions.py`
Custom exception classes for the application (e.g., `ModbusConnectionError`, `ConfigurationError`). Catch these instead of bare `Exception` for cleaner error handling.

---

## Domain (`src/domain/`)

Thin layer — pure Python data definitions, no I/O.

### `enums.py`
```python
class SawState(Enum):
    IDLE = 0
    HYDRAULIC_ACTIVE = 1
    BAND_MOTOR_RUNNING = 2
    CUTTING = 3
    CUTTING_COMPLETE = 4
    SAW_RISING = 5
    MATERIAL_FEEDING = 6

class ControlMode(Enum):
    MANUAL = "manual"
    ML = "ml"
```

### `models.py`
Dataclasses for structured data: `RawSensorData` (raw register values from Modbus), `ProcessedData` (scaled/converted values), `ControlCommand` (speed command to send to PLC).

### `validators.py`
Input validation functions — used to sanity-check values before writing them to the PLC.

---

## Services (`src/services/`)

### Modbus (`src/services/modbus/`)

#### `client.py`
Wraps pymodbus's async TCP client. Maintains connection state, implements a reconnection loop with a configurable cooldown (prevents hammering the PLC if it's offline), and exposes `read_registers()` and `write_register()` coroutines.

#### `reader.py`
Knows which registers to read and how to parse them. Reads ~40 registers in a single batch request (Modbus function code 03). Returns a `RawSensorData` dict. Runs at 10 Hz driven by the pipeline.

#### `writer.py`
Writes cutting speed and descent speed to the PLC registers (addresses 2066 and 2041). Only called when the pipeline decides a speed change is needed. Runs at up to 10 Hz but typically less often due to write thresholds.

---

### Control (`src/services/control/`)

#### `manager.py`
The `ControlManager` is the state machine that switches between Manual and ML mode. When you click "Manual" or "AI" in the GUI, this is what changes. It holds references to both `ManualController` and `MLController` and delegates the `calculate_speeds()` call to whichever is currently active.

#### `manual.py`
In manual mode, speeds are simply whatever the operator last set via the GUI. `ManualController` stores those values and returns them unchanged on each tick.

#### `ml_controller.py`
The most complex service (~836 lines). In ML mode, this:
1. Collects the last N data points into a buffer
2. Extracts 4 features: band current, band deviation, cutting speed, descent speed
3. Runs the scikit-learn Bagging model
4. Applies the `COEFFICIENT` global multiplier
5. Enforces speed limits (min/max from config)
6. Applies the **Torque Guard** protection mechanism (see below)
7. Accumulates speed changes until the write threshold is reached
8. Returns the new recommended speeds

**Torque Guard** is a safety feature: after ML activates, it watches the band motor torque. If torque increases by more than 40% over the previous 2.5mm of descent, it reduces cutting speed by 25%. This protects the blade from breaking when encountering hard material.

**Initial delay**: ML doesn't activate immediately when cutting starts. There's a configurable delay (default 5 seconds OR 25mm of descent, whichever comes later) to let the machine stabilize before ML takes control.

#### `machine_control.py`
Singleton class used by the GUI to issue one-shot commands: start cutting, stop cutting, set speed, enable coolant, etc. It translates GUI button presses into Modbus write operations. Because it's a singleton, any page in the GUI can import and use it without needing a reference passed through the hierarchy.

---

### Processing (`src/services/processing/`)

#### `data_processor.py`
The 10 Hz pipeline loop. On each tick: read Modbus → scale values → update cutting tracker → run control → detect anomalies → write DB → publish IoT → update snapshot. This is the central coordinator of the entire system.

#### `cutting_tracker.py`
Singleton that watches `testere_durumu` transitions to detect when a cutting session starts and ends. Assigns a sequential `kesim_id` integer to each session. Persists session metadata (start/end time, duration, start/end height, data point count) to `total.db` via `cutting_sessions` table. Survives app restarts by loading the last `kesim_id` from the database on startup.

#### `anomaly_tracker.py`
Maintains the state of active anomalies across pipeline ticks. An anomaly is "active" until the sensor value returns to normal. Prevents the same anomaly from being logged 10 times per second.

#### `anomaly_detector.py`
Statistical detection: maintains a rolling window of recent values for each sensor, computes Z-score and IQR. Values beyond configured thresholds trigger an anomaly event.

---

### Database (`src/services/database/`)

#### `sqlite_service.py`
Thread-safe SQLite wrapper using the single-writer pattern: a dedicated background thread owns the connection and processes writes from a queue. Reads use thread-local connections (each thread gets its own read-only connection). Exposes `write_async(sql, params)` (queues a write) and `read(sql, params)` (synchronous read).

#### `schemas.py`
SQL `CREATE TABLE` statements for all six databases. Imported by `lifecycle.py` which runs them at startup via `executescript()`. Adding a column means editing here and clearing the old database file (or writing a migration). See `docs/09-database-schema.md` for the full column-level reference.

#### `backup_service.py`
Runs daily backups of all four SQLite files by copying them to a timestamped folder. Runs in a separate process to avoid blocking the main application.

#### `postgres_service.py`
Optional. When enabled in config, mirrors data to a PostgreSQL server using `asyncpg`. Disabled by default.

---

### IoT (`src/services/iot/`)

#### `mqtt_client.py`
Async MQTT client using `aiomqtt`. Publishes sensor data to a broker in ThingsBoard's telemetry JSON format. Implements reconnection with exponential backoff. Batches multiple data points into a single publish to reduce broker load.

#### `http_client.py`
Alternative to MQTT: sends telemetry via ThingsBoard's REST API using aiohttp. Used when MQTT is blocked or unavailable.

#### `thingsboard.py`
Protocol helpers: formatting telemetry payloads, managing device tokens, handling provisioning responses.

---

### Camera (`src/services/camera/`)

Optional subsystem — only active if a camera device is configured.

#### `camera_service.py`
Opens an OpenCV `VideoCapture` and reads frames in a daemon thread at up to 30 FPS. Shares frames via a thread-safe ring buffer.

#### `detection_worker.py`
Runs YOLO object detection on frames in a separate thread. Detects broken teeth on the band saw blade. Posts results to `CameraResultsStore`.

#### `ldc_worker.py`
Applies lens distortion correction (LDC) to frames before detection. Uses OpenCV's `undistort` with pre-calibrated camera matrix coefficients.

#### `results_store.py`
Thread-safe store that holds the most recent camera frame, detection results, and health metrics. The GUI polls this at its own rate.

#### `health_calculator.py`
Computes a "saw health" score based on the number of detected broken teeth and wear percentage. Maps these to a 0–100 health index.

---

## ML Model (`src/ml/`)

### `model_loader.py`
Loads the `.pkl` model file using `joblib`. Thread-safe with a lock around the load call. Caches the loaded model so subsequent calls are instant.

### `preprocessor.py`
Prepares the 4 input features for model inference: normalizes or scales values as the model expects. The preprocessing must exactly match what was used during model training.

---

## GUI (`src/gui/`)

### `app.py`
Creates the `QApplication`, instantiates `MainController`, shows the window, and enters the Qt event loop. Called from the lifecycle on a dedicated thread.

### `page_index.py`
`PageIndex` IntEnum mapping page names to `QStackedWidget` indices (0–6). Import this anywhere you need to navigate between pages.

### `numpad.py`
A virtual numeric keypad dialog (`NumpadDialog`). All parameter entry in the GUI uses this — tap a parameter frame, the numpad appears, the operator enters a number, and it writes back to the frame. Supports optional decimal point input.

### `widgets/touch_button.py`
A `QPushButton` subclass that also responds to Qt touch events (in addition to mouse events). Used for the positioning page buttons which need to work on a touchscreen without a mouse.

### Controllers (`src/gui/controllers/`)

See `docs/06-gui-pages.md` for a detailed walkthrough of each page.

| File | Page | Lines |
|------|------|-------|
| `main_controller.py` | Sidebar + page switching | 487 |
| `control_panel_controller.py` | Main control page | 2,502 |
| `auto_cutting_controller.py` (class `AutoCuttingController`) | Auto cutting mode | 1,206 |
| `positioning_controller.py` | Vise / positioning | 785 |
| `sensor_controller.py` | Cutting graphs + anomaly | 1,514 |
| `monitoring_controller.py` | Live sensor monitor | 850 |
| `alarm_controller.py` | Alarm history | 413 |
| `camera_controller.py` | Camera feed | 539 |

---

## Tests (`tests/`)

| Test File | What It Tests |
|-----------|--------------|
| `test_page_index.py` | PageIndex values and aliases |
| `test_otomatik_kesim_controller.py` | AutoCuttingController validation, polling, ML mode |
| `test_machine_control_auto_cutting.py` | Cutting session lifecycle |
| `test_main_controller_integration.py` | Main window page switching |
| `test_camera_service.py` | Camera lifecycle and frame capture |
| `test_camera_results_store.py` | Thread-safe camera state sharing |
| `test_detection_worker.py` | YOLO detection worker threading |
| `test_health_calculator.py` | Saw health score computation |
| `test_ldc_worker.py` | Lens distortion correction |
| `test_vision_service.py` | Vision service orchestration |

All tests mock hardware (no PLC or camera required). GUI tests bypass `QApplication` by using `__new__` + manual attribute injection to instantiate controllers without rendering any widgets.
