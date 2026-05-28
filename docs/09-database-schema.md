# Database Schema

The application uses **six SQLite databases**, each stored as a separate file under `data/databases/current/`. Schemas are defined in `src/services/database/schemas.py` and applied at startup via `executescript()`.

All timestamps are stored as ISO-8601 TEXT strings (e.g., `"2025-05-28T14:30:00.123456"`).

---

## raw.db — Raw Modbus Registers

**File:** `raw.db`  
**Write rate:** Every Modbus poll (10 Hz = ~864,000 rows/day)  
**Purpose:** Unprocessed integer values straight off the wire. Useful for debugging register-level issues or replaying data without the scaling logic.

### Table: `raw_registers`

One row per Modbus read. Each column is the raw integer register value before any scaling.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment row ID |
| `timestamp` | TEXT | Poll time |
| `reg_1000_makine_id` | INTEGER | Machine ID |
| `reg_1001_serit_id` | INTEGER | Band ID |
| `reg_1002_serit_dis_mm` | INTEGER | Band tooth pitch |
| `reg_1003_serit_tip` | INTEGER | Band type code |
| `reg_1004_serit_marka` | INTEGER | Band brand code |
| `reg_1005_serit_malz` | INTEGER | Band material code |
| `reg_1006_malzeme_cinsi` | INTEGER | Material type code |
| `reg_1007_malzeme_sertlik` | INTEGER | Material hardness code |
| `reg_1008_kesit_yapisi` | INTEGER | Cross-section code |
| `reg_1009_a_mm` – `reg_1012_d_mm` | INTEGER | Material dimensions A–D |
| `reg_1013_kafa_yuksekligi` | INTEGER | Head height raw (÷10 = mm) |
| `reg_1014_kesilen_parca_adeti` | INTEGER | Pieces cut counter |
| `reg_1015_serit_motor_akim` | INTEGER | Band motor current raw (÷10 = A) |
| `reg_1016_serit_motor_tork` | INTEGER | Band motor torque raw (÷10 = %) |
| `reg_1017_inme_motor_akim` | INTEGER | Descent motor current raw (÷100 = A) |
| `reg_1018_inme_motor_tork` | INTEGER | Descent motor torque raw |
| `reg_1019_mengene_basinc` | INTEGER | Vise pressure raw (÷10 = bar) |
| `reg_1020_serit_gerginligi` | INTEGER | Band tension raw (÷10 = bar) |
| `reg_1021_ivme_olcer_x/y/z` | INTEGER | Vibration X/Y/Z (g) |
| `reg_1024_serit_sapmasi` | INTEGER | Band deviation raw (÷100 = mm, signed) |
| `reg_1025_ortam_sicakligi` | INTEGER | Ambient temperature raw (÷10 = °C) |
| `reg_1026_ortam_nem` | INTEGER | Ambient humidity raw (÷10 = %) |
| `reg_1027_sogutma_sivi_sicakligi` | INTEGER | Coolant temperature raw |
| `reg_1028_hidrolik_yag_sicakligi` | INTEGER | Hydraulic oil temperature raw |
| `reg_1029_serit_sicakligi` | INTEGER | Band temperature raw |
| `reg_1030_testere_durumu` | INTEGER | Saw state (0–6) |
| `reg_1031_alarm_status` | INTEGER | Fault active flag |
| `reg_1032_alarm_bilgisi` | INTEGER | Alarm bitmask |
| `reg_1033_serit_kesme_hizi` | INTEGER | Cutting speed raw (÷10 = m/min) |
| `reg_1034_serit_inme_hizi` | INTEGER | Descent speed raw (special signed) |
| `reg_1035–1040` | INTEGER | Vibration frequencies and deltas |
| `reg_1041_malzeme_genisligi` | INTEGER | Material width raw (÷10 = mm) |
| `reg_1042_guc_1`, `reg_1043_guc_2` | INTEGER | Power (IEEE 754 float split across two 16-bit words) |

**Indexes:** `timestamp`, `testere_durumu`

---

## total.db — Processed Sensor Data

**File:** `total.db`  
**Write rate:** Every pipeline tick (10 Hz)  
**Purpose:** Scaled engineering-unit values plus ML outputs, anomaly flags, and cutting session linkage. This is the primary analytics database.

### Table: `sensor_data`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `timestamp` | TEXT | Tick time |
| `kesim_id` | INTEGER | Cutting session ID (NULL when not cutting) |
| `serit_motor_akim_a` | REAL | Band motor current (A) |
| `serit_motor_tork_percentage` | REAL | Band motor torque (%) |
| `inme_motor_akim_a` | REAL | Descent motor current (A) |
| `inme_motor_tork_percentage` | REAL | Descent motor torque (%) |
| `serit_kesme_hizi` | REAL | Cutting speed feedback (m/min) |
| `serit_inme_hizi` | REAL | Descent speed feedback (mm/min) |
| `kesme_hizi_hedef` | REAL | Cutting speed setpoint (m/min) |
| `inme_hizi_hedef` | REAL | Descent speed setpoint (mm/min) |
| `kafa_yuksekligi_mm` | REAL | Head height (mm) |
| `serit_sapmasi` | REAL | Band deviation (mm) |
| `serit_gerginligi_bar` | REAL | Band tension (bar) |
| `mengene_basinc_bar` | REAL | Vise pressure (bar) |
| `ortam_sicakligi_c` | REAL | Ambient temperature (°C) |
| `ortam_nem_percentage` | REAL | Ambient humidity (%) |
| `sogutma_sivi_sicakligi_c` | REAL | Coolant temperature (°C) |
| `hidrolik_yag_sicakligi_c` | REAL | Hydraulic oil temperature (°C) |
| `ivme_olcer_x/y/z` | REAL | Vibration X/Y/Z (g) |
| `ivme_olcer_x/y/z_hz` | REAL | Vibration frequencies (Hz) |
| `max_titresim_hz` | REAL | Peak vibration frequency (Hz) |
| `testere_durumu` | INTEGER | Saw state (0–6) |
| `alarm_status` | INTEGER | Fault flag |
| `alarm_bilgisi` | TEXT | Alarm bitmask as hex string |
| `makine_id`, `serit_id` | INTEGER | Traceability IDs |
| `malzeme_cinsi`, `malzeme_sertlik`, `kesit_yapisi` | TEXT | Material info |
| `malzeme_a_mm` – `malzeme_d_mm` | INTEGER | Material dimensions |
| `malzeme_genisligi` | REAL | Material width (mm) |
| `serit_tip`, `serit_marka`, `serit_malz` | TEXT | Band info |
| `serit_dis_mm` | INTEGER | Band tooth pitch (mm) |
| `kesilen_parca_adeti` | INTEGER | Pieces cut |
| `guc_kwh` | REAL | Power consumption (kWh) |
| `ml_output` | REAL | Raw ML model output (speed multiplier) |
| `kesme_hizi_degisim` | REAL | Cutting speed delta applied this tick |
| `inme_hizi_degisim` | REAL | Descent speed delta applied this tick |
| `torque_guard_active` | INTEGER | 1 if Torque Guard was active this tick |
| `controller_type` | TEXT | `"manual"` or `"ml"` |
| `anomalies` | TEXT | JSON list of active anomaly names |

**Indexes:** `timestamp`, `kesim_id`, `testere_durumu`

### Table: `cutting_sessions`

One row per cutting session (state transitions into and out of `CUTTING`).

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `kesim_id` | INTEGER UNIQUE | Sequential session counter (survives restarts) |
| `start_time` | TEXT | Timestamp when state entered CUTTING |
| `end_time` | TEXT | Timestamp when state left CUTTING (NULL if in progress) |
| `controller_type` | TEXT | `"manual"` or `"ml"` at start of session |
| `start_height_mm` | REAL | Head height at cut start |
| `end_height_mm` | REAL | Head height at cut end |
| `duration_ms` | INTEGER | Cut duration in milliseconds |
| `data_count` | INTEGER | Number of `sensor_data` rows for this session |

**Indexes:** `kesim_id`, `start_time`

---

## log.db — Application Logs

**File:** `log.db`  
**Write rate:** On demand (application events, warnings, errors)  
**Purpose:** Structured log records, queryable by time/level/logger.

### Table: `system_logs`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `timestamp` | TEXT | Log time |
| `level` | TEXT | `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |
| `logger_name` | TEXT | Python logger name (e.g., `modbus`, `control`) |
| `message` | TEXT | Log message text |
| `exception` | TEXT | Traceback if an exception was attached |

**Indexes:** `timestamp`, `level`, `logger_name`

---

## ml.db — ML Prediction Audit Trail

**File:** `ml.db`  
**Write rate:** Every tick where ML mode is active and a prediction was made  
**Purpose:** Full audit of ML inputs and outputs for model evaluation and debugging.

### Table: `ml_predictions`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `timestamp` | TEXT | Prediction time |
| `akim_input` | REAL | Band motor current feature (A) |
| `sapma_input` | REAL | Band deviation feature (mm) |
| `kesme_hizi_input` | REAL | Cutting speed feature (m/min) |
| `inme_hizi_input` | REAL | Descent speed feature (mm/min) |
| `serit_motor_tork` | REAL | Band motor torque (%) |
| `kafa_yuksekligi` | REAL | Head height at prediction (mm) |
| `yeni_kesme_hizi` | REAL | Cutting speed command output (m/min) |
| `yeni_inme_hizi` | REAL | Descent speed command output (mm/min) |
| `katsayi` | REAL | Global speed multiplier (COEFFICIENT) applied |
| `ml_output` | REAL | Raw model output before multiplier |
| `kesim_id` | INTEGER | Cutting session (NULL if not cutting) |
| `makine_id`, `serit_id` | INTEGER | Traceability IDs |
| `malzeme_cinsi` | TEXT | Material type |

**Indexes:** `timestamp`, `kesim_id`

---

## anomaly.db — Anomaly Detection Events

**File:** `anomaly.db`  
**Write rate:** On event (when a sensor value crosses a threshold)  
**Purpose:** Persisted history of sensor anomalies for trend analysis and blade wear tracking.

### Table: `anomaly_events`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `timestamp` | TEXT | Event time |
| `sensor_name` | TEXT | Key name of affected sensor (e.g., `serit_motor_akim_a`) |
| `sensor_value` | REAL | Sensor reading at event time |
| `detection_method` | TEXT | `"z_score"` or `"iqr"` |
| `kesim_id` | INTEGER | Cutting session at time of event |
| `kafa_yuksekligi` | REAL | Head height at event (mm) |
| `makine_id`, `serit_id` | INTEGER | Traceability IDs |
| `malzeme_cinsi` | TEXT | Material type |

### Table: `anomaly_resets`

Tracks when the operator pressed "Reset" on the Sensor page, clearing the visible anomaly history.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `reset_time` | TEXT | When the reset occurred |
| `reset_by` | TEXT | Always `"user"` currently |

**Indexes:** `timestamp`, `sensor_name`, `kesim_id`, `reset_time`

---

## camera.db — Camera Vision Results

**File:** `camera.db`  
**Write rate:** On detection event (frame-rate dependent, only when anomalies detected)  
**Purpose:** Blade health tracking — broken tooth counts, crack events, and wear measurements over time.

### Table: `detection_events`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `timestamp` | TEXT | Detection time |
| `event_type` | TEXT | `"broken_tooth"` or `"crack"` |
| `confidence` | REAL | YOLO model confidence (0.0–1.0) |
| `count` | INTEGER | Number of detections in this event |
| `image_path` | TEXT | Path to the source frame JPEG |
| `kesim_id` | INTEGER | Cutting session at detection |
| `makine_id`, `serit_id`, `malzeme_cinsi` | — | Traceability fields |

### Table: `wear_history`

Wear measurements from LDC (lens distortion corrected) edge detection.

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `timestamp` | TEXT | Measurement time |
| `wear_percentage` | REAL | Computed blade wear (0–100 %) |
| `health_score` | REAL | Combined health index (0–100) |
| `edge_pixel_count` | INTEGER | Raw edge pixel count from OpenCV |
| `image_path` | TEXT | Source frame path |
| `kesim_id` | INTEGER | Cutting session at measurement |
| `makine_id`, `serit_id`, `malzeme_cinsi` | — | Traceability fields |

**Indexes:** `timestamp`, `event_type`, `kesim_id`, `wear_kesim_id`

---

## Notes

### Why are column names in Turkish?

These column names are the original interface contract between the data pipeline, the schema, and any external dashboards. Renaming them requires recreating the SQLite tables (SQLite does not support `ALTER TABLE RENAME COLUMN` on all column types and indexes) and updating every SQL query. See `docs/07-translation.md` for the full rationale.

### Adding a new column

1. Edit the relevant `SCHEMA_*` constant in `schemas.py`.
2. Delete the old database file (or write a migration script using `CREATE TABLE ... AS SELECT` and `DROP TABLE`/rename).
3. The schema is applied at startup by `lifecycle.py` using `executescript()`.

### Traceability fields

`ml_predictions`, `anomaly_events`, `detection_events`, and `wear_history` all carry `makine_id`, `serit_id`, and `malzeme_cinsi`. These let you join any prediction or anomaly record back to the machine configuration and blade that was in use at the time.
