# Опис toolchain файлів

## Спільна архітектура

Кожен toolchain файл підключає `cmake/toolchains/common.cmake`, який надає:

| Макрос | Призначення |
|---|---|
| `cross_toolchain_find_compiler(PREFIX INSTALL)` | Знаходить компілятор за префіксом, дає зрозуміле повідомлення при невдачі |
| `cross_toolchain_setup_sysroot()` | Встановлює `CMAKE_FIND_ROOT_PATH_MODE_*` для крос-збірки |
| `cross_toolchain_no_sysroot()` | Встановлює `BOTH` — пошук на host і в sysroot |

---

## Raspberry Pi 1 / Zero / Zero W — `RaspberryPi1.cmake`

| Параметр | Значення |
|---|---|
| SoC | BCM2835 |
| CPU | ARM1176JZF-S |
| ISA | ARMv6, VFPv2 |
| Компілятор | `arm-linux-gnueabihf-gcc` |
| CPU прапори | `-march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard` |
| Пресети | `rpi1-debug`, `rpi1-release` |

**Увага щодо ARMv6:** Ubuntu пакет `gcc-arm-linux-gnueabihf` скомпільований з
ARMv7 baseline. Бінарники для Pi 1/Zero краще збирати через:
- Офіційний [Raspberry Pi toolchain](https://github.com/raspberrypi/tools)
- crosstool-NG з `--target=arm-linux-gnueabihf --with-arch=armv6zk`

```cmake
# Власний prefix:
cmake --preset rpi1-release -DRPI1_TOOLCHAIN_PREFIX=/opt/rpi-tools/arm-linux-gnueabihf/bin/arm-linux-gnueabihf
```

---

> **Примітка:** RPi 4 та RPi 5 використовують `gcc-12-aarch64-linux-gnu` за замовчуванням.
> Змінити версію: `-DRPI4_GCC_VERSION=13`.

---

## Raspberry Pi 2 — `RaspberryPi2.cmake`

| Параметр | Значення |
|---|---|
| SoC | BCM2836 |
| CPU | Cortex-A7 × 4 |
| ISA | ARMv7-A, NEON, VFPv4 |
| Компілятор | `arm-linux-gnueabihf-gcc` |
| CPU прапори | `-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -mthumb` |
| Пресети | `rpi2-debug`, `rpi2-release` |

Пакет Ubuntu `gcc-arm-linux-gnueabihf` повністю підходить для ARMv7-A.

---

## Raspberry Pi 3 / Zero 2W — `RaspberryPi3.cmake`

| Параметр | Значення |
|---|---|
| SoC | BCM2837 / BCM2837B0 |
| CPU | Cortex-A53 × 4 |
| ISA | ARMv8-A, 64-bit |
| Компілятор | `aarch64-linux-gnu-gcc` |
| CPU прапори | `-mcpu=cortex-a53` |
| Пресети | `rpi3-debug`, `rpi3-release` |

Для 32-bit OS на Pi 3 використовуйте `RaspberryPi2.cmake` із `-mcpu=cortex-a53`.

---

## Raspberry Pi 4 / 400 / CM4 — `RaspberryPi4.cmake`

| Параметр | Значення |
|---|---|
| SoC | BCM2711 |
| CPU | Cortex-A72 × 4 |
| ISA | ARMv8-A, 64-bit |
| Компілятор | `aarch64-linux-gnu-gcc-12` (за замовч.), fallback на `aarch64-linux-gnu-gcc` |
| CPU прапори | `-mcpu=cortex-a72+crc+simd` |
| Пресети | `rpi4-debug`, `rpi4-release`, `rpi4-relwithdebinfo` |

---

## Raspberry Pi 5 — `RaspberryPi5.cmake`

| Параметр | Значення |
|---|---|
| SoC | BCM2712 |
| CPU | Cortex-A76 × 4 |
| ISA | ARMv8.2-A, 64-bit |
| Компілятор | `aarch64-linux-gnu-gcc-13` (за замовч.), fallback на `aarch64-linux-gnu-gcc` |
| CPU прапори | `-mcpu=cortex-a76+crc+simd+crypto+dotprod` |
| Пресети | `rpi5-debug`, `rpi5-release`, `rpi5-relwithdebinfo` |

---

## Yocto Linux — `Yocto.cmake`

Архітектура нейтральний toolchain — визначає компілятор та sysroot зі змінних
середовища, які встановлює `environment-setup-*` скрипт Yocto SDK.

| Змінна середовища | Звідки | Використання |
|---|---|---|
| `CC` | SDK | `CMAKE_C_COMPILER` + початкові прапори |
| `CXX` | SDK | `CMAKE_CXX_COMPILER` + початкові прапори |
| `AR`, `STRIP`, `LD`, ... | SDK | відповідні CMake змінні |
| `SDKTARGETSYSROOT` | SDK | `CMAKE_SYSROOT` |
| `OECORE_TARGET_ARCH` | SDK | `CMAKE_SYSTEM_PROCESSOR` |
| `OECORE_NATIVE_SYSROOT` | SDK | пошук `pkg-config` |

**Порядок використання:**

```bash
# 1. Активувати SDK (обов'язково перед cmake)
source /opt/poky/5.0/environment-setup-cortexa72-poky-linux

# 2. Перевірити
./scripts/get-sysroot-yocto.sh --method check

# 3. Зібрати
cmake --preset yocto-release
cmake --build --preset yocto-release
```

Якщо `SDKTARGETSYSROOT` не влаштовує — можна перевизначити:
```bash
cmake --preset yocto-release -DYOCTO_SDK_SYSROOT=/custom/sysroot
```

---

## Ubuntu 20.04 — `Ubuntu2004.cmake`

| Параметр | Значення |
|---|---|
| Архітектура | x86_64 (нативна) |
| GCC версія | 10 (за замовчуванням), 9 |
| CPU прапори | `-march=x86-64 -mtune=generic` |
| Пресети | `ubuntu2004-debug`, `ubuntu2004-release` |

```bash
# Змінити версію GCC:
cmake --preset ubuntu2004-debug -DUBUNTU2004_GCC_VERSION=9
```

---

## Ubuntu 24.04 — `Ubuntu2404.cmake`

| Параметр | Значення |
|---|---|
| Архітектура | x86_64 (нативна) |
| GCC версія | 13 (за замовчуванням), 14 |
| CPU прапори | `-march=x86-64-v2 -mtune=generic` |
| Пресети | `ubuntu2404-debug`, `ubuntu2404-release`, `ubuntu2404-asan` |

`x86-64-v2` вимагає: SSE4.2, POPCNT (підтримується CPU після ~2009 р.).
Для максимальної сумісності — змініть на `-march=x86-64`.

---

## CMake змінні, спільні для всіх RPi toolchain файлів

| Змінна | Призначення |
|---|---|
| `RPI_SYSROOT` | Шлях до sysroot (порожньо = без sysroot) |
| `RPI<N>_TOOLCHAIN_PREFIX` | Префікс компілятора для RPi N (напр. `RPI4_TOOLCHAIN_PREFIX`) |

Ці змінні — `CACHE` змінні, їх можна задати у `CMakePresets.json` або через `-D`.
