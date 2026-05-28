"""Page index constants for sidebar navigation."""

from enum import IntEnum


class PageIndex(IntEnum):
    """Named page indices for QStackedWidget navigation.

    Values must match the addWidget() insertion order in MainController._setup_ui().
    """
    CONTROL_PANEL = 0
    AUTO_CUTTING  = 1
    POSITIONING   = 2
    SENSOR        = 3
    MONITORING    = 4
    ALARM         = 5
    CAMERA        = 6

    # Backward-compatible aliases
    KONTROL_PANELI = 0
    OTOMATIK_KESIM = 1
    KONUMLANDIRMA  = 2
    IZLEME         = 4
    KAMERA         = 6
