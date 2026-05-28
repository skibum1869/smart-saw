"""
Domain enumerations.
"""

from enum import Enum


class SawState(Enum):
    """
    Saw machine operational states.

    Values match Modbus register values from PLC.
    """
    IDLE = 0                # Machine is idle
    HYDRAULIC_ACTIVE = 1    # Hydraulic active
    BAND_MOTOR_RUNNING = 2  # Band motor running
    CUTTING = 3             # Actively cutting
    CUTTING_COMPLETE = 4    # Cutting completed
    SAW_RISING = 5          # Saw moving up
    MATERIAL_FEEDING = 6    # Material feeding


# Backward-compatible alias
TesereDurumu = SawState


class ControlMode(Enum):
    """Control operation modes."""
    MANUAL = "manual"  # Manual speed control (GUI-driven)
    ML = "ml"          # ML-based automatic control
