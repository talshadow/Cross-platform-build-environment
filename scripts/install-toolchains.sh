#!/usr/bin/env bash
# scripts/install-toolchains.sh
#
# Встановлює всі необхідні крос-компілятори для збірки під цільові платформи.
# Підтримувані host-системи: Ubuntu 20.04, Ubuntu 24.04
#
# Використання:
#   chmod +x scripts/install-toolchains.sh
#   ./scripts/install-toolchains.sh [ВАРІАНТ...]
#
# Варіанти:
#   all       — встановити все (за замовчуванням)
#   rpi-arm32 — крос-компілятор для RPi 1/2 (arm-linux-gnueabihf)
#   rpi-arm64 — крос-компілятор для RPi 3/4/5 (aarch64-linux-gnu)
#   native20  — GCC 10 для Ubuntu 20.04
#   native24  — GCC 13/14 для Ubuntu 24.04
#   ninja     — збирач Ninja (потрібен для CMake presets)
#
# Yocto: toolchain встановлюється з SDK-інсталятора (./poky-*.sh),
#        цей скрипт Yocto SDK не встановлює.

set -euo pipefail

# --- Кольоровий вивід ------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Перевірка прав --------------------------------------------------------
require_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Потрібні права root. Запустіть через sudo або як root."
        exit 1
    fi
}

# --- Визначення Ubuntu версії ----------------------------------------------
detect_ubuntu_version() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Не вдалося визначити ОС (відсутній /etc/os-release)"
        exit 1
    fi
    # shellcheck source=/dev/null
    source /etc/os-release
    if [[ "${ID}" != "ubuntu" ]]; then
        log_warn "Виявлена ОС: ${PRETTY_NAME}. Скрипт розрахований на Ubuntu."
        log_warn "Продовжити? [y/N] "
        read -r answer
        [[ "${answer}" =~ ^[Yy]$ ]] || exit 0
    fi
    echo "${VERSION_ID}"
}

# --- Встановлення пакетів --------------------------------------------------
install_packages() {
    log_info "Оновлення apt..."
    apt-get update -qq
    log_info "Встановлення: $*"
    apt-get install -y --no-install-recommends "$@"
    log_ok "Встановлено: $*"
}

# --- Функції встановлення --------------------------------------------------
install_rpi_arm32() {
    log_info "=== Крос-компілятор RPi 1/2 (arm-linux-gnueabihf) ==="
    install_packages \
        gcc-arm-linux-gnueabihf \
        g++-arm-linux-gnueabihf \
        binutils-arm-linux-gnueabihf

    log_info "Перевірка:"
    arm-linux-gnueabihf-gcc --version | head -1

    log_warn "УВАГА (RPi 1/Zero): Ubuntu arm-linux-gnueabihf скомпільовано"
    log_warn "з ARMv7 baseline. Для ARMv6 бінарники можуть не запуститись."
    log_warn "Використовуйте офіційний RPi Foundation toolchain для ARMv6."
}

install_rpi_arm64() {
    log_info "=== Крос-компілятори RPi 4 (GCC 12) та RPi 5 (GCC 13) ==="
    install_packages \
        gcc-12-aarch64-linux-gnu \
        g++-12-aarch64-linux-gnu \
        gcc-13-aarch64-linux-gnu \
        g++-13-aarch64-linux-gnu \
        binutils-aarch64-linux-gnu

    log_info "Перевірка:"
    aarch64-linux-gnu-gcc-12 --version | head -1
    aarch64-linux-gnu-gcc-13 --version | head -1
}

install_native_gcc_ubuntu20() {
    log_info "=== GCC 10 для Ubuntu 20.04 ==="
    install_packages gcc-10 g++-10

    # Встановлюємо GCC 10 як альтернативу (не змінюємо default)
    update-alternatives --install /usr/bin/gcc-for-build gcc-for-build \
        "$(which gcc-10)" 10 || true
    log_info "Перевірка:"
    gcc-10 --version | head -1
}

install_native_gcc_ubuntu24() {
    log_info "=== GCC 13 та GCC 14 для Ubuntu 24.04 ==="
    install_packages gcc-13 g++-13

    # GCC 14 може бути в universe
    if apt-cache show gcc-14 &>/dev/null; then
        install_packages gcc-14 g++-14
    else
        log_warn "gcc-14 недоступний в поточних репозиторіях, пропущено."
    fi

    log_info "Перевірка:"
    gcc-13 --version | head -1
}

install_ninja() {
    log_info "=== Ninja build system ==="
    install_packages ninja-build
    log_info "Перевірка:"
    ninja --version
}

install_cmake() {
    log_info "=== CMake (перевірка версії) ==="
    if command -v cmake &>/dev/null; then
        local ver
        ver=$(cmake --version | head -1 | grep -oP '\d+\.\d+\.\d+')
        local major minor
        major=$(echo "$ver" | cut -d. -f1)
        minor=$(echo "$ver" | cut -d. -f2)
        if [[ $major -gt 3 ]] || { [[ $major -eq 3 ]] && [[ $minor -ge 20 ]]; }; then
            log_ok "CMake ${ver} (>= 3.20) вже встановлено"
            return
        fi
        log_warn "CMake ${ver} < 3.20. Потрібно оновити."
    fi

    log_info "Встановлення CMake через Kitware APT..."
    install_packages ca-certificates gpg wget
    wget -qO- "https://apt.kitware.com/keys/kitware-archive-latest.asc" \
        | gpg --dearmor - > /usr/share/keyrings/kitware-archive-keyring.gpg
    local codename
    codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME}")
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] \
https://apt.kitware.com/ubuntu/ ${codename} main" \
        > /etc/apt/sources.list.d/kitware.list
    apt-get update -qq
    install_packages cmake
    log_info "CMake: $(cmake --version | head -1)"
}

# --- Головна логіка --------------------------------------------------------
main() {
    require_sudo

    local ubuntu_ver
    ubuntu_ver=$(detect_ubuntu_version)
    log_info "Host система: Ubuntu ${ubuntu_ver}"

    local targets=("$@")
    if [[ ${#targets[@]} -eq 0 ]] || [[ "${targets[0]}" == "all" ]]; then
        targets=(rpi-arm32 rpi-arm64 ninja cmake)
        if [[ "${ubuntu_ver}" == "20.04" ]]; then
            targets+=(native20)
        elif [[ "${ubuntu_ver}" == "24.04" ]]; then
            targets+=(native24)
        fi
    fi

    for target in "${targets[@]}"; do
        case "${target}" in
            rpi-arm32) install_rpi_arm32  ;;
            rpi-arm64) install_rpi_arm64  ;;
            native20)  install_native_gcc_ubuntu20 ;;
            native24)  install_native_gcc_ubuntu24 ;;
            ninja)     install_ninja       ;;
            cmake)     install_cmake       ;;
            all)       : ;;  # вже оброблено вище
            *)
                log_error "Невідомий варіант: '${target}'"
                echo "Допустимі: all, rpi-arm32, rpi-arm64, native20, native24, ninja, cmake"
                exit 1
                ;;
        esac
    done

    echo ""
    log_ok "=== Встановлення завершено ==="
    echo ""
    echo "Доступні крос-компілятори:"
    for cc in arm-linux-gnueabihf-gcc aarch64-linux-gnu-gcc gcc-10 gcc-13 gcc-14; do
        if command -v "${cc}" &>/dev/null; then
            printf "  %-35s %s\n" "${cc}" "$(${cc} --version | head -1)"
        fi
    done
}

main "$@"
