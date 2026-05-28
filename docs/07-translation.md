# Turkish → English Translation

## Background

The project was originally written in Turkish. All visible UI strings, identifiers, enum values, log messages, and code comments were in Turkish. This document records exactly what was changed, why certain things were left in Turkish, and how backward compatibility was preserved.

---

## What Was Translated

### Enums (`src/domain/enums.py`, `src/core/constants.py`)

`SawState` enum values were renamed:

| Old (Turkish) | New (English) | Integer Value |
|--------------|--------------|---------------|
| `BOSTA` | `IDLE` | 0 |
| `HIDROLIK_AKTIF` | `HYDRAULIC_ACTIVE` | 1 |
| `SERIT_MOTOR_CALISIYOR` | `BAND_MOTOR_RUNNING` | 2 |
| `KESIYOR` | `CUTTING` | 3 |
| `KESIM_BITTI` | `CUTTING_COMPLETE` | 4 |
| `SERIT_YUKARI_CIKIYOR` | `SAW_RISING` | 5 |
| `MALZEME_BESLEME` | `MATERIAL_FEEDING` | 6 |

The class itself was renamed: `TesereDurumu` → `SawState`.

A backward-compatible alias was added at the end of the file:
```python
TesereDurumu = SawState  # backward-compatible alias
```

Similarly in `constants.py`:
- `KATSAYI` → `COEFFICIENT` (with alias `KATSAYI = COEFFICIENT`)
- `INME_HIZI_WRITE_THRESHOLD` → `DESCENT_SPEED_WRITE_THRESHOLD`
- `KESME_HIZI_WRITE_THRESHOLD` → `CUTTING_SPEED_WRITE_THRESHOLD`

---

### Page Index (`src/gui/page_index.py`)

English names became the primary constants; Turkish names became IntEnum aliases:

```python
class PageIndex(IntEnum):
    CONTROL_PANEL = 0   # was KONTROL_PANELI
    AUTO_CUTTING  = 1   # was OTOMATIK_KESIM
    POSITIONING   = 2   # was KONUMLANDIRMA
    SENSOR        = 3   # (unchanged)
    MONITORING    = 4   # was IZLEME
    ALARM         = 5   # (unchanged)
    CAMERA        = 6   # was KAMERA

    # Backward-compatible aliases (IntEnum allows duplicate values)
    KONTROL_PANELI = 0
    OTOMATIK_KESIM = 1
    KONUMLANDIRMA  = 2
    IZLEME         = 4
    KAMERA         = 6
```

---

### Controller Classes

`OtomatikKesimController` was renamed to `AutoCuttingController`. A backward-compatible alias was appended to the bottom of the file:

```python
OtomatikKesimController = AutoCuttingController  # backward-compatible alias
```

The import in `main_controller.py` was updated:
```python
from .otomatik_kesim_controller import OtomatikKesimController as AutoCuttingController
```

The internal attribute `_prev_testere_durumu` was renamed to `_prev_saw_state` in both the production code and the test file.

---

### UI Strings

Every visible string in all 8 page controllers was translated:

**Buttons:**
- "Manuel" → "Manual"
- "Yapay Zeka" → "AI"
- "İPTAL" → "CANCEL"
- "Makine Başlat" → "Machine Start"
- "Soğutma Sıvısı" → "Coolant"
- "Talaş Temizliği" → "Chip Cleaning"
- "Kesim Başlat" → "Start Cutting"
- "Kesim Durdur" → "Stop Cutting"
- "Alarmları Sıfırla" → "Reset Alarms"

**Frame titles:**
- "Kesim Modu" → "Cutting Mode"
- "Hız Seçimi" → "Speed Selection"
- "Kafa Yüksekliği" → "Head Height"
- "Şerit Sapması" → "Band Deviation"
- "Kesim Kontrol" → "Cutting Control"
- "Kesim Zamanı" → "Cutting Time"
- "Çalışma Günlüğü" → "Activity Log"
- "Sayaç" → "Counter"
- "Kesim Modu" → "Cutting Mode"
- "Mengene Kontrolü" → "Vise Control"
- "Malzeme Konumlandırma" → "Material Positioning"
- "Testere Konumlandırma" → "Saw Positioning"
- "Anomali Durumu" → "Anomaly Status"

**Parameter labels:**
- "Paketteki Adet" → "Pieces per Package"
- "Paket Sayısı" → "Package Count"
- "Uzunluk (mm)" → "Length (mm)"
- "Kesim Hızı (m/dk)" → "Cutting Speed (m/min)"
- "İlerleme Hızı (mm/dk)" → "Descent Speed (mm/min)"
- "Toplam: X adet" → "Total: X pcs"

**Status strings (machine states):**

These are used as dictionary keys across `control_panel_controller.py` and `monitoring_controller.py`, so they had to be changed consistently:

| Old | New |
|-----|-----|
| "BAĞLANTI BEKLENİYOR" | "AWAITING CONNECTION" |
| "BOŞTA" | "IDLE" |
| "HİDROLİK AKTİF" | "HYDRAULIC ACTIVE" |
| "ŞERİT MOTOR ÇALIŞIYOR" | "BAND MOTOR RUNNING" |
| "KESİM YAPILIYOR" | "CUTTING" |
| "KESİM BİTTİ" | "CUTTING COMPLETE" |
| "ŞERİT YUKARI ÇIKIYOR" | "SAW RISING" |
| "MALZEME BESLEME" | "MATERIAL FEEDING" |
| "BİLİNMİYOR" | "UNKNOWN" |
| "Bağlantı Yok" | "No Connection" |
| "Veri bekleniyor..." | "Awaiting data..." |
| "Bağlantı Kontrol Ediliyor..." | "Checking Connection..." |

**Log messages:** All `self.add_log(...)` calls in `control_panel_controller.py` were translated from Turkish to English.

**Monitoring labels:** All sensor name labels in `monitoring_controller.py` were translated (Machine ID, Band ID, Band Motor Speed, Ambient Temperature, etc.).

**Sensor controller:** Axis title dicts, button labels, anomaly status text ("Her şey yolunda." → "All OK.").

**Camera controller:** Feed labels, detection labels, status badges.

**Alarm controller:** Column headers, status text, alarm descriptions.

**Day names:** The datetime display in `main_controller.py` was changed from Turkish day names (Pazartesi, Salı…) to English (Monday, Tuesday…).

---

## What Was NOT Translated (Intentional)

### Modbus Data Pipeline Keys

The dict keys used throughout the data pipeline remain in Turkish:

```python
data.get('testere_durumu', 0)
data.get('serit_kesme_hizi', 0)
data.get('kafa_yuksekligi_mm', 0)
data.get('serit_motor_akim_a', 0)
# ... etc.
```

**Why:** These keys are **database column names** in `total.db` and `raw.db`. They appear in:
- `schemas.py` — CREATE TABLE column definitions
- `data_processor.py` — dict construction
- Every GUI controller — data display
- IoT clients — telemetry field names
- SQL indexes (`idx_sensor_testere_durumu`)

Renaming them would require a coordinated database migration (or schema recreation) across all four databases, updates to every SQL query, and changes to any external dashboards reading those field names from ThingsBoard. This was considered too risky to do as part of a translation pass.

**If you want to rename them in future:** Write a database migration script that renames the columns (SQLite requires recreating the table), update `schemas.py`, and do a global search/replace for each key name.

### File Names

The file `otomatik_kesim_controller.py` was not renamed (would require updating all imports and could confuse git history). The class inside was renamed, and a backward-compatible alias added.

### Comment-Only Turkish Text

A small number of code comments and docstring examples still contain Turkish words — these are structural comments ("CONTAINER 1: Makine & Şerit Bilgileri") or historical notes. They do not affect runtime behavior.

---

## Files Changed

18 files were modified:

| File | Change |
|------|--------|
| `src/domain/enums.py` | `TesereDurumu` → `SawState`, enum values translated, alias added |
| `src/domain/__init__.py` | Added `SawState` export |
| `src/domain/models.py` | Updated import |
| `src/core/constants.py` | Constants renamed, aliases added |
| `src/core/__init__.py` | Added `SawState` export |
| `src/services/processing/cutting_tracker.py` | Updated enum references |
| `src/gui/page_index.py` | English primaries, Turkish aliases |
| `src/gui/numpad.py` | One debug print line |
| `src/gui/controllers/main_controller.py` | Nav buttons, day names, status text, page refs |
| `src/gui/controllers/otomatik_kesim_controller.py` | Class rename, all UI strings, validation errors |
| `src/gui/controllers/control_panel_controller.py` | All UI strings, log messages, status dicts |
| `src/gui/controllers/monitoring_controller.py` | All sensor label strings, state dict |
| `src/gui/controllers/positioning_controller.py` | Frame titles |
| `src/gui/controllers/sensor_controller.py` | Axis titles, button labels, status text |
| `src/gui/controllers/alarm_controller.py` | Column headers, alarm descriptions, status text |
| `src/gui/controllers/camera_controller.py` | All label and status strings |
| `tests/test_otomatik_kesim_controller.py` | Class name, attribute name, assertion strings |
| `tests/test_page_index.py` | Added English constant assertions, kept Turkish alias assertions |

---

## Backward Compatibility

All renamed identifiers have aliases so existing code that hasn't been updated will continue to work:

```python
# These all still work:
PageIndex.KONTROL_PANELI      # == PageIndex.CONTROL_PANEL == 0
TesereDurumu.KESIYOR          # == SawState.CUTTING == 3
OtomatikKesimController(...)  # == AutoCuttingController(...)
```

If you are writing new code, use the English names. Remove the Turkish aliases once all call sites have been updated.
