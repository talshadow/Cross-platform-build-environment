# Архітектура проєкту

## Призначення

Інфраструктурний CMake проєкт: надає готові toolchain файли, CMake модулі та
допоміжні скрипти для крос-компіляції C/C++ проєктів під Raspberry Pi і
Yocto Linux з host-систем Ubuntu 20.04 / 24.04.

Проєкт не є застосунком — це шаблон і набір інструментів, який підключається
до вашого основного `CMakeLists.txt`.

---

## Структура файлів

```
SupportRaspberryPI/
│
├── CMakeLists.txt              # Кореневий файл (шаблонний проєкт)
├── CMakePresets.json           # Пресети для всіх платформ
│
├── cmake/
│   ├── toolchains/
│   │   ├── common.cmake        # Спільні макроси (підключається через include())
│   │   ├── RaspberryPi1.cmake  # ARMv6 (Pi 1, Zero, Zero W)
│   │   ├── RaspberryPi2.cmake  # ARMv7-A (Pi 2)
│   │   ├── RaspberryPi3.cmake  # AArch64 Cortex-A53 (Pi 3, Zero 2W)
│   │   ├── RaspberryPi4.cmake  # AArch64 Cortex-A72 (Pi 4, 400, CM4)
│   │   ├── RaspberryPi5.cmake  # AArch64 Cortex-A76 (Pi 5)
│   │   ├── Yocto.cmake         # Yocto SDK (будь-яка архітектура)
│   │   ├── Ubuntu2004.cmake    # x86_64, GCC 9/10
│   │   └── Ubuntu2404.cmake    # x86_64, GCC 13/14
│   │
│   └── modules/
│       ├── CompilerWarnings.cmake    # target_enable_warnings()
│       ├── Sanitizers.cmake          # target_enable_sanitizers()
│       └── CrossCompileHelpers.cmake # cross_check_cxx_flag(), cross_feature_check()
│
├── scripts/
│   ├── install-toolchains.sh   # Встановити крос-компілятори (apt)
│   ├── get-sysroot-rpi.sh      # Отримати sysroot для RPi (Docker/образ/SSH)
│   ├── get-sysroot-yocto.sh    # Встановити/витягнути Yocto SDK sysroot
│   ├── sync-sysroot.sh         # Синхронізувати sysroot з живого RPi
│   ├── build.sh                # Обгортка над cmake --preset
│   └── deploy.sh               # Розгортання по SSH
│
├── src/                        # Вихідний код проєкту
├── tests/                      # Тести (GTest, ctest)
│
└── docs/
    ├── overview.md             # Цей файл
    ├── toolchains.md           # Детальний опис toolchain файлів
    └── getting-started.md      # Покрокова інструкція
```

---

## Потік крос-компіляції

```
Host (Ubuntu)
│
├─ [1] install-toolchains.sh
│      apt install gcc-aarch64-linux-gnu ...
│
├─ [2] get-sysroot-rpi.sh / get-sysroot-yocto.sh
│      → /srv/rpi4-sysroot/
│           ├── lib/
│           ├── usr/include/
│           └── usr/lib/
│
├─ [3] cmake --preset rpi4-release
│      │  -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/RaspberryPi4.cmake
│      │  -DRPI_SYSROOT=/srv/rpi4-sysroot
│      │
│      └─ CMake читає toolchain:
│            CMAKE_C_COMPILER   = aarch64-linux-gnu-gcc
│            CMAKE_SYSROOT      = /srv/rpi4-sysroot
│            CMAKE_C_FLAGS_INIT = -mcpu=cortex-a72+crc+simd
│
├─ [4] cmake --build --preset rpi4-release
│      → build/rpi4-release/bin/<ваш_бінарник>  (ELF AArch64)
│
└─ [5] deploy.sh --preset rpi4-release --host 192.168.1.100
       rsync → RPi → запуск
```

---

## Принцип роботи toolchain файлів

### Що відбувається коли CMake зчитує toolchain

1. Toolchain завантажується **двічі**: під час `try_compile` тестів і при
   основній конфігурації. Тому toolchain не повинен мати побічних ефектів.

2. `CMAKE_C_FLAGS_INIT` / `CMAKE_CXX_FLAGS_INIT` — задаються **один раз**
   з toolchain і стають базою для `CMAKE_C_FLAGS`. Якщо toolchain файл
   завантажується знову — значення в кеші вже є, `CACHE INTERNAL ""` гарантує
   що вони не перезаписуються.

3. `CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER` забезпечує що при `find_program()`
   CMake знаходить програми хост-системи (cmake, python, тощо), а не
   цільової.

4. `CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY` забезпечує що `.so`/`.a`
   знаходяться тільки в sysroot, не на хості.

### Чому `CMAKE_C_FLAGS_INIT`, а не `CMAKE_C_FLAGS`

`CMAKE_C_FLAGS` — кешована змінна користувача. Перезапис з toolchain
перекриє все що користувач задав через `-DCMAKE_C_FLAGS=...`. `*_INIT`
змінні задають **початкові** значення і об'єднуються з `CMAKE_C_FLAGS`.

### Sysroot та симлінки

Після синхронізації sysroot деякі `.so` файли мають абсолютні симлінки:
```
/srv/rpi4-sysroot/usr/lib/aarch64-linux-gnu/libssl.so -> /lib/aarch64-linux-gnu/libssl.so.3
```
Посилання `/lib/...` — абсолютне відносно **хост-системи**, а не sysroot.
Лінкер крос-компілятора його не знайде.

Скрипти `sync-sysroot.sh` та `get-sysroot-rpi.sh` автоматично перетворюють
такі посилання на відносні через `fixup_symlinks()`.

---

## CMakePresets.json — структура пресетів

```
base (hidden)
│   generator: Ninja
│   binaryDir: build/${presetName}
│   CMAKE_EXPORT_COMPILE_COMMANDS: ON
│
├── base-cross (hidden)
│   inherits: base
│   BUILD_TESTS: OFF
│
├── ubuntu2404-debug
│   toolchainFile: Ubuntu2404.cmake
│   CMAKE_BUILD_TYPE: Debug
│
├── ubuntu2404-asan
│   inherits: ubuntu2404-debug
│   ENABLE_ASAN: ON, ENABLE_UBSAN: ON
│
├── rpi4-debug / rpi4-release
│   inherits: base-cross
│   toolchainFile: RaspberryPi4.cmake
│
└── yocto-debug / yocto-release
    inherits: base-cross
    toolchainFile: Yocto.cmake
```

`jobs: 0` у `buildPresets` означає "використовувати всі доступні ядра".

---

## CMake модулі

### CompilerWarnings.cmake

```cmake
include(CompilerWarnings)
target_enable_warnings(my_target)           # Wall, Wextra, Wshadow, ...
target_enable_warnings(my_target STRICT)    # + Wlogical-op, Wuseless-cast, ...
target_enable_warnings(my_target PEDANTIC)  # STRICT + Wpedantic
```

Автоматично підбирає прапори для GCC, Clang або MSVC.

### Sanitizers.cmake

```cmake
include(Sanitizers)
target_enable_sanitizers(my_target ASAN UBSAN)
target_enable_sanitizers(my_target TSAN)     # TSAN несумісний з ASAN
```

При крос-компіляції — попереджає, але не блокує.
Глобальне вимкнення: `-DSANITIZERS_ENABLED=OFF`.

### CrossCompileHelpers.cmake

```cmake
include(CrossCompileHelpers)

# Додати прапор якщо компілятор підтримує
cross_check_cxx_flag(TARGET my_target FLAG -march=armv8.2-a)
cross_check_cxx_flag(TARGET my_target FLAG -fsomething REQUIRED)

# Перевірка фічі через try_compile (безпечно при крос-компіляції)
cross_feature_check(
    FEATURE CXX_HAS_INT128
    CODE "int main() { __int128 x = 0; (void)x; return 0; }"
)
if(HAVE_CXX_HAS_INT128)
    target_compile_definitions(my_target PRIVATE HAS_INT128=1)
endif()

# Діагностика конфігурації
cross_get_target_info()
```

---

## Підключення до власного CMakeLists.txt

```cmake
# Додайте cmake/modules до шляху пошуку:
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")

include(CompilerWarnings)
include(Sanitizers)
include(CrossCompileHelpers)

add_executable(my_app src/main.cpp)
target_enable_warnings(my_app STRICT)

if(ENABLE_ASAN)
    target_enable_sanitizers(my_app ASAN UBSAN)
endif()
```

Або вкажіть toolchain при конфігурації:
```bash
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=<шлях>/cmake/toolchains/RaspberryPi4.cmake \
    -DCMAKE_MODULE_PATH=<шлях>/cmake/modules
```
