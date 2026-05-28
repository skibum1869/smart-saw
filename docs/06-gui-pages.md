# GUI Pages

The GUI is a fullscreen 1920×1080 PySide6 application. A fixed sidebar (392px wide) holds the navigation. The remaining 1528×1080 area is a `QStackedWidget` where each page lives.

Pages are switched by calling `_switch_page(PageIndex.PAGE_NAME)`, which is available to all controllers via the `switch_page_callback` parameter.

---

## Navigation Sidebar

**File:** `src/gui/controllers/main_controller.py`

The sidebar contains:
- "SMART SAW" logo
- 6 (or 7) navigation buttons, one per page
- System status icon + text at the top of the content area (shows PLC connection state)
- Date and day of week (bottom left)
- Time (top right)

Clicking a nav button checks that button, unchecks all others, and calls `stackedWidget.setCurrentIndex(index)`.

---

## Page 0 — Control Panel

**File:** `src/gui/controllers/control_panel_controller.py`  
**Class:** `ControlPanelController`  
**Lines:** 2,502 — the largest file in the project

This is the primary operator page. It is divided into several frames:

### Cutting Mode Frame (top-left)
Two toggle buttons: **Manual** and **AI**. Switching them calls `ControlManager.set_mode()` asynchronously. Also contains three speed preset buttons: **Slow**, **Normal**, **Fast** — clicking one sets both cutting speed and descent speed to the configured presets.

### Head Height Frame
A vertical progress bar showing the current saw head height (0–350mm). Filled from bottom as the saw descends.

### Band Deviation Frame
A real-time strip chart showing the band deviation (lateral blade drift) over time. The graph scrolls as new data arrives.

### Band Cutting Speed Frame
- Large display: current cutting speed (m/min)
- Sub-frame: band motor current (A) and torque (%)
- Click the frame to open the numpad and manually enter a speed

### Band Descent Speed Frame
- Large display: current descent speed (mm/min)
- Sub-frame: descent motor current (A) and torque (%)
- Click the frame to open the numpad

### Log Viewer Frame (right side)
A scrolling text widget showing application log messages in real time. Color-coded by severity (green INFO, yellow WARNING, red ERROR).

### Cutting Control Frame (bottom)
Five large buttons:
- **Machine Start** — Toggle: activates register 100.1 (bypass interlock). Glows pink when active.
- **Coolant** — Toggle: turns coolant pump on/off
- **Chip Cleaning** — Toggle: turns chip cleaning conveyor on/off
- **Start Cutting** — Momentary: sends the cutting start command to PLC
- **Stop Cutting** — Momentary: sends the cutting stop command to PLC

### Cutting Time Frame (top-right)
Five time displays:
- **Start:** — time when current cut began
- **Duration:** — live counter, increments every second while cutting
- **Remaining:** — estimated time left (green)
- **End:** — timestamp when last cut finished
- **Previous:** — duration of the last completed cut (orange)

---

## Page 1 — Auto Cutting

**File:** `src/gui/controllers/otomatik_kesim_controller.py`  
**Class:** `AutoCuttingController`  
**Lines:** 1,206

Used for batch cutting operations: operator enters parameters, presses START, and the machine automatically cuts a specified number of pieces.

### Parameter Frames (left column)
Five tappable frames — tapping any one opens the numpad:

| Parameter | Description | Range |
|-----------|-------------|-------|
| **P** | Pieces per package | 1–9999 |
| **X** | Package count | 1–999 |
| **L** | Cut length (mm) | 1–99999 |
| **C** | Cutting speed (m/min) | 0–500 |
| **S** | Descent speed (mm/min) | 0–500 |

A **Total** label below P and X shows P × X (total number of pieces to cut).

All parameters lock (grey out) once cutting starts.

### Counter Frame (right column, top)
Shows `current / target` count in large text (e.g., `7 / 20`) with a progress bar below. Turns green when target is reached.

### Control Frame (right column, bottom)
- **START** — Validates params, writes them to PLC registers, issues start command. Becomes "IN PROGRESS..." during cutting.
- **RESET** (hold 1.5 seconds) — Resets the cut counter. A pink progress overlay fills the button as you hold.
- **CANCEL** — Cancels the operation, resets UI state.
- **Auto Cutting Mode** toggle — Enables the PLC's own auto-cut mode (register 2).

### Mode Card (bottom-left)
**Manual** / **AI** toggle — same as Control Panel, switches the `ControlManager` mode.

---

## Page 2 — Positioning

**File:** `src/gui/controllers/positioning_controller.py`  
**Class:** `PositioningController`  
**Lines:** 785

For manual machine positioning — used before starting a cut to set up the material.

### Vise Control (left)
Three icon buttons for vise operations. Each is a toggle (press to activate, press again to deactivate):
- **Rear Vise Open** — Opens the rear clamp
- **Vise Close/Clamp** — Closes/tightens vise
- **Front Vise Open** — Opens the front clamp

### Material Positioning (center)
Two large hold-to-activate buttons:
- **Material Back** — Hold to move material backward (feeding direction)
- **Material Forward** — Hold to move material forward

These are hold buttons: the command is active only while the button is pressed. Works with both mouse and touch events.

### Saw Positioning (right)
Two hold buttons:
- **Saw Up** — Hold to raise the saw head
- **Saw Down** — Hold to lower the saw head

---

## Page 3 — Sensor Data

**File:** `src/gui/controllers/sensor_controller.py`  
**Class:** `SensorController`  
**Lines:** 1,514

Real-time sensor graphs with anomaly detection status.

### Cutting Graph (left, large)
A live line chart showing one selected sensor over time. X-axis and Y-axis are selectable via buttons in the two frames below.

**Y-axis (what to plot):** Cutting Speed, Descent Speed, Band Current, Band Deviation, Band Torque, Band Tension

**X-axis (time basis):** Time (seconds), Height (mm)

### Anomaly Status (right column)
One status card per monitored sensor. Each card shows:
- Sensor name
- Current value
- Status text ("All OK." / warning message)
- Color: green = normal, yellow = warning, red = critical

A **Reset** button clears all anomaly states, useful after a known event.

---

## Page 4 — Monitoring

**File:** `src/gui/controllers/monitoring_controller.py`  
**Class:** `MonitoringController`  
**Lines:** 850

A dashboard showing all sensor values simultaneously. No graphs — just current readings in a grid layout.

### Container 1 — Machine & Band Info
Small cards for: Machine ID, Band ID, Band Outer Dimension, Band Type, Band Brand, Band Material

### Container 2 — Motor Data
Cards for: Band Motor Speed (m/min), Descent Motor Speed (mm/min), Band Motor Current (A), Descent Motor Current (A), Band Motor Torque (%), Descent Motor Torque (%), Power (kWh)

### Container 3 — Material Info
Cards for: Material Type, Material Hardness, Cross Section

### Container 4 — Sensor Data
Cards for: Band Deviation (mm), Band Tension (bar), Head Height (mm), Vibration X/Y/Z (g), Vise Pressure (bar), Ambient Temperature (°C), Ambient Humidity (%)

### Container 5 — Status
Cards for: Pieces Cut, Saw Status (current state text), Alarm Status

---

## Page 5 — Alarms

**File:** `src/gui/controllers/alarm_controller.py`  
**Class:** `AlarmController`  
**Lines:** 413

Alarm history and active alarm management.

### Alarm Table
Four columns: **Time**, **Alarm Code**, **Description**, **Status**

Active alarms are shown in red bold text with status "ACTIVE". Resolved alarms show in white with "Resolved".

The table populates from `data/databases/current/alarm.db` which persists across restarts. Alarms are detected by polling registers 1031 (fault status) and 1032 (alarm bitmask) at 2 Hz.

When a new alarm fires, the app **automatically navigates** to this page.

Alarm codes (register 1032 bitmask):

| Bit | Alarm |
|-----|-------|
| 0x0001 | Emergency Button Pressed |
| 0x0002 | Cutting Motor Fault |
| 0x0004 | Hydraulic Motor Fault |
| 0x0008 | Coolant Motor Fault |
| 0x0010 | Conveyor Motor Fault |
| 0x0020 | Brush Motor Fault |
| 0x0040 | Pulley Cover Open |
| 0x0080 | Band Break Fault |
| 0x0100 | Servo Motor Overload |
| 0x0200 | Servo Motor High Temperature |
| 0x0400 | Band Motor Fault |
| 0x0800 | Measurement Calculation Error |
| 0x1000 | Front Vise Error |
| 0x2000 | Servo Resistance Error |

**Reset Alarms** button sets a "reset timestamp" in `alarm.db`. Only alarms after that timestamp are shown, clearing the visible history. Still-active alarms immediately reappear after reset.

---

## Page 6 — Camera (Optional)

**File:** `src/gui/controllers/camera_controller.py`  
**Class:** `CameraController`  
**Lines:** 539

Only shown if a camera is configured. Displays:

- Live camera feed (left panel)
- Sequential inspection frames (center panel, up to 6 tiles)
- **Broken Tooth Detection** section: count, last detection timestamp, WARNING indicator
- **Crack Detection** section: count, last detection timestamp, WARNING indicator
- **Wear Percentage**, **Saw Health** score (0–100)
- **Saw Status** text
- Recording status badge (frame counter / "Recording: —")

The camera controller polls `CameraResultsStore` at 200ms intervals.

---

## Page Layout Summary

| Index | Name | Class | Key Purpose |
|-------|------|-------|-------------|
| 0 | Control Panel | `ControlPanelController` | Day-to-day operation |
| 1 | Auto Cutting | `AutoCuttingController` | Batch cutting jobs |
| 2 | Positioning | `PositioningController` | Setup before cutting |
| 3 | Sensor Data | `SensorController` | Live graphs |
| 4 | Monitoring | `MonitoringController` | All readings at once |
| 5 | Alarms | `AlarmController` | Fault history |
| 6 | Camera | `CameraController` | Blade inspection |
