# Getting Started

## Prerequisites

- **OS:** Ubuntu 24.04 LTS (production target); any systemd + X11 Linux for development
- **Python:** 3.10 or newer (Ubuntu 24.04 ships Python 3.12 — compatible)
- **Network:** access to the PLC at `192.168.1.147:502` (only needed on the target machine)
- **Display:** 1920×1080; the GUI layout uses fixed pixel coordinates for a touchscreen

## Setup

```bash
# Clone the repository
git clone <repo-url>
cd smart-saw

# Create and activate a virtual environment
python3 -m venv .venv
source .venv/bin/activate        # Linux/macOS
# .venv\Scripts\activate         # Windows

# Install dependencies
pip install -r requirements.txt
```

> If you see `ModuleNotFoundError: No module named 'yaml'` when running tests,
> you are using the system Python rather than the venv. Activate the venv first.

## Running the Application

```bash
# From the project root:
python run.py
```

Or directly:

```bash
python -m src.main
```

The application will:
1. Load `config/config.yaml`
2. Initialize all four SQLite databases under `data/databases/current/`
3. Attempt to connect to the PLC via Modbus TCP
4. Start the data processing pipeline at 10 Hz
5. Launch the GUI (if `gui.enabled: true` in config)

If the PLC is not reachable, the GUI will still launch and display "Awaiting Connection" — it reconnects automatically.

## Running Headless (No GUI)

Set `gui.enabled: false` in `config/config.yaml`. Useful for running on a server or Raspberry Pi without a display.

## Environment Variables

Copy `.env.example` to `.env` and fill in any secrets (IoT credentials, etc.):

```bash
cp .env.example .env
```

The config file supports `${VARIABLE_NAME}` substitution from `.env`.

## Running Tests

```bash
pytest tests/ -v
```

Note: Most tests mock hardware dependencies (PLC, camera) so they run without any physical connections. Tests that import GUI controllers require PySide6 to be installed; tests that import `control_panel_controller` require `pyyaml`.

## Configuration

All system behavior is controlled by `config/config.yaml`. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `modbus.host` | `192.168.1.147` | PLC IP address |
| `modbus.port` | `502` | Modbus TCP port |
| `modbus.read_rate` | `10` | Sensor read frequency (Hz) |
| `gui.enabled` | `true` | Show graphical interface |
| `control.default_mode` | `manual` | Start in Manual or ML mode |
| `ml.model_path` | `data/models/...pkl` | Path to trained ML model |
| `database.sqlite.path` | `data/databases/current` | Where SQLite files are stored |

See `docs/05-configuration.md` for a full configuration reference.

## File Layout

```
smart-saw/
├── config/
│   └── config.yaml          ← Main configuration file
├── data/
│   ├── databases/current/   ← SQLite databases (created at runtime)
│   └── models/              ← ML model (.pkl file)
├── docs/                    ← This documentation
├── logs/                    ← Log files (created at runtime)
├── src/                     ← All source code
├── tests/                   ← Test suite
├── run.py                   ← Launch script
├── setup-autostart.sh       ← systemd deployment helper (Linux)
└── requirements.txt
```

## Production Deployment (Ubuntu 24.04 LTS)

On the target machine the application runs as a systemd service so it starts automatically on boot and restarts after a crash. `setup-autostart.sh` is an interactive menu-driven script that handles the full lifecycle.

**Requirements:** Ubuntu 24.04 LTS, `sudo` access.

```bash
sudo bash setup-autostart.sh
```

The script opens a status screen showing the current state of each component, then a numbered menu:

| Option | Action |
|--------|--------|
| 1 | Install required system packages via `apt` |
| W | Disable Wayland and force X11 (see note below) |
| 2 | Create `venv/` virtualenv |
| 3 | Install `requirements.txt` into the venv |
| 4 | Write `/etc/systemd/system/smart-saw.service` |
| 5 | Enable the service for autostart |
| **6** | **Full setup — runs 1 → 2 → 3 → 4 → 5 in one step** |
| 7 | Start the service now |
| 8 | Stop the service |
| 9 | Show the last 30 lines of journal logs |
| 10 | Disable autostart (keep service file) |
| 11 | Remove the service entirely |

The generated unit file runs `venv/bin/python run.py` as the non-root user who invoked `sudo`, loads secrets from `.env`, and sets `DISPLAY=:0`, `XAUTHORITY`, and `QT_QPA_PLATFORM=xcb` so the Qt GUI appears on the local screen.

### System packages installed by option 1

| Package | Why |
|---------|-----|
| `python3-venv` | Needed to run `python3 -m venv` |
| `python3-dev` | Headers for any compiled wheels |
| `libxcb-cursor0` | PySide6 xcb platform plugin |
| `libxcb-xinerama0` | Multi-monitor support |
| `libxcb-randr0` | Screen resolution queries |
| `libxcb-render-util0` | Render extension helpers |
| `libxkbcommon-x11-0` | Keyboard input under xcb |
| `libgl1` | OpenGL (required by PySide6 and OpenCV) |
| `libglib2.0-0` | GLib base (PySide6 runtime) |

### Wayland vs X11 (Ubuntu 24.04 specific)

Ubuntu 24.04 defaults to a **Wayland** session. The application requires **X11** (`QT_QPA_PLATFORM=xcb`) — it will fail to start under Wayland.

Option **W** in the script edits `/etc/gdm3/custom.conf` to add `WaylandEnable=false` and restarts GDM3. After that, every login will use X11. The status screen will show a red warning if the current session is still Wayland.

You can also do this manually:
```bash
sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
sudo systemctl restart gdm3
```

### First-time setup on a new machine

```bash
sudo bash setup-autostart.sh   # choose W (disable Wayland), then log out/in
sudo bash setup-autostart.sh   # choose 6 (Full setup)
sudo bash setup-autostart.sh   # choose 7 (Start service) to test immediately
```

### Checking logs after deployment

```bash
journalctl -u smart-saw -f          # follow live
journalctl -u smart-saw -n 50       # last 50 lines
```

> The script uses `venv/` (not `.venv/`) as the virtualenv directory. If you created a `.venv/` during development, option 2 will create a separate `venv/` for the service.

---

## Typical Development Workflow

1. Edit source files under `src/`
2. Run tests: `pytest tests/ -v`
3. Launch the app: `python run.py`
4. Check logs in `logs/` if something goes wrong

Log files are written separately per subsystem:
- `logs/app.log` — General application events
- `logs/modbus.log` — PLC communication
- `logs/database.log` — Database operations
- `logs/control.log` — Speed control decisions
- `logs/iot.log` — IoT/MQTT telemetry
