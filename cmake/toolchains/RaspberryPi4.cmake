# cmake/toolchains/RaspberryPi4.cmake
#
# Toolchain для Raspberry Pi 4 Model B / 400 / CM4
# SoC:  BCM2711
# CPU:  Cortex-A72 × 4 (ARMv8-A, 64-bit)
# OS:   Raspberry Pi OS 64-bit / Ubuntu Server 22.04/24.04 arm64
#
# Пакети Ubuntu: gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
#
# Використання:
#   cmake -B build -S . \
#     -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/RaspberryPi4.cmake \
#     [-DRPI_SYSROOT=/path/to/sysroot]

cmake_minimum_required(VERSION 3.28)

set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(RPI4_TOOLCHAIN_PREFIX "aarch64-linux-gnu"
    CACHE STRING "Префікс крос-компілятора для Raspberry Pi 4")

set(RPI4_GCC_VERSION "12"
    CACHE STRING "Версія GCC для крос-компіляції RPi 4 (12, 13, ...)")

set(_TOOLCHAIN_PREFIX_VAR RPI4_TOOLCHAIN_PREFIX)
include("${CMAKE_CURRENT_LIST_DIR}/common.cmake")

# Шукаємо версований компілятор (aarch64-linux-gnu-gcc-12),
# якщо не знайдено — fallback на неверсований (aarch64-linux-gnu-gcc)
find_program(_RPI4_CC_VERSIONED
    "${RPI4_TOOLCHAIN_PREFIX}-gcc-${RPI4_GCC_VERSION}"
    HINTS ENV PATH)

if(_RPI4_CC_VERSIONED)
    find_program(_RPI4_CXX_VERSIONED
        "${RPI4_TOOLCHAIN_PREFIX}-g++-${RPI4_GCC_VERSION}"
        HINTS ENV PATH)
    set(CMAKE_C_COMPILER   "${_RPI4_CC_VERSIONED}"  CACHE FILEPATH "C compiler"   FORCE)
    set(CMAKE_CXX_COMPILER "${_RPI4_CXX_VERSIONED}" CACHE FILEPATH "C++ compiler" FORCE)
    unset(_RPI4_CXX_VERSIONED)
    find_program(_AR    "${RPI4_TOOLCHAIN_PREFIX}-ar")
    find_program(_STRIP "${RPI4_TOOLCHAIN_PREFIX}-strip")
    find_program(_RANLIB "${RPI4_TOOLCHAIN_PREFIX}-ranlib")
    if(_AR)
        set(CMAKE_AR     "${_AR}"     CACHE FILEPATH "Archiver" FORCE)
    endif()
    if(_STRIP)
        set(CMAKE_STRIP  "${_STRIP}"  CACHE FILEPATH "Strip"    FORCE)
    endif()
    if(_RANLIB)
        set(CMAKE_RANLIB "${_RANLIB}" CACHE FILEPATH "Ranlib"   FORCE)
    endif()
    unset(_AR)
    unset(_STRIP)
    unset(_RANLIB)
else()
    message(WARNING
        "[RaspberryPi4] gcc-${RPI4_GCC_VERSION} не знайдено, "
        "використовується неверсований aarch64-linux-gnu-gcc. "
        "Встановіть: sudo apt install gcc-${RPI4_GCC_VERSION}-aarch64-linux-gnu")
    cross_toolchain_find_compiler(
        "${RPI4_TOOLCHAIN_PREFIX}"
        "gcc-${RPI4_GCC_VERSION}-aarch64-linux-gnu g++-${RPI4_GCC_VERSION}-aarch64-linux-gnu")
endif()
unset(_RPI4_CC_VERSIONED)

# --- CPU-специфічні прапори -----------------------------------------------
# -mcpu=cortex-a72  — Cortex-A72 (BCM2711), ARMv8-A + CRC + Crypto
# +crc              — апаратний CRC32 (вже включено в cortex-a72)
# +simd             — Advanced SIMD (NEON для AArch64)
set(_RPI4_CPU_FLAGS "-mcpu=cortex-a72+crc+simd")

set(CMAKE_C_FLAGS_INIT   "${_RPI4_CPU_FLAGS}" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS_INIT "${_RPI4_CPU_FLAGS}" CACHE INTERNAL "")

# --- Sysroot ---------------------------------------------------------------
set(RPI_SYSROOT "" CACHE PATH
    "Шлях до sysroot Raspberry Pi (порожньо = збірка без sysroot)")

if(RPI_SYSROOT)
    if(NOT IS_DIRECTORY "${RPI_SYSROOT}")
        message(FATAL_ERROR
            "[Toolchain] RPI_SYSROOT не існує: '${RPI_SYSROOT}'")
    endif()
    set(CMAKE_SYSROOT        "${RPI_SYSROOT}")
    set(CMAKE_FIND_ROOT_PATH "${RPI_SYSROOT}")
    cross_toolchain_setup_sysroot()
else()
    message(STATUS
        "[RaspberryPi4] Збірка без sysroot. "
        "Для повної підтримки задайте -DRPI_SYSROOT=<path>")
    cross_toolchain_no_sysroot()
endif()
