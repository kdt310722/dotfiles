#!/usr/bin/env bash

# ============================================
# 💻 CROSS-PLATFORM TOOLS INSTALLER
# ============================================
# Standalone installer for essential development tools
# Supports: macOS, Ubuntu, Debian, Fedora, Arch Linux

set -euo pipefail

# ============================================
# 📦 PACKAGE CONFIGURATION (EDIT HERE)
# ============================================

# Common packages available with the same name on both macOS and Linux
readonly PACKAGES_COMMON=(
    # Network tools
    curl wget openssl
    # Text processing
    nano vim grep gawk jq
    # Compression
    zip unzip gzip
    # System utilities
    zsh htop git tree gpg
    # Modern CLI tools
    bat fzf ripgrep
    # Development
    python3
)

# macOS-specific packages (Homebrew)
readonly PACKAGES_MACOS=(
    gnu-sed         # GNU sed (macOS has BSD sed by default)
    eza             # Modern ls replacement
    fd              # Modern find replacement
    terminal-notifier
)

# Linux-specific packages (apt/dnf/pacman)
readonly PACKAGES_LINUX=(
    # Network diagnostics
    net-tools iputils-ping traceroute dnsutils
    # System utilities
    sed bzip2 libnotify-bin
    # Development tools
    build-essential python3-pip
    # Modern CLI tools (different package names)
    fd-find         # Named 'fd' on macOS, 'fd-find' on Debian
)

# ============================================
# 🔧 CONFIGURATION
# ============================================
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/.logs/install-tools"
readonly LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
readonly LOCK_FILE="/tmp/install-tools.lock"

# Installation settings
readonly MAX_RETRIES=3
readonly PARALLEL_JOBS=4
readonly RETRY_DELAY=2

# ============================================
# 🎨 COLOR DEFINITIONS
# ============================================
readonly COLOR_RESET='\033[0m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_DIM='\033[2m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'

# ============================================
# 📝 LOGGING FUNCTIONS
# ============================================

# Log file descriptor (initialized in init_logging)
LOG_FD=""

log_to_file() {
    if [[ -n "$LOG_FD" ]]; then
        echo "$1" >&$LOG_FD
    fi
}

log_cmd_output() {
    local pkg="$1"
    shift
    {
        echo ""
        echo "========================================"
        echo "=== $(date '+%Y-%m-%d %H:%M:%S'): Installing $pkg ==="
        echo "Command: $*"
        echo "========================================"
        "$@" 2>&1
        local exit_code=$?
        echo "========================================"
        echo "=== Exit code: $exit_code ==="
        echo "========================================"
        return $exit_code
    } >&$LOG_FD
}

init_logging() {
    mkdir -p "$LOG_DIR"
    # Open log file descriptor
    exec {LOG_FD}>>"$LOG_FILE"
    log_to_file "=== Install Tools started at $(date) ==="
    log_to_file "=== OS: $OS_TYPE | Distro: ${DISTRO:-unknown} ==="
}

log_info() {
    printf "${COLOR_BLUE}i${COLOR_RESET}  %s\n" "$1"
}

log_success() {
    printf "${COLOR_GREEN}+${COLOR_RESET}  %s\n" "$1"
}

log_error() {
    printf "${COLOR_RED}x${COLOR_RESET}  %s\n" "$1" >&2
}

log_warn() {
    printf "${COLOR_YELLOW}!${COLOR_RESET}  %s\n" "$1"
}

log_step() {
    printf "\n${COLOR_CYAN}${COLOR_BOLD}%s${COLOR_RESET}\n" "$1"
}

# ============================================
# 📊 PROGRESS BAR
# ============================================

# Global variables for progress tracking
declare -g CURRENT_PROGRESS=0
declare -g TOTAL_PACKAGES=0
declare -g PROGRESS_WIDTH=40

init_progress() {
    CURRENT_PROGRESS=0
    TOTAL_PACKAGES=$1
}

show_progress() {
    local current=$1
    local total=$2
    local name="${3:-}"

    if [[ $total -eq 0 ]]; then
        return 0
    fi

    local percentage=$((current * 100 / total))
    local filled=$((percentage * PROGRESS_WIDTH / 100))
    local empty=$((PROGRESS_WIDTH - filled))

    # Build progress bar with ASCII only
    local bar=""
    if [[ $filled -gt 0 ]]; then
        bar+="$(printf '%*s' "$filled" '' | tr ' ' '#')"
    fi
    if [[ $empty -gt 0 ]]; then
        bar+="$(printf '%*s' "$empty" '' | tr ' ' '-')"
    fi

    # Truncate package name if too long
    if [[ ${#name} -gt 25 ]]; then
        name="${name:0:22}..."
    fi

    printf "\r${COLOR_CYAN}[%s]${COLOR_RESET} ${COLOR_BOLD}%3d%%${COLOR_RESET} ${COLOR_DIM}%3d/%3d${COLOR_RESET} %-25s" \
        "$bar" "$percentage" "$current" "$total" "$name"
}

clear_progress() {
    printf "\r%*s\r" $((PROGRESS_WIDTH + 50)) ""
}

finish_progress() {
    show_progress "$TOTAL_PACKAGES" "$TOTAL_PACKAGES" "Done!"
    echo
}

# ============================================
# 🔒 SUDO MANAGEMENT
# ============================================

request_sudo() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Check if already has sudo access
    if sudo -n true 2>/dev/null; then
        return 0
    fi

    # Prompt for password
    echo
    printf "${COLOR_YELLOW}${COLOR_BOLD}[sudo]  Sudo privileges required${COLOR_RESET}\n"
    printf "${COLOR_DIM}   This script needs administrative privileges to install packages.${COLOR_RESET}\n"
    echo

    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        exit 1
    fi

    # Keep sudo alive in background
    (while true; do
        sudo -n true 2>/dev/null || exit
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done) &

    SUDO_KEEPALIVE_PID=$!
    log_success "Sudo privileges granted"
}

cleanup_sudo() {
    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}

# ============================================
# 🔍 SYSTEM DETECTION
# ============================================

detect_os() {
    local os_type
    os_type=$(uname -s)

    case "$os_type" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            log_error "Unsupported operating system: $os_type"
            exit 1
            ;;
    esac
}

detect_distro() {
    if [[ "$OS_TYPE" != "linux" ]]; then
        echo ""
        return 0
    fi

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    case "$DISTRO" in
        ubuntu|debian)
            echo "apt"
            ;;
        fedora|rhel|centos)
            if command -v dnf &>/dev/null; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        arch|manjaro)
            echo "pacman"
            ;;
        *)
            if [[ "$OS_TYPE" == "macos" ]]; then
                echo "brew"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# ============================================
# 📦 PACKAGE MANAGER OPERATIONS
# ============================================

update_package_list() {
    log_step "Updating package list"

    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq
            ;;
        brew)
            brew update --quiet
            ;;
        dnf)
            sudo dnf check-update -y || true
            ;;
        pacman)
            sudo pacman -Sy --noconfirm
            ;;
    esac

    log_success "Package list updated"
}

is_installed() {
    local pkg=$1

    # First check if command exists in PATH
    if command -v "$pkg" &>/dev/null; then
        return 0
    fi

    # Then check package manager specific
    case "$PKG_MANAGER" in
        apt)
            dpkg -s "$pkg" &>/dev/null
            ;;
        brew)
            brew list "$pkg" &>/dev/null 2>&1
            ;;
        dnf)
            rpm -q "$pkg" &>/dev/null
            ;;
        pacman)
            pacman -Q "$pkg" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

install_package_cmd() {
    local pkg=$1

    case "$PKG_MANAGER" in
        apt)
            sudo apt-get install -y -qq "$pkg"
            ;;
        brew)
            brew install "$pkg"
            ;;
        dnf)
            sudo dnf install -y "$pkg"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$pkg"
            ;;
        *)
            log_error "Unknown package manager"
            return 1
            ;;
    esac
}

# ============================================
# 🔧 PACKAGE INSTALLATION WITH RETRY
# ============================================

install_with_retry() {
    local pkg=$1
    local attempt=1

    log_to_file ""
    log_to_file "========================================"
    log_to_file "Installing package: $pkg"
    log_to_file "Max retries: $MAX_RETRIES"
    log_to_file "========================================"

    while [[ $attempt -le $MAX_RETRIES ]]; do
        log_to_file "Attempt $attempt/$MAX_RETRIES for $pkg..."

        if log_cmd_output "$pkg" install_package_cmd "$pkg"; then
            log_to_file "SUCCESS: $pkg installed on attempt $attempt"
            return 0
        fi

        local exit_code=$?

        if [[ $attempt -lt $MAX_RETRIES ]]; then
            log_to_file "FAILED with exit code $exit_code, retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        else
            log_to_file "FAILED permanently after $MAX_RETRIES attempts (exit code: $exit_code)"
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

# ============================================
# 🔌 EXTERNAL INSTALLERS REGISTRY
# ============================================

# Format: tool_name="os1,os2,..."
declare -A EXTERNAL_INSTALLERS=(
    ["zoxide"]="macos,linux"
    ["homebrew"]="macos"
    ["eza_linux"]="linux"
    ["uv"]="macos,linux"
)

install_zoxide() {
    command -v zoxide &>/dev/null && return 2
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

install_homebrew() {
    command -v brew &>/dev/null && return 2
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_eza_linux() {
    # eza installation for Linux via official deb repository
    command -v eza &>/dev/null && return 2

    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Add gpg key
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | \
        sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg

    # Add repository
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | \
        sudo tee /etc/apt/sources.list.d/gierens.list

    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq
    sudo apt-get install -y -qq eza

    rm -rf "$tmp_dir"
}

install_uv() {
    # uv - Python package manager
    # https://docs.astral.sh/uv/
    command -v uv &>/dev/null && return 2
    curl -LsSf https://astral.sh/uv/install.sh | sh
}

is_external_supported() {
    local name=$1
    local supported_oses="${EXTERNAL_INSTALLERS[$name]:-}"

    if [[ -z "$supported_oses" ]]; then
        return 1
    fi

    if [[ "$supported_oses" == *"$OS_TYPE"* ]]; then
        return 0
    fi

    return 1
}

run_external_installer() {
    local name=$1

    log_to_file ""
    log_to_file "========================================"
    log_to_file "Running external installer: $name"
    log_to_file "========================================"

    # Check if function exists
    if [[ $(type -t "install_$name") != "function" ]]; then
        log_to_file "ERROR: install_$name function not found"
        return 1
    fi

    # Run installer with output capture to log
    {
        echo ""
        echo "========================================"
        echo "External installer: $name"
        echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
        local exit_code=0
        "install_$name" 2>&1 || exit_code=$?
        echo "========================================"
        echo "Exit code: $exit_code"
        echo "========================================"
        return $exit_code
    } >&$LOG_FD
}

# ============================================
# ⚡ PARALLEL PROCESSING
# ============================================

# Result tracking
declare -A INSTALL_RESULTS
declare -a INSTALL_FAILED
declare -a INSTALL_SKIPPED
declare -a INSTALL_SUCCESS

init_results() {
    INSTALL_FAILED=()
    INSTALL_SKIPPED=()
    INSTALL_SUCCESS=()
}

record_result() {
    local pkg=$1
    local status=$2

    case "$status" in
        success)
            INSTALL_SUCCESS+=("$pkg")
            ;;
        skipped)
            INSTALL_SKIPPED+=("$pkg")
            ;;
        failed)
            INSTALL_FAILED+=("$pkg")
            ;;
    esac
}

# Worker function for parallel execution
install_worker() {
    local pkg=$1
    local is_external=$2

    if [[ "$is_external" == "true" ]]; then
        # External installer - run in subshell to prevent set -e from triggering on exit code 2
        local exit_code=0
        (run_external_installer "${pkg#ext_}" > /dev/null 2>&1) || exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            echo "SUCCESS:$pkg"
        elif [[ $exit_code -eq 2 ]]; then
            echo "SKIPPED:$pkg"
        else
            echo "FAILED:$pkg"
        fi
    else
        # Regular package
        if is_installed "$pkg"; then
            echo "SKIPPED:$pkg"
            return 0
        fi

        if install_with_retry "$pkg" > /dev/null 2>&1; then
            echo "SUCCESS:$pkg"
        else
            echo "FAILED:$pkg"
        fi
    fi
}

# ============================================
# 📋 PACKAGE LIST BUILDING
# ============================================

build_package_list() {
    local -n list=$1

    # Add common packages
    list+=("${PACKAGES_COMMON[@]}")

    # Add OS-specific packages
    case "$OS_TYPE" in
        macos)
            list+=("${PACKAGES_MACOS[@]}")
            ;;
        linux)
            list+=("${PACKAGES_LINUX[@]}")
            ;;
    esac
}

build_external_list() {
    local -n list=$1

    for name in "${!EXTERNAL_INSTALLERS[@]}"; do
        if is_external_supported "$name"; then
            # Skip eza on macOS if already in brew packages
            if [[ "$name" == "eza_linux" && "$OS_TYPE" == "macos" ]]; then
                continue
            fi
            list+=("ext_$name")
        fi
    done
}

# ============================================
# 🚀 MAIN INSTALLATION FLOW
# ============================================

run_installation() {
    log_step "Building package list"

    # Build package lists
    local -a packages=()
    local -a externals=()
    build_package_list packages
    build_external_list externals

    local total_regular=${#packages[@]}
    local total_external=${#externals[@]}
    local total=$((total_regular + total_external))

    log_info "Found $total_regular regular packages"
    [[ $total_external -gt 0 ]] && log_info "Found $total_external external installers"

    if [[ $total -eq 0 ]]; then
        log_warn "No packages to install"
        return 0
    fi

    log_step "Installing packages (parallel: $PARALLEL_JOBS jobs)"

    init_progress "$total"
    init_results

    # Combine all items
    local -a all_items=("${packages[@]}" "${externals[@]}")
    local current=0

    # Process in parallel batches
    local -a pids=()
    local -a batch_items=()

    for item in "${all_items[@]}"; do
        batch_items+=("$item")

        # Launch batch when full
        if [[ ${#batch_items[@]} -ge $PARALLEL_JOBS ]]; then
            launch_batch batch_items pids
            batch_items=()
        fi
    done

    # Launch remaining items
    if [[ ${#batch_items[@]} -gt 0 ]]; then
        launch_batch batch_items pids
    fi

    # Wait for all and collect results
    wait_and_collect pids all_items

    finish_progress
}

launch_batch() {
    local -n items=$1
    local -n pid_list=$2

    for item in "${items[@]}"; do
        local is_external="false"
        [[ "$item" == ext_* ]] && is_external="true"

        install_worker "$item" "$is_external" &
        pid_list+=($!)
    done
}

wait_and_collect() {
    local -n pids=$1
    local -n items=$2
    local idx=0

    for pid in "${pids[@]}"; do
        local item="${items[$idx]}"
        local output

        if wait "$pid"; then
            output=$(cat /dev/null)  # Get output from background job
        fi

        CURRENT_PROGRESS=$((CURRENT_PROGRESS + 1))
        show_progress "$CURRENT_PROGRESS" "$TOTAL_PACKAGES" "$item"

        idx=$((idx + 1))
    done
}

# ============================================
# 📊 SEQUENTIAL INSTALLATION (Fallback)
# ============================================

run_installation_sequential() {
    log_step "Building package list"

    local -a packages=()
    local -a externals=()
    build_package_list packages
    build_external_list externals

    local total_regular=${#packages[@]}
    local total_external=${#externals[@]}
    local total=$((total_regular + total_external))

    log_info "Found $total_regular regular packages"
    [[ $total_external -gt 0 ]] && log_info "Found $total_external external installers"

    if [[ $total -eq 0 ]]; then
        log_warn "No packages to install"
        return 0
    fi

    log_step "Installing packages"

    init_progress "$total"
    init_results

    # Install regular packages
    for pkg in "${packages[@]}"; do
        show_progress "$CURRENT_PROGRESS" "$TOTAL_PACKAGES" "$pkg"

        log_to_file ""
        log_to_file "========================================"
        log_to_file "Package: $pkg"

        if is_installed "$pkg"; then
            log_to_file "Status: ALREADY INSTALLED (skipped)"
            record_result "$pkg" "skipped"
        else
            log_to_file "Status: INSTALLING..."
            if install_with_retry "$pkg" > /dev/null 2>&1; then
                log_to_file "Status: SUCCESS"
                record_result "$pkg" "success"
            else
                log_to_file "Status: FAILED"
                record_result "$pkg" "failed"
                log_error "Failed to install: $pkg"
            fi
        fi

        CURRENT_PROGRESS=$((CURRENT_PROGRESS + 1))
    done

    # Install external tools
    for ext in "${externals[@]}"; do
        local name="${ext#ext_}"
        show_progress "$CURRENT_PROGRESS" "$TOTAL_PACKAGES" "$name"

        # Run in subshell to prevent set -e from triggering on exit code 2
        local exit_code=0
        (run_external_installer "$name" > /dev/null 2>&1) || exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            record_result "$name" "success"
        elif [[ $exit_code -eq 2 ]]; then
            record_result "$name" "skipped"
        else
            record_result "$name" "failed"
            log_error "Failed to install: $name"
        fi

        CURRENT_PROGRESS=$((CURRENT_PROGRESS + 1))
    done

    finish_progress
}

# ============================================
# 📝 SUMMARY
# ============================================

print_summary() {
    local success_count=${#INSTALL_SUCCESS[@]}
    local skipped_count=${#INSTALL_SKIPPED[@]}
    local failed_count=${#INSTALL_FAILED[@]}

    echo
    printf "${COLOR_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}\n"
    printf "${COLOR_BOLD}           INSTALLATION SUMMARY${COLOR_RESET}\n"
    printf "${COLOR_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}\n"

    printf "  ${COLOR_GREEN}+${COLOR_RESET}  Successfully installed: ${COLOR_GREEN}%d${COLOR_RESET}\n" "$success_count"
    printf "  ${COLOR_YELLOW}o${COLOR_RESET}  Already installed:     ${COLOR_YELLOW}%d${COLOR_RESET}\n" "$skipped_count"

    if [[ $failed_count -gt 0 ]]; then
        printf "  ${COLOR_RED}x${COLOR_RESET}  Failed:                ${COLOR_RED}%d${COLOR_RESET}\n" "$failed_count"
        echo
        printf "${COLOR_RED}${COLOR_BOLD}Failed packages:${COLOR_RESET}\n"
        for pkg in "${INSTALL_FAILED[@]}"; do
            printf "  ${COLOR_RED}  - %s${COLOR_RESET}\n" "$pkg"
        done
    fi

    echo
    printf "${COLOR_DIM}Log file: %s${COLOR_RESET}\n" "$LOG_FILE"

    if [[ $failed_count -eq 0 ]]; then
        printf "\n${COLOR_GREEN}${COLOR_BOLD}All tools installed successfully!${COLOR_RESET}\n"
        return 0
    else
        printf "\n${COLOR_YELLOW}! Some packages failed to install.${COLOR_RESET}\n"
        return 1
    fi
}

# ============================================
# 🔧 SETUP FUNCTIONS
# ============================================

setup_homebrew() {
    if [[ "$OS_TYPE" != "macos" ]]; then
        return 0
    fi

    if command -v brew &>/dev/null; then
        log_success "Homebrew is already installed"
        return 0
    fi

    log_step "Installing Homebrew"

    log_to_file ""
    log_to_file "========================================"
    log_to_file "Installing Homebrew"
    log_to_file "========================================"

    {
        echo ""
        echo "========================================"
        echo "Homebrew Installer"
        echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "========================================"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1
        echo "========================================"
        echo "Exit code: $?"
        echo "========================================"
    } >&$LOG_FD

    if command -v brew &>/dev/null; then
        log_success "Homebrew installed successfully"

        # Add to PATH for current session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        log_error "Failed to install Homebrew"
        exit 1
    fi
}

setup_macos_cli_tools() {
    if [[ "$OS_TYPE" != "macos" ]]; then
        return 0
    fi

    if xcode-select -p &>/dev/null; then
        return 0
    fi

    log_step "Installing Command Line Tools"
    log_info "Please complete the installation dialog..."
    xcode-select --install

    log_warn "Please wait for Command Line Tools installation to complete, then run this script again"
    exit 0
}

# ============================================
# 🧹 CLEANUP
# ============================================

cleanup() {
    local exit_code=$?

    cleanup_sudo

    # Clean temp files
    rm -f /tmp/install-tools-*.tmp 2>/dev/null || true
    rm -f "$LOCK_FILE" 2>/dev/null || true

    echo "" >&$LOG_FD
    echo "=== Install Tools finished at $(date) with exit code $exit_code ===" >&$LOG_FD

    # Close log file descriptor
    exec {LOG_FD}>&- 2>/dev/null || true

    exit $exit_code
}

check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_error "Another instance is already running (PID: $pid)"
            exit 1
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# ============================================
# 🏁 MAIN
# ============================================

main() {
    # Set trap for cleanup
    trap cleanup EXIT INT TERM

    # Initialize
    readonly OS_TYPE=$(detect_os)
    readonly DISTRO=$(detect_distro)
    readonly PKG_MANAGER=$(detect_package_manager)

    init_logging
    check_lock

    # Header
    echo
    printf "${COLOR_CYAN}${COLOR_BOLD}>>  Install Tools${COLOR_RESET}\n"
    printf "${COLOR_DIM}    OS: %s | Package Manager: %s${COLOR_RESET}\n" "$OS_TYPE" "$PKG_MANAGER"
    printf "${COLOR_DIM}    Date: $(date '+%Y-%m-%d %H:%M:%S')${COLOR_RESET}\n"
    echo

    # OS-specific setup
    case "$OS_TYPE" in
        linux)
            log_info "Detected: Linux (${DISTRO})"
            request_sudo
            update_package_list
            ;;
        macos)
            log_info "Detected: macOS"
            setup_macos_cli_tools
            setup_homebrew
            update_package_list
            ;;
    esac

    # Run installation
    run_installation_sequential

    # Print summary
    print_summary
}

# Run main function
main "$@"
