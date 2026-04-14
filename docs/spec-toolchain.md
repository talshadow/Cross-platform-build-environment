# Специфікація: Toolchain файли

## Обов'язкові змінні

Кожен toolchain файл повинен встановити наведені нижче змінні **до** будь-якого
`project()` або `enable_language()`.

| Змінна | Крос-toolchain | Нативний toolchain | Опис |
|---|---|---|---|
| `CMAKE_SYSTEM_NAME` | **обов'язково** | **обов'язково** | `"Linux"` |
| `CMAKE_SYSTEM_PROCESSOR` | **обов'язково** | **обов'язково** | `aarch64`, `arm`, `x86_64`… |
| `CMAKE_C_COMPILER` | **обов'язково** | **обов'язково** | повний шлях або ім'я |
| `CMAKE_CXX_COMPILER` | **обов'язково** | **обов'язково** | повний шлях або ім'я |
| `CMAKE_C_FLAGS_INIT` | **обов'язково** | **обов'язково** | CPU-специфічні прапори |
| `CMAKE_CXX_FLAGS_INIT` | **обов'язково** | **обов'язково** | CPU-специфічні прапори |
| `CMAKE_AR` / `CMAKE_RANLIB` | обов'язково | обов'язково для LTO | для нативного: `gcc-ar-<ver>` / `gcc-ranlib-<ver>` |

> **Чому `CMAKE_SYSTEM_PROCESSOR` обов'язковий навіть для нативних toolchain:**
> Без явного значення деякий код (включно з `OpenSSL.cmake` і `CrossCompileHelpers.cmake`)
> отримає порожній рядок і некоректно визначить архітектуру. CMake не гарантує
> автоматичного заповнення цієї змінної коли `CMAKE_SYSTEM_NAME` задається вручну.

---

## Заборони

| Що заборонено | Причина |
|---|---|
| `set(CMAKE_C_FLAGS ...)` | перекриває прапори користувача; замість цього — `CMAKE_C_FLAGS_INIT` |
| `message(FATAL_ERROR ...)` без перевірки `CMAKE_CROSSCOMPILING` | toolchain завантажується двічі; перша спроба може падати на умовах що ще не виконані |
| `find_library()` без `NO_DEFAULT_PATH` у крос-toolchain | може знайти хост-бібліотеку замість target |
| `set(CMAKE_BUILD_TYPE ...)` | задається пресетом або користувачем, не toolchain |
| `project()` | toolchain не є проєктним файлом |

---

## CMAKE_C_FLAGS_INIT vs CMAKE_C_FLAGS

```
CMAKE_C_FLAGS_INIT   ←  задається toolchain (один раз, зберігається в CACHE INTERNAL)
        +
CMAKE_C_FLAGS        ←  задається користувачем через -DCMAKE_C_FLAGS=...
        =
реальні прапори компіляції
```

`CACHE INTERNAL ""` гарантує що значення не перезаписується при повторному
завантаженні toolchain під час `try_compile`.

---

## Режими пошуку — правила

### Крос-toolchain із sysroot

```cmake
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)   # програми — з хосту
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)    # .so/.a — тільки з sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)    # заголовки — тільки з sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)    # CMake пакети — тільки з sysroot
```

Виклик через `cross_toolchain_setup_sysroot()` з `common.cmake`.

### Крос-toolchain без sysroot

```cmake
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
```

Виклик через `cross_toolchain_no_sysroot()` з `common.cmake`.

### Нативний toolchain

Режими пошуку **не задавати** — CMake використовує власні за замовчуванням.

---

## Структура крос-toolchain файлу

```cmake
cmake_minimum_required(VERSION 3.20)

# 1. Ідентифікація цільової платформи
set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 2. Кеш-змінна префіксу (перевизначувана користувачем)
set(RPI4_TOOLCHAIN_PREFIX "aarch64-linux-gnu" CACHE STRING "...")
set(_TOOLCHAIN_PREFIX_VAR RPI4_TOOLCHAIN_PREFIX)  # для повідомлення про помилку

# 3. Спільні утиліти
include("${CMAKE_CURRENT_LIST_DIR}/common.cmake")

# 4. Пошук компілятора
cross_toolchain_find_compiler("${RPI4_TOOLCHAIN_PREFIX}" "gcc-aarch64-linux-gnu ...")

# 5. CPU-специфічні прапори
set(_CPU_FLAGS "-mcpu=cortex-a72+crc+simd")
set(CMAKE_C_FLAGS_INIT   "${_CPU_FLAGS}" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS_INIT "${_CPU_FLAGS}" CACHE INTERNAL "")

# 6. Sysroot (необов'язкова)
set(RPI_SYSROOT "" CACHE PATH "Шлях до sysroot")
if(RPI_SYSROOT)
    if(NOT IS_DIRECTORY "${RPI_SYSROOT}")
        message(FATAL_ERROR "[Toolchain] RPI_SYSROOT не існує: '${RPI_SYSROOT}'")
    endif()
    set(CMAKE_SYSROOT        "${RPI_SYSROOT}")
    set(CMAKE_FIND_ROOT_PATH "${RPI_SYSROOT}")
    cross_toolchain_setup_sysroot()
else()
    cross_toolchain_no_sysroot()
endif()
```

---

## Структура нативного toolchain файлу

```cmake
cmake_minimum_required(VERSION 3.20)

# Нативна збірка: CMAKE_SYSTEM_NAME та CMAKE_SYSTEM_PROCESSOR задаємо явно,
# щоб уникнути порожніх значень при вручному завантаженні toolchain.
set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Версія GCC (перевизначувана)
set(UBUNTU2404_GCC_VERSION "13" CACHE STRING "Версія GCC")

find_program(CMAKE_C_COMPILER   "gcc-${UBUNTU2404_GCC_VERSION}")
find_program(CMAKE_CXX_COMPILER "g++-${UBUNTU2404_GCC_VERSION}")

if(NOT CMAKE_C_COMPILER OR NOT CMAKE_CXX_COMPILER)
    message(FATAL_ERROR "[Toolchain] gcc-${UBUNTU2404_GCC_VERSION} не знайдено.")
endif()

set(CMAKE_C_COMPILER   "${CMAKE_C_COMPILER}"   CACHE FILEPATH "C compiler"   FORCE)
set(CMAKE_CXX_COMPILER "${CMAKE_CXX_COMPILER}" CACHE FILEPATH "C++ compiler" FORCE)

# gcc-ar / gcc-ranlib — обгортки з підтримкою LTO плагіну.
# Обов'язкові для коректної роботи ENABLE_LTO=ON.
find_program(_GCC_AR     "gcc-ar-${UBUNTU2404_GCC_VERSION}")
find_program(_GCC_RANLIB "gcc-ranlib-${UBUNTU2404_GCC_VERSION}")
find_program(_GCC_NM     "gcc-nm-${UBUNTU2404_GCC_VERSION}")
if(_GCC_AR)     set(CMAKE_AR     "${_GCC_AR}"     CACHE FILEPATH "" FORCE) endif()
if(_GCC_RANLIB) set(CMAKE_RANLIB "${_GCC_RANLIB}" CACHE FILEPATH "" FORCE) endif()
if(_GCC_NM)     set(CMAKE_NM     "${_GCC_NM}"     CACHE FILEPATH "" FORCE) endif()
unset(_GCC_AR) unset(_GCC_RANLIB) unset(_GCC_NM)

set(CMAKE_C_FLAGS_INIT   "-march=x86-64-v2 -mtune=generic" CACHE INTERNAL "")
set(CMAKE_CXX_FLAGS_INIT "-march=x86-64-v2 -mtune=generic" CACHE INTERNAL "")

# Нативна збірка: режими пошуку BOTH (хост = target)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
```

---

## common.cmake — API макросів

### cross_toolchain_find_compiler(PREFIX INSTALL)

Шукає `<PREFIX>-gcc` і `<PREFIX>-g++`. При невдачі — `FATAL_ERROR` з інструкцією
щодо встановлення пакету `INSTALL`.

Додатково шукає і встановлює (якщо знайдено):
- `CMAKE_AR` → `<PREFIX>-ar`
- `CMAKE_STRIP` → `<PREFIX>-strip`
- `CMAKE_RANLIB` → `<PREFIX>-ranlib`

Перед викликом треба встановити `_TOOLCHAIN_PREFIX_VAR` — ім'я кеш-змінної
що містить PREFIX (використовується у тексті помилки).

### cross_toolchain_setup_sysroot()

Встановлює:
- `CMAKE_FIND_ROOT_PATH_MODE_PROGRAM = NEVER`
- `CMAKE_FIND_ROOT_PATH_MODE_LIBRARY = ONLY`
- `CMAKE_FIND_ROOT_PATH_MODE_INCLUDE = ONLY`
- `CMAKE_FIND_ROOT_PATH_MODE_PACKAGE = ONLY`

### cross_toolchain_no_sysroot()

Встановлює всі `CMAKE_FIND_ROOT_PATH_MODE_*` в `BOTH`.

---

## Подвійне завантаження toolchain

CMake завантажує toolchain **двічі**:
1. Під час `try_compile` тестів компілятора.
2. Під час основної конфігурації проєкту.

**Наслідки:**
- Не використовувати `message(FATAL_ERROR)` в умовах що залежать від стану
  першого завантаження (наприклад, перевірка `CMAKE_SOURCE_DIR`).
- `CACHE INTERNAL ""` для `CMAKE_C_FLAGS_INIT` — значення зберігається при
  першому завантаженні і не перезаписується при другому.
- Не викликати `find_program()` поза `cross_toolchain_find_compiler()` — при
  повторному завантаженні може знайти інший результат.

Перевірка що це основна конфігурація (не try_compile):
```cmake
if(CMAKE_CROSSCOMPILING AND NOT CMAKE_TRY_COMPILE_TARGET_TYPE)
    # виконується тільки при основній конфігурації
endif()
```

---

## Змінні, які toolchain НЕ повинен задавати

| Змінна | Хто задає |
|---|---|
| `CMAKE_BUILD_TYPE` | пресет або користувач |
| `BUILD_TESTS` | пресет або корінь CMakeLists.txt |
| `ENABLE_ASAN/UBSAN/TSAN/LTO` | пресет або користувач |
| `CMAKE_INSTALL_PREFIX` | користувач або ExternalProject |
| `CMAKE_CXX_STANDARD` | CMakeLists.txt проєкту |
