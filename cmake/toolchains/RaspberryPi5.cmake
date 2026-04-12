# cmake/toolchains/RaspberryPi5.cmake
#
# Toolchain для Raspberry Pi 5
# SoC:  BCM2712
# CPU:  Cortex-A76 × 4 (ARMv8.2-A, 64-bit)
# OS:   Raspberry Pi OS 64-bit / Ubuntu Server 24.04 arm64
#
# Пакети Ubuntu: gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
# Рекомендовано GCC 12+ для повної підтримки ARMv8.2-A.
#
# Використання:
#   cmake -B build -S . \
#     -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/RaspberryPi5.cmake \
#     [-DRPI_SYSROOT=/path/to/sysroot]

cmake_minimum_required(VERSION 3.20)

set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(RPI5_TOOLCHAIN_PREFIX "aarch64-linux-gnu"
    CACHE STRING "Префікс крос-компілятора для Raspberry Pi 5")

set(_TOOLCHAIN_PREFIX_VAR RPI5_TOOLCHAIN_PREFIX)
include("${CMAKE_CURRENT_LIST_DIR}/common.cmake")
cross_toolchain_find_compiler(
    "${RPI5_TOOLCHAIN_PREFIX}"
    "gcc-aarch64-linux-gnu g++-aarch64-linux-gnu")

# --- CPU-специфічні прапори -----------------------------------------------
# -mcpu=cortex-a76  — Cortex-A76 (BCM2712), ARMv8.2-A
# +crc              — апаратний CRC32
# +simd             — Advanced SIMD
# +crypto           — апаратне шифрування (AES, SHA)
# +dotprod          — Dot Product (корисно для ML задач)
# -march=armv8.2-a  — мінімальна ISA (автоматично з cortex-a76,
#                      але явне задання покращує діагностику)
set(_RPI5_CPU_FLAGS "-mcpu=cortex-a76+crc+simd+crypto+dotprod")

set(CMAKE_C_FLAGS_INIT   "${_RPI5_CPU_FLAGS}" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS_INIT "${_RPI5_CPU_FLAGS}" CACHE INTERNAL "")

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
        "[RaspberryPi5] Збірка без sysroot. "
        "Для повної підтримки задайте -DRPI_SYSROOT=<path>")
    cross_toolchain_no_sysroot()
endif()
