#!/usr/bin/env bash
# Smart Saw — setup and management tool
# Usage: sudo bash setup-autostart.sh
#
# Tested on: Ubuntu 24.04 LTS (requires systemd + X11)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="smart-saw"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
VENV_DIR="${PROJECT_DIR}/venv"
RUN_USER="${SUDO_USER:-$(whoami)}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Helpers ---
info()    { echo -e "${CYAN}►${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}!${NC} $1"; }
fail()    { echo -e "${RED}✗${NC} $1"; }

header() {
    echo
    echo -e "${BOLD}━━━ $1 ━━━${NC}"
    echo
}

status_line() {
    local label="$1" value="$2" color="${3:-$NC}"
    printf "  %-24s ${color}%s${NC}\n" "$label" "$value"
}

# --- Status checks ---
check_venv()    { [ -d "${VENV_DIR}/bin" ]; }
check_deps()    { check_venv && "${VENV_DIR}/bin/python" -c "import pymodbus, PySide6" 2>/dev/null; }
check_unit()    { [ -f "${SERVICE_FILE}" ]; }
check_enabled() { systemctl is-enabled "${SERVICE_NAME}" &>/dev/null; }
check_running() { systemctl is-active  "${SERVICE_NAME}" &>/dev/null; }
check_wayland() {
    # Returns true (exit 0) if the current session is Wayland
    local session_type
    session_type=$(loginctl show-session \
        "$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="${RUN_USER}" '$3==u {print $1; exit}')" \
        -p Type --value 2>/dev/null || echo "unknown")
    [[ "${session_type}" == "wayland" ]]
}

status_tag() {
    if $1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${DIM}–${NC}"
    fi
}

# --- Status screen ---
show_status() {
    header "Smart Saw Status"
    status_line "Project directory"  "${PROJECT_DIR}"
    status_line "Run as user"        "${RUN_USER}"
    echo
    status_line "Virtualenv"         "$(check_venv    && echo 'present'   || echo 'missing')"   "$(check_venv    && echo "$GREEN" || echo "$DIM")"
    status_line "Dependencies"       "$(check_deps    && echo 'installed' || echo 'missing')"   "$(check_deps    && echo "$GREEN" || echo "$YELLOW")"
    status_line "Systemd unit"       "$(check_unit    && echo 'written'   || echo 'missing')"   "$(check_unit    && echo "$GREEN" || echo "$DIM")"
    status_line "Autostart service"  "$(check_enabled && echo 'enabled'   || echo 'disabled')"  "$(check_enabled && echo "$GREEN" || echo "$DIM")"
    status_line "Running state"      "$(check_running && echo 'running'   || echo 'stopped')"   "$(check_running && echo "$GREEN" || echo "$DIM")"
    if check_wayland 2>/dev/null; then
        status_line "Display session"  "WAYLAND — X11 required!" "$RED"
    fi
    echo
}

# --- Actions ---

# System packages required on Ubuntu 24.04 LTS before the venv can be built
# and PySide6's xcb platform plugin can load.
SYSTEM_PACKAGES=(
    python3-venv          # python3 -m venv
    python3-dev           # headers for any compiled wheels
    libxcb-cursor0        # PySide6 xcb platform plugin
    libxcb-xinerama0      # multi-monitor support
    libxcb-randr0         # screen resolution queries
    libxcb-render-util0   # render extension helpers
    libxkbcommon-x11-0    # keyboard input under xcb
    libgl1                # OpenGL (PySide6 / OpenCV)
    libglib2.0-0          # GLib base (PySide6 runtime)
)

do_system_deps() {
    header "Install System Packages (Ubuntu 24.04)"
    if ! command -v apt-get &>/dev/null; then
        warn "apt-get not found — skipping (not an Ubuntu/Debian system)."
        return 0
    fi
    info "Updating package index..."
    apt-get update -qq
    info "Installing required packages..."
    apt-get install -y "${SYSTEM_PACKAGES[@]}"
    success "System packages installed."
    echo
    warn "Wayland note: Ubuntu 24.04 defaults to Wayland."
    warn "The application requires X11 (QT_QPA_PLATFORM=xcb)."
    warn "To force X11 at login, run option [W] or do it manually:"
    warn "  sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf"
    warn "  sudo systemctl restart gdm3"
}

do_disable_wayland() {
    header "Disable Wayland (Force X11)"
    local gdm_conf="/etc/gdm3/custom.conf"
    if [ ! -f "${gdm_conf}" ]; then
        fail "GDM3 config not found at ${gdm_conf} — is GDM3 installed?"
        return 1
    fi
    if grep -q "^WaylandEnable=false" "${gdm_conf}"; then
        success "Wayland is already disabled in ${gdm_conf}."
        return 0
    fi
    # Uncomment the line if it exists commented out, otherwise append it
    if grep -q "^#WaylandEnable=false" "${gdm_conf}"; then
        sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' "${gdm_conf}"
    else
        # Insert under [daemon] section if present, otherwise append
        if grep -q "^\[daemon\]" "${gdm_conf}"; then
            sed -i '/^\[daemon\]/a WaylandEnable=false' "${gdm_conf}"
        else
            echo -e "\n[daemon]\nWaylandEnable=false" >> "${gdm_conf}"
        fi
    fi
    success "WaylandEnable=false written to ${gdm_conf}."
    info "Restarting GDM3 to apply..."
    systemctl restart gdm3
    success "GDM3 restarted. Next login will use X11."
}

do_venv() {
    header "Create Virtualenv"
    if check_venv; then
        warn "Virtualenv already exists: ${VENV_DIR}"
        read -rp "  Recreate from scratch? [y/N] " ans
        [[ "${ans,,}" == "y" ]] || return 0
        info "Removing old venv..."
        rm -rf "${VENV_DIR}"
    fi
    info "Creating virtualenv..."
    python3 -m venv "${VENV_DIR}"
    success "Virtualenv ready: ${VENV_DIR}"
}

do_deps() {
    header "Install Python Dependencies"
    if ! check_venv; then
        fail "Create a virtualenv first."
        return 1
    fi
    info "Upgrading pip..."
    "${VENV_DIR}/bin/pip" install --quiet --upgrade pip
    info "Installing requirements.txt..."
    "${VENV_DIR}/bin/pip" install -r "${PROJECT_DIR}/requirements.txt"
    success "Dependencies installed."
}

do_install_service() {
    header "Install Systemd Service"
    info "Writing service file: ${SERVICE_FILE}"
    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Smart Band Saw Control System
After=network.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=${RUN_USER}
WorkingDirectory=${PROJECT_DIR}
EnvironmentFile=${PROJECT_DIR}/.env
ExecStart=${VENV_DIR}/bin/python ${PROJECT_DIR}/run.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/${RUN_USER}/.Xauthority
Environment=QT_QPA_PLATFORM=xcb

[Install]
WantedBy=graphical-session.target
EOF
    systemctl daemon-reload
    success "Service file written and daemon reloaded."
}

do_enable() {
    header "Enable Autostart Service"
    if ! check_unit; then
        fail "Install the service first."
        return 1
    fi
    systemctl enable "${SERVICE_NAME}.service"
    success "Service will start automatically on boot."
}

do_disable() {
    header "Disable Autostart Service"
    if ! check_unit; then
        fail "Service file not found."
        return 1
    fi
    systemctl disable "${SERVICE_NAME}.service"
    success "Service will not start on boot."
}

do_start() {
    header "Start Service"
    if ! check_unit; then
        fail "Install the service first."
        return 1
    fi
    systemctl start "${SERVICE_NAME}.service"
    sleep 1
    if check_running; then
        success "Service is running."
    else
        fail "Service failed to start. Logs:"
        journalctl -u "${SERVICE_NAME}" -n 10 --no-pager
    fi
}

do_stop() {
    header "Stop Service"
    if check_running; then
        systemctl stop "${SERVICE_NAME}.service"
        success "Service stopped."
    else
        warn "Service is not running."
    fi
}

do_logs() {
    header "Service Logs (last 30 lines)"
    journalctl -u "${SERVICE_NAME}" -n 30 --no-pager
    echo
    info "Follow live: journalctl -u ${SERVICE_NAME} -f"
}

do_uninstall() {
    header "Remove Service"
    if check_running; then
        info "Stopping service..."
        systemctl stop "${SERVICE_NAME}.service"
    fi
    if check_enabled; then
        info "Disabling service..."
        systemctl disable "${SERVICE_NAME}.service"
    fi
    if check_unit; then
        info "Deleting service file..."
        rm -f "${SERVICE_FILE}"
        systemctl daemon-reload
    fi
    success "Service fully removed."
}

do_full_setup() {
    header "Full Setup"
    info "Running all steps in order."
    echo
    do_system_deps
    do_venv
    do_deps
    do_install_service
    do_enable
    echo
    success "Full setup complete. Service will start on next boot."
    echo
    if check_wayland 2>/dev/null; then
        warn "WARNING: Active session is Wayland. Run option [W] to force X11,"
        warn "then log out and back in before starting the service."
    fi
}

# --- Menu ---
show_menu() {
    echo -e "${BOLD}  Setup${NC}"
    echo "    1)  Install system packages (Ubuntu 24.04)"
    echo "    W)  Disable Wayland / force X11 (Ubuntu 24.04)"
    echo "    2)  Create virtualenv"
    echo "    3)  Install Python dependencies"
    echo "    4)  Install systemd service"
    echo "    5)  Enable autostart"
    echo "    6)  Full setup (1→2→3→4→5)"
    echo
    echo -e "${BOLD}  Control${NC}"
    echo "    7)  Start service"
    echo "    8)  Stop service"
    echo "    9)  Show logs"
    echo
    echo -e "${BOLD}  Remove${NC}"
    echo "   10)  Disable autostart"
    echo "   11)  Remove service entirely"
    echo
    echo "    0)  Exit"
    echo
}

# --- Main loop ---
main() {
    while true; do
        show_status
        show_menu
        read -rp "  Choice: " choice
        case "${choice}" in
            1)   do_system_deps ;;
            [Ww]) do_disable_wayland ;;
            2)   do_venv ;;
            3)   do_deps ;;
            4)   do_install_service ;;
            5)   do_enable ;;
            6)   do_full_setup ;;
            7)   do_start ;;
            8)   do_stop ;;
            9)   do_logs ;;
            10)  do_disable ;;
            11)  do_uninstall ;;
            0)   echo; exit 0 ;;
            *)   warn "Invalid choice." ;;
        esac
        echo
        read -rp "  Press Enter to continue..." _
    done
}

main
