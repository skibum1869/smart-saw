# Smart Band Saw Control System — Overview

## What Is This?

This is an industrial control system for a **band saw machine** (a motorized metal-cutting saw that uses a continuous looped blade). The software runs on a dedicated computer mounted on or near the machine, communicates with the machine's PLC (Programmable Logic Controller) over Ethernet, and provides:

- A **full-screen touchscreen GUI** for operators to control the machine
- **Automatic (AI-driven) cutting speed control** using a trained ML model
- **Real-time sensor monitoring** for all machine parameters
- **Anomaly detection** that alerts operators to dangerous conditions
- **Data logging** of every cutting session to local databases
- **IoT telemetry** sending sensor data to a ThingsBoard cloud dashboard
- **Computer vision** for band saw blade inspection (optional)

The machine itself is controlled by a Mitsubishi or similar PLC. This software sits between the human operator and the PLC — reading sensor data from PLC registers, making decisions, and writing speed commands back to the PLC.

---

## Physical Setup

```
Operator
   │
   ▼
┌──────────────────────┐
│  Control Computer    │  ← Runs this software
│  (Raspberry Pi /     │
│   Industrial PC)     │
│  1920×1080 display   │
└──────────┬───────────┘
           │ Modbus TCP (Ethernet)
           │ 192.168.1.147:502
           ▼
┌──────────────────────┐
│  PLC (Mitsubishi     │  ← Machine brain
│  or similar)         │
└──────────┬───────────┘
           │ Hardwired I/O
           ▼
┌──────────────────────┐
│  Band Saw Machine    │  ← Physical machine
│  - Band motor        │
│  - Descent motor     │
│  - Hydraulic system  │
│  - Coolant system    │
│  - Vise clamps       │
└──────────────────────┘
```

Additionally, sensor data is forwarded to the cloud:

```
Control Computer ──MQTT/HTTP──► ThingsBoard Cloud Dashboard
```

---

## Key Machine Concepts

| Term | Meaning |
|------|---------|
| **Cutting speed** (`serit_kesme_hizi`) | How fast the band blade moves, in m/min. Controlled by the band motor. |
| **Descent speed** (`serit_inme_hizi`) | How fast the saw head drops into the material, in mm/min. Controlled by the descent motor. |
| **Head height** (`kafa_yuksekligi_mm`) | How far the saw head is from the bottom, in mm. Goes from ~350mm (top) down toward 0mm as cutting progresses. |
| **Band deviation** (`serit_sapmasi`) | Lateral drift of the blade as it cuts — ideally near 0mm. |
| **Saw state** | Current machine state: IDLE → HYDRAULIC ACTIVE → BAND MOTOR RUNNING → CUTTING → CUTTING COMPLETE → SAW RISING |
| **Cutting session** (`kesim_id`) | One complete cut from start to finish, tracked with a sequential integer ID. |
| **Torque** | Resistance the blade encounters. High torque = hard material or dull blade. Used to protect the blade. |
| **Vise (mengene)** | Clamps that hold the material in place while cutting. Front and rear vise. |

---

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────┐
│                      GUI (PySide6)                         │
│   7 pages: Control Panel, Auto Cutting, Positioning,       │
│            Sensor, Monitoring, Alarm, Camera               │
└─────────────────────────┬──────────────────────────────────┘
                          │ Qt Signals / thread-safe callbacks
┌─────────────────────────▼──────────────────────────────────┐
│               Data Processing Pipeline (10 Hz)             │
│   Reads Modbus data → scales values → detects anomalies    │
│   → runs ML → writes speeds back → logs to database        │
└───────┬──────────────┬────────────────┬────────────────────┘
        │              │                │
┌───────▼───┐  ┌───────▼──────┐  ┌─────▼──────────┐
│  Modbus   │  │  SQLite DBs  │  │  IoT (MQTT/    │
│  TCP/PLC  │  │  (4 files)   │  │  ThingsBoard)  │
└───────────┘  └──────────────┘  └────────────────┘
```

The system runs with **two concurrency layers**:
- **AsyncIO event loop** — Modbus communication, IoT telemetry, database writes
- **Qt GUI thread** — All user interface rendering and interaction (runs on its own thread)

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| GUI framework | PySide6 (Qt for Python) |
| Async I/O | Python asyncio |
| PLC communication | pymodbus (Modbus TCP) |
| ML model | scikit-learn Bagging ensemble (joblib) |
| Local database | SQLite (4 databases) |
| Cloud database | PostgreSQL (optional) |
| IoT telemetry | MQTT / ThingsBoard HTTP API |
| Computer vision | OpenCV + Ultralytics YOLO |
| Configuration | YAML (`config/config.yaml`) |

---

## Project Stats

- ~20,000 lines of Python across 75+ files
- 7 GUI pages
- 4 SQLite databases
- 70+ Modbus registers read at 10 Hz
- 11 development phases completed
- Supports headless mode (no GUI, for server deployments)
