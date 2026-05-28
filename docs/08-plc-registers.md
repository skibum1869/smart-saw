# PLC Register Map

The application communicates with the PLC over Modbus TCP. This document covers the full register address map: what addresses are read, what the raw values mean, how they are scaled, and which addresses the software writes to.

---

## Read Registers — Sensor Block (1000–1043)

The reader fetches 44 consecutive holding registers in one Modbus FC03 request starting at address **1000**. The raw integer from the PLC is scaled to engineering units as shown.

| Offset | Address | Pipeline Key | Description | Scale | Unit |
|--------|---------|-------------|-------------|-------|------|
| 0 | 1000 | `makine_id` | Machine ID | ×1 | — |
| 1 | 1001 | `serit_id` | Band ID | ×1 | — |
| 2 | 1002 | `serit_dis_mm` | Band tooth pitch | ×1 | mm |
| 3 | 1003 | `serit_tip` | Band type code | ×1 | — |
| 4 | 1004 | `serit_marka` | Band brand code | ×1 | — |
| 5 | 1005 | `serit_malz` | Band material code | ×1 | — |
| 6 | 1006 | `malzeme_cinsi` | Material type code | ×1 | — |
| 7 | 1007 | `malzeme_sertlik` | Material hardness code | ×1 | — |
| 8 | 1008 | `kesit_yapisi` | Cross-section code | ×1 | — |
| 9 | 1009 | `a_mm` | Material dim A | ×1 | mm |
| 10 | 1010 | `b_mm` | Material dim B | ×1 | mm |
| 11 | 1011 | `c_mm` | Material dim C | ×1 | mm |
| 12 | 1012 | `d_mm` | Material dim D | ×1 | mm |
| 13 | 1013 | `kafa_yuksekligi_mm` | Head height | ÷10 | mm |
| 14 | 1014 | `kesilen_parca_adeti` | Pieces cut | ×1 | pcs |
| 15 | 1015 | `serit_motor_akim_a` | Band motor current | ÷10 | A |
| 16 | 1016 | `serit_motor_tork_percentage` | Band motor torque | ÷10 | % |
| 17 | 1017 | `inme_motor_akim_a` | Descent motor current | ÷100 | A |
| 18 | 1018 | `inme_motor_tork_percentage` | Descent motor torque | ×1 | % |
| 19 | 1019 | `mengene_basinc_bar` | Vise pressure | ÷10 | bar |
| 20 | 1020 | `serit_gerginligi_bar` | Band tension | ÷10 | bar |
| 21 | 1021 | `ivme_olcer_x` | X-axis vibration | ×1 | g |
| 22 | 1022 | `ivme_olcer_y` | Y-axis vibration | ×1 | g |
| 23 | 1023 | `ivme_olcer_z` | Z-axis vibration | ×1 | g |
| 24 | 1024 | `serit_sapmasi` | Band deviation (signed) | ÷100 | mm |
| 25 | 1025 | `ortam_sicakligi_c` | Ambient temperature | ÷10 | °C |
| 26 | 1026 | `ortam_nem_percentage` | Ambient humidity | ÷10 | % |
| 27 | 1027 | `sogutma_sivi_sicakligi_c` | Coolant temperature | ÷10 | °C |
| 28 | 1028 | `hidrolik_yag_sicakligi_c` | Hydraulic oil temperature | ÷10 | °C |
| 29 | 1029 | `serit_sicakligi_c` | Band temperature | ×1 | °C |
| 30 | 1030 | `testere_durumu` | Saw state (0–6) | ×1 | — |
| 31 | 1031 | `alarm_status` | Fault active flag | ×1 | — |
| 32 | 1032 | `alarm_bilgisi` | Alarm bitmask | ×1 | hex |
| 33 | 1033 | `serit_kesme_hizi` | Cutting speed feedback | ÷10 | m/min |
| 34 | 1034 | `serit_inme_hizi` | Descent speed feedback | special | mm/min |
| 35 | 1035 | `ivme_olcer_x_hz` | X vibration frequency | ×1 | Hz |
| 36 | 1036 | `ivme_olcer_y_hz` | Y vibration frequency | ×1 | Hz |
| 37 | 1037 | `ivme_olcer_z_hz` | Z vibration frequency | ×1 | Hz |
| 38 | 1038 | `fark_hz_x` | X frequency delta | ÷100 | Hz |
| 39 | 1039 | `fark_hz_y` | Y frequency delta | ÷100 | Hz |
| 40 | 1040 | `fark_hz_z` | Z frequency delta | ÷100 | Hz |
| 41 | 1041 | `malzeme_genisligi` | Material width | ÷10 | mm |
| 42 | 1042 | `guc` | Power | ×1 | kWh |
| 43 | 1043 | `guc2` | Power 2 | ×1 | kWh |

> **Note on offset 34 (`serit_inme_hizi`):** Descent speed uses special signed handling via `sanitize_signed_register()` because the PLC encodes negative (upward) movement as a large unsigned integer. After sign correction the value is divided by 100.

---

## Read Registers — Target Speed Readback (2041, 2066)

These two registers are read back separately (not in the 44-register block) so the GUI can display what speed target is currently in effect.

| Address | Pipeline Key | Description | Scale | Unit |
|---------|-------------|-------------|-------|------|
| 2041 | `inme_hizi_target` | Descent speed setpoint | ÷100 | mm/min |
| 2066 | `kesme_hizi_target` | Cutting speed setpoint | ÷10 | m/min |

---

## Saw State Values (register 1030 / `testere_durumu`)

| Raw Value | `SawState` Enum | Display String |
|-----------|----------------|----------------|
| 0 | `SawState.IDLE` | IDLE |
| 1 | `SawState.HYDRAULIC_ACTIVE` | HYDRAULIC ACTIVE |
| 2 | `SawState.BAND_MOTOR_RUNNING` | BAND MOTOR RUNNING |
| 3 | `SawState.CUTTING` | CUTTING |
| 4 | `SawState.CUTTING_COMPLETE` | CUTTING COMPLETE |
| 5 | `SawState.SAW_RISING` | SAW RISING |
| 6 | `SawState.MATERIAL_FEEDING` | MATERIAL FEEDING |

---

## Alarm Bitmask (register 1032 / `alarm_bilgisi`)

Each bit represents one fault condition. Multiple alarms can be active simultaneously.

| Bit (hex) | Alarm |
|-----------|-------|
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

---

## Write Registers — Speed Setpoints

These are written by `ModbusWriter` (the async ML/manual control path) up to 10 Hz, subject to write thresholds configured in `ml.write_thresholds`.

| Address | Description | Scale | Unit |
|---------|-------------|-------|------|
| 2041 | Descent speed setpoint | ×100 | mm/min → raw |
| 2066 | Cutting speed setpoint | ×10 | m/min → raw |

---

## Write Registers — Auto Cutting Parameters

Written by `MachineControl` when the operator starts a batch cutting job from Page 1 (Auto Cutting).

| Address | Description | Scale | Notes |
|---------|-------------|-------|-------|
| 2 | Auto cutting mode | ×1 | 1 = on, 0 = off |
| 2050 | Target piece count (P) | ×1 | Pieces per package |
| 2064–2065 | Cut length (L) | ×10 | 32-bit doubleword, mm |
| 2056 | Cut piece count readback | ×1 | Read to update counter |
| 2070 | Package count (X) | ×1 | Number of packages |

> **L (cut length)** is a 32-bit value written as two consecutive 16-bit registers (2064 high word, 2065 low word) using `write_registers()`. The value is multiplied by 10 before writing.

---

## Write Registers — Control Bits (read-modify-write)

These registers hold packed bit fields. Each operation reads the current register value, sets or clears the target bit, then writes the result back. This is a **read-modify-write** cycle and is not atomic — it should not be called concurrently.

### Register 20 — Main Control

| Bit | Constant | Function |
|-----|----------|---------|
| 3 | `CUTTING_START_BIT` | Start cutting (momentary, set to 1) |
| 4 | `CUTTING_STOP_BIT` | Stop cutting (momentary, set to 1) |
| 5 | `REAR_VISE_OPEN_BIT` | Rear vise open (hold to activate) |
| 6 | `FRONT_VISE_OPEN_BIT` | Front vise open (hold to activate) |
| 7 | `MATERIAL_FORWARD_BIT` | Material forward (hold) |
| 8 | `MATERIAL_BACKWARD_BIT` | Material backward (hold) |
| 9 | `SAW_UP_BIT` | Saw head up (hold) |
| 10 | `SAW_DOWN_BIT` | Saw head down (hold) |
| 13 | `AUTO_CUTTING_START_BIT` | Auto cutting start |
| 14 | `AUTO_CUTTING_RESET_BIT` | Auto cutting counter reset |

### Register 40 — Length Confirmation

| Bit | Coil Address | Constant | Function |
|-----|-------------|----------|---------|
| 10 | 650 | `UZUNLUK_CONFIRM_BIT` | Confirm L value written (set after writing register 2064–2065) |

> **Coil address formula:** coil = register × 16 + bit. Register 40, bit 10 → coil 650.
> The confirm bit is written via `write_coil()` (Modbus FC05), not via read-modify-write.

### Register 102 — Machine Start / Chip Cleaning

| Bit | Constant | Function |
|-----|----------|---------|
| 0 | `MACHINE_START_BIT` | Machine start (back cover bypass) — glows pink when active |
| 3 | `CHIP_CLEANING_BIT` | Chip cleaning conveyor |

### Register 2000 — Coolant

| Bit | Constant | Function |
|-----|----------|---------|
| 1 | `COOLANT_BIT` | Coolant pump on/off |

---

## Notes on Scaling

The PLC stores all decimal values as integers by multiplying by a fixed factor before storing. The reader divides by the same factor to recover the engineering value:

| Factor | Registers using it |
|--------|--------------------|
| ×10 | Head height, most current/torque/speed/temperature sensors |
| ×100 | Band deviation, descent speed, some frequency deltas |
| ×1 | Integer codes (state, alarms, IDs), raw counts |

When **writing**, the application multiplies back by the same factor. For example, writing `58.0 m/min` to register 2066 sends `580` to the PLC.

---

## Config Register Map vs. Actual Addresses

`config.yaml` contains a `registers:` section with named constants (e.g., `KAFA_YUKSEKLIK: 2000`). These were defined for an earlier register layout. The actual reader does **not** use this map — it always reads starting at address 1000 with a fixed offset table. The config map is kept for documentation purposes but is not authoritative; the offsets above and in `src/services/modbus/reader.py` are the ground truth.
