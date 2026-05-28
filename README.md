# Smart Saw Control System

Industrial band saw controller with ML-based cutting speed optimization, real-time sensor monitoring, and a 1920×1080 fullscreen touchscreen GUI.

## Overview

- **PLC communication** — Modbus TCP, 10 Hz polling of ~40 registers
- **ML control** — scikit-learn Bagging ensemble adjusts cutting and descent speed in real time
- **Torque Guard** — safety feature that reduces speed if band motor torque spikes >40%
- **GUI** — PySide6 fullscreen interface with 7 pages (control panel, auto cutting, positioning, sensor graphs, monitoring, alarms, camera)
- **Camera (optional)** — YOLO-based broken tooth detection, LDC wear measurement
- **Storage** — 6 SQLite databases (raw sensor, processed, logs, ML audit, anomalies, camera)
- **IoT (optional)** — MQTT telemetry to ThingsBoard

## Quick Start

```bash
git clone https://github.com/skibum1869/smart-saw.git
cd smart-saw
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # add IoT credentials if needed
python run.py
```

If the PLC is not reachable the GUI still launches and reconnects automatically.

## Production Deployment (Ubuntu 24.04 LTS)

An interactive setup script handles system packages, virtualenv, and the systemd service:

```bash
sudo bash setup-autostart.sh
```

Choose **W** first to disable Wayland (Ubuntu 24.04 defaults to Wayland; the app requires X11), then choose **6** for full setup. See [`docs/02-getting-started.md`](docs/02-getting-started.md) for details.

## Configuration

All behavior is controlled by `config/config.yaml`. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `modbus.host` | `192.168.1.147` | PLC IP address |
| `control.default_mode` | `manual` | `manual` or `ml` at startup |
| `ml.model_path` | `data/models/...pkl` | Bagging model file |
| `gui.enabled` | `true` | Set `false` for headless operation |
| `iot.enabled` | `false` | Enable MQTT telemetry |

Full reference: [`docs/05-configuration.md`](docs/05-configuration.md)

## ML Model

**Algorithm:** Bagging ensemble (scikit-learn, loaded via joblib)

**Inputs:** band motor current (A), band deviation (mm), cutting speed (m/min), descent speed (mm/min)

**Output:** speed adjustment coefficient applied to both axes

**Torque Guard:** activates 5 s after ML starts; if torque increases >40% over the previous 2.5 mm of descent, cutting speed is reduced by 25%.

## Documentation

| File | Contents |
|------|----------|
| [`docs/01-overview.md`](docs/01-overview.md) | System overview, machine concepts, tech stack |
| [`docs/02-getting-started.md`](docs/02-getting-started.md) | Setup, running, Ubuntu 24.04 deployment |
| [`docs/03-architecture.md`](docs/03-architecture.md) | Concurrency model, startup sequence, data flow |
| [`docs/04-codebase-tour.md`](docs/04-codebase-tour.md) | Every source file described |
| [`docs/05-configuration.md`](docs/05-configuration.md) | Full config.yaml reference |
| [`docs/06-gui-pages.md`](docs/06-gui-pages.md) | All 7 GUI pages documented |
| [`docs/07-translation.md`](docs/07-translation.md) | Turkish→English translation record |
| [`docs/08-plc-registers.md`](docs/08-plc-registers.md) | Full Modbus register map with scaling |
| [`docs/09-database-schema.md`](docs/09-database-schema.md) | All 6 SQLite database schemas |

## Project Structure

```
smart-saw/
├── config/config.yaml          # Main configuration
├── data/
│   ├── databases/current/      # SQLite databases (runtime)
│   └── models/                 # ML model (.pkl)
├── docs/                       # Documentation
├── logs/                       # Log files (runtime)
├── src/
│   ├── core/                   # Config, lifecycle, logging, exceptions
│   ├── domain/                 # Enums, dataclasses, validators
│   ├── services/
│   │   ├── modbus/             # Async Modbus client, reader, writer
│   │   ├── control/            # Manual/ML mode, MachineControl singleton
│   │   ├── processing/         # 10 Hz pipeline, cutting tracker, anomaly detection
│   │   ├── database/           # SQLite service, schemas, backup
│   │   ├── iot/                # MQTT / ThingsBoard
│   │   └── camera/             # OpenCV capture, YOLO detection, wear calc
│   ├── ml/                     # Model loader, preprocessor
│   └── gui/                    # PySide6 controllers (7 pages)
├── tests/                      # Test suite (mocked hardware)
├── run.py                      # Entry point
└── setup-autostart.sh          # Ubuntu 24.04 systemd deployment
```

## Tests

```bash
pytest tests/ -v
```

All tests mock hardware — no PLC or camera required.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| GUI doesn't appear on Ubuntu | Run option W in `setup-autostart.sh` to disable Wayland |
| `ModuleNotFoundError: yaml` | Activate the venv before running |
| PLC shows "Awaiting Connection" | Check `modbus.host` in `config/config.yaml` and network/firewall on port 502 |
| ML model not found | Copy `.pkl` file to `data/models/` and update `ml.model_path` in config |
| Database queue full | Increase `database.sqlite.write_queues.*` in config or check disk I/O |

Logs are written to `logs/` (separate files per subsystem: `app`, `modbus`, `database`, `control`, `iot`).

## License

MIT
