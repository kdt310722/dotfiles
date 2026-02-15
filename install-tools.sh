#!/usr/bin/env bash

set -euo pipefail

# ============================================
# 🛠️ PACKAGE DEFINITIONS
# ============================================
declare -A PACKAGES_DEBIAN=(
    ["network"]="curl wget net-tools iputils-ping traceroute dnsutils openssl"
    ["text"]="nano vim grep sed gawk jq"
    ["compression"]="zip unzip gzip bzip2"
    ["system"]="zsh htop git tree gpg bat fzf ripgrep fd-find libnotify-bin"
    ["build"]="build-essential python3 python3-pip"
)

declare -A PACKAGES_MACOS=(
    ["network"]="curl wget openssl"
    ["text"]="nano vim grep gnu-sed jq"
    ["compression"]="zip unzip gzip"
    ["system"]="zsh htop git tree gpg eza bat fzf ripgrep fd terminal-notifier"
    ["build"]="python3"
)

# ============================================
# 🎨 COLOR & ICON DEFINITIONS
# ============================================
readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_DIM='\033[2m'
readonly COLOR_BOLD='\033[1m'

readonly ICON_CHECK='✅'
readonly ICON_CROSS='❌'
readonly ICON_INFO='ℹ️'
readonly ICON_HOURGLASS='⏳'
readonly ICON_ROCKET='🚀'
readonly ICON_PACKAGE='📦'
readonly ICON_GEAR='⚙️'
readonly ICON_DONE='🎉'
readonly ICON_WARN='⚠️'
readonly ICON_LOCK='🔒'

# ============================================
# 📝 LOG FUNCTIONS
# ============================================
log_info() {
    printf "${COLOR_BLUE}${ICON_INFO}${COLOR_RESET} %s\n" "$1"
}

log_success() {
    printf "${COLOR_GREEN}${ICON_CHECK}${COLOR_RESET} %s\n" "$1"
}

log_error() {
    printf "${COLOR_RED}${ICON_CROSS}${COLOR_RESET} %s\n" "$1" >&2
}

log_warn() {
    printf "${COLOR_YELLOW}${ICON_WARN}${COLOR_RESET} %s\n" "$1"
}

log_step() {
    printf "\n${COLOR_CYAN}${ICON_HOURGLASS}${COLOR_RESET} ${COLOR_BOLD}%s${COLOR_RESET}\n" "$1"
}

log_dim() {
    printf "${COLOR_DIM}%s${COLOR_RESET}\n" "$1"
}

# ============================================
# 🔒 ROOT CHECK
# ============================================
check_root() {
    if [[ "$OS_TYPE" == "debian" ]] && [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges on Linux"
        log_info "Please run with: sudo $0"
        exit 1
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
            if [[ -f /etc/os-release ]]; then
                # shellcheck source=/dev/null
                source /etc/os-release
                if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
                    echo "debian"
                else
                    log_error "Only Ubuntu/Debian-based Linux distributions are supported"
                    exit 1
                fi
            else
                log_error "Unable to detect Linux distribution"
                exit 1
            fi
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

# ============================================
# 📦 PACKAGE MANAGER WRAPPERS
# ============================================
readonly OS_TYPE=$(detect_os)

update_package_list() {
    log_info "Updating package list..."
    case "$OS_TYPE" in
        debian)
            apt-get update -qq
            ;;
        macos)
            if command -v brew &>/dev/null; then
                brew update --quiet
            else
                log_warn "Homebrew is not installed"
            fi
            ;;
    esac
    log_success "Package list updated"
}

install_packages() {
    local packages=("$@")
    local pkg

    for pkg in "${packages[@]}"; do
        printf "  ${ICON_PACKAGE} Installing: ${COLOR_CYAN}%s${COLOR_RESET}... " "$pkg"

        case "$OS_TYPE" in
            debian)
                if dpkg -l "$pkg" &>/dev/null 2>&1; then
                    printf "${COLOR_DIM}already installed${COLOR_RESET}\n"
                else
                    if apt-get install -y -qq "$pkg" &>/dev/null; then
                        printf "${COLOR_GREEN}done${COLOR_RESET}\n"
                    else
                        printf "${COLOR_RED}failed${COLOR_RESET}\n"
                        log_error "Failed to install: $pkg"
                    fi
                fi
                ;;
            macos)
                if brew list "$pkg" &>/dev/null 2>&1; then
                    printf "${COLOR_DIM}already installed${COLOR_RESET}\n"
                else
                    if brew install "$pkg" 2>/dev/null; then
                        printf "${COLOR_GREEN}done${COLOR_RESET}\n"
                    else
                        printf "${COLOR_RED}failed${COLOR_RESET}\n"
                        log_warn "Failed to install: $pkg (may not be available on Homebrew)"
                    fi
                fi
                ;;
        esac
    done
}

# ============================================
# 🎯 INSTALLATION FUNCTIONS
# ============================================
install_homebrew() {
    if ! command -v brew &>/dev/null; then
        log_step "Installing Homebrew ${ICON_ROCKET}"
        log_info "Downloading Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew installed successfully"
    else
        log_success "Homebrew is already installed"
    fi
}

install_brew_formula() {
    local formulas=("$@")
    log_info "Installing Homebrew formulas..."
    for formula in "${formulas[@]}"; do
        printf "  ${ICON_PACKAGE} Installing: ${COLOR_CYAN}%s${COLOR_RESET}... " "$formula"
        if brew list "$formula" &>/dev/null 2>&1; then
            printf "${COLOR_DIM}already installed${COLOR_RESET}\n"
        else
            if brew install "$formula" 2>/dev/null; then
                printf "${COLOR_GREEN}done${COLOR_RESET}\n"
            else
                printf "${COLOR_RED}failed${COLOR_RESET}\n"
            fi
        fi
    done
}

install_category() {
    local category=$1
    local -n pkg_map

    case "$OS_TYPE" in
        debian)
            pkg_map=PACKAGES_DEBIAN
            ;;
        macos)
            pkg_map=PACKAGES_MACOS
            ;;
    esac

    local packages="${pkg_map[$category]}"

    if [[ -n "$packages" ]]; then
        log_step "Installing $category tools ${ICON_GEAR}"
        install_packages $packages
    fi
}

# ============================================
# 🔧 MACOS-SPECIFIC SETUP
# ============================================
setup_macos_cli_tools() {
    log_step "Checking Command Line Tools ${ICON_GEAR}"
    if ! xcode-select -p &>/dev/null; then
        log_info "Installing Command Line Tools..."
        xcode-select --install
        log_warn "Please complete the Command Line Tools installation, then run this script again"
        exit 0
    else
        log_success "Command Line Tools are installed"
    fi
}

# ============================================
# � ZSH SHELL CONFIGURATION
# ============================================
setup_zsh_default_shell() {
    log_step "Setting zsh as default shell ${ICON_GEAR}"

    if ! command -v zsh &>/dev/null; then
        log_error "zsh is not installed"
        return 1
    fi

    local zsh_path
    zsh_path=$(command -v zsh)
    log_info "Found zsh at: ${COLOR_CYAN}$zsh_path${COLOR_RESET}"

    local current_shell
    current_shell=$(dscl . -read ~/ UserShell 2>/dev/null | awk '{print $2}' || echo "$SHELL")

    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_success "zsh is already the default shell"
        return 0
    fi

    case "$OS_TYPE" in
        debian)
            printf "  ${ICON_PACKAGE} Changing default shell to zsh... "
            if echo "$zsh_path" | sudo tee /etc/shells &>/dev/null && sudo chsh -s "$zsh_path" "$USER" &>/dev/null; then
                printf "${COLOR_GREEN}done${COLOR_RESET}\n"
                log_success "Default shell changed to zsh for user: $USER"
                log_warn "Please log out and log back in for changes to take effect"
            else
                printf "${COLOR_RED}failed${COLOR_RESET}\n"
                log_error "Failed to change default shell to zsh"
                return 1
            fi
            ;;
        macos)
            log_success "zsh is already the default shell on macOS"
            ;;
    esac
}

# ============================================
# �📊 SUMMARY
# ============================================
print_summary() {
    printf "\n${COLOR_GREEN}${ICON_DONE}${COLOR_RESET} ${COLOR_BOLD}COMPLETED!${COLOR_RESET}\n"
    printf "${COLOR_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}\n"
    log_success "All core tools have been installed"
    printf "\n${ICON_INFO} Verify by running:\n"
    printf "   • curl --version\n"
    printf "   • git --version\n"
    printf "   • jq --version\n"
    printf "   • htop --version\n"
    printf "\n${COLOR_DIM}Happy coding! 🥑${COLOR_RESET}\n"
}

# ============================================
# 🛠️ UTILITY TOOL DEFINITION
# ============================================
install_utility_tools() {
    if [[ "$OS_TYPE" == "debian" ]] && ! command -v eza &>/dev/null; then
        printf "  ${ICON_PACKAGE} Installing: ${COLOR_CYAN}eza${COLOR_RESET}... "
        mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list
        chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        apt update -y
        apt install -y eza
    fi

    if ! command -v zoxide &>/dev/null; then
        printf "  ${ICON_PACKAGE} Installing: ${COLOR_CYAN}zoxide${COLOR_RESET}... "
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi
}

# ============================================
# 🚀 MAIN EXECUTION
# ============================================
main() {
    # Check root privileges for Linux
    check_root

    # Header
    printf "\n${COLOR_CYAN}${ICON_ROCKET}${COLOR_RESET} ${COLOR_BOLD}Setup Core Tools${COLOR_RESET}\n"
    printf "${COLOR_DIM}OS: %s | Date: $(date '+%Y-%m-%d %H:%M:%S')${COLOR_RESET}\n\n"

    # OS-specific setup
    case "$OS_TYPE" in
        debian)
            log_info "Detected: Ubuntu/Debian 🐧"
            update_package_list
            ;;
        macos)
            log_info "Detected: macOS 🍎"
            setup_macos_cli_tools
            install_homebrew
            update_package_list
            ;;
    esac

    # Install packages by category
    install_category "network"
    install_category "text"
    install_category "compression"
    install_category "system"
    install_category "build"
    install_utility_tools

    # Setup zsh as default shell
    setup_zsh_default_shell

    # Summary
    print_summary
}

# ============================================
# 🏁 ENTRY POINT
# ============================================
main "$@"
