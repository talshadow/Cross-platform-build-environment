# Специфікація: CMake модулі API

Всі модулі знаходяться у `cmake/modules/`.  
Підключення: `list(APPEND CMAKE_MODULE_PATH "<path>/cmake/modules")` + `include(<Module>)`.

---

## CompilerWarnings.cmake

### target_enable_warnings

```cmake
target_enable_warnings(<target> [NORMAL | STRICT | PEDANTIC])
```

Додає набір попереджень компілятора до `<target>` через `target_compile_options(PRIVATE ...)`.

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `target` | ім'я CMake цілі | так | ціль до якої застосовуються попередження |
| рівень | keyword | ні | `NORMAL` (за замовч.), `STRICT`, `PEDANTIC` |

#### Рівні попереджень

**NORMAL** (за замовчуванням) — базовий набір для GCC/Clang:
```
-Wall -Wextra -Wshadow -Wnon-virtual-dtor -Wcast-align
-Wunused -Woverloaded-virtual -Wconversion -Wsign-conversion
-Wdouble-promotion -Wformat=2 -Wimplicit-fallthrough
-Wnull-dereference
```

**STRICT** — NORMAL плюс:
```
-Wmisleading-indentation -Wduplicated-cond -Wduplicated-branches
-Wlogical-op -Wuseless-cast
```

**PEDANTIC** — STRICT плюс:
```
-Wpedantic
```

#### Поведінка за компілятором

| Компілятор | Набір |
|---|---|
| GCC | `_COMMON_WARNINGS` (відповідно до рівня) |
| Clang | `_COMMON_WARNINGS` + `-Wno-gnu-zero-variadic-macro-arguments` |
| MSVC | `/W4` + набір `/w14*` та `/we4*` (незалежно від рівня) |

#### Помилки та обмеження

- Не перевіряє чи підтримує компілятор кожен прапор — `GCC`/`Clang`-специфічні прапори (наприклад `-Wlogical-op`) ігноруються якщо компілятор їх не підтримує (GCC просто попередить).
- Прапори STRICT (`-Wlogical-op`, `-Wuseless-cast`) є **GCC-специфічними** і не підтримуються Clang — Clang їх проігнорує зі своїм попередженням.

#### Приклади

```cmake
include(CompilerWarnings)

target_enable_warnings(my_lib)            # NORMAL
target_enable_warnings(my_app STRICT)     # STRICT
target_enable_warnings(my_test PEDANTIC)  # PEDANTIC
```

---

## Sanitizers.cmake

### Глобальна опція

```cmake
option(SANITIZERS_ENABLED "Дозволити санітайзери" ON)
```

`-DSANITIZERS_ENABLED=OFF` вимикає всі санітайзери глобально. Викликати
`target_enable_sanitizers()` стає no-op.

---

### target_enable_sanitizers

```cmake
target_enable_sanitizers(<target> [ASAN] [UBSAN] [TSAN] [LSAN])
```

Додає прапори санітайзерів до `<target>` через
`target_compile_options(PRIVATE ...)` та `target_link_options(PRIVATE ...)`.
Також додає `-g` для читабельних stack traces.

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `target` | ім'я CMake цілі | так | ціль до якої застосовуються санітайзери |
| `ASAN` | keyword | ні | AddressSanitizer |
| `UBSAN` | keyword | ні | UndefinedBehaviorSanitizer |
| `TSAN` | keyword | ні | ThreadSanitizer |
| `LSAN` | keyword | ні | LeakSanitizer (окремо, якщо без ASAN) |

#### Прапори за санітайзером

| Санітайзер | Compile flags | Link flags |
|---|---|---|
| `ASAN` | `-fsanitize=address -fno-omit-frame-pointer` | `-fsanitize=address` |
| `UBSAN` | `-fsanitize=undefined -fsanitize=float-divide-by-zero -fsanitize=integer-divide-by-zero -fno-sanitize-recover=undefined` | `-fsanitize=undefined` |
| `TSAN` | `-fsanitize=thread -fno-omit-frame-pointer` | `-fsanitize=thread` |
| `LSAN` (без ASAN) | `-fsanitize=leak` | `-fsanitize=leak` |

LSAN вбудований в ASAN — окремий `-fsanitize=leak` застосовується лише якщо ASAN не увімкнений.

#### Помилки

| Умова | Поведінка |
|---|---|
| `TSAN` + (`ASAN` або `LSAN`) | `FATAL_ERROR`: несумісні санітайзери |
| Невідомий keyword | `WARNING` з іменем невідомого санітайзера |
| `MSVC` | `WARNING` + тільки `/fsanitize=address`, повертається |
| Крос-компіляція | `WARNING` (може не запуститись без runtime), продовжує |
| `SANITIZERS_ENABLED=OFF` | no-op |

#### Приклади

```cmake
include(Sanitizers)

# ASAN + UBSAN (типовий розробницький пресет)
target_enable_sanitizers(my_app ASAN UBSAN)

# Thread sanitizer (окремий build — несумісний з ASAN)
target_enable_sanitizers(my_app TSAN)

# Тільки Leak Sanitizer
target_enable_sanitizers(my_app LSAN)

# Вимкнути глобально
cmake ... -DSANITIZERS_ENABLED=OFF
```

---

## CrossCompileHelpers.cmake

### cross_check_cxx_flag

```cmake
cross_check_cxx_flag(TARGET <target> FLAG <flag> [REQUIRED])
```

Перевіряє підтримку C++ прапора компілятором через `check_cxx_compiler_flag()`.
При успіху додає прапор через `target_compile_options(PRIVATE ...)`.

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `TARGET` | keyword + значення | так | CMake ціль |
| `FLAG` | keyword + значення | так | прапор для перевірки (напр. `-march=armv8.2-a`) |
| `REQUIRED` | keyword | ні | якщо задано і прапор не підтримується — `FATAL_ERROR` |

#### Кешування

Результат перевірки кешується у змінній `HAVE_CXX_FLAG_<normalized_flag>`,
де `<normalized_flag>` — прапор з заміною всіх `[^a-zA-Z0-9_]` на `_`.

Приклад: `-march=armv8.2-a` → `HAVE_CXX_FLAG__march_armv8_2_a`.

#### Поведінка

| Стан | `REQUIRED` | Результат |
|---|---|---|
| Прапор підтримується | — | додається до target |
| Прапор не підтримується | ні | `STATUS` повідомлення, пропуск |
| Прапор не підтримується | так | `FATAL_ERROR` |
| `TARGET` або `FLAG` відсутні | — | `FATAL_ERROR` |

#### Приклади

```cmake
include(CrossCompileHelpers)

cross_check_cxx_flag(TARGET my_app FLAG -march=armv8.2-a)
cross_check_cxx_flag(TARGET my_app FLAG -fsomething REQUIRED)
```

---

### cross_feature_check

```cmake
cross_feature_check(
    FEATURE  <name>
    CODE     <cpp_code>
    [COMPILE_FLAGS <flags...>]
)
```

Перевіряє наявність C++ фічі через `try_compile`. Ніколи не використовує
`try_run` — безпечно при крос-компіляції.

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `FEATURE` | keyword + значення | так | ім'я для кешованої змінної `HAVE_<FEATURE>` |
| `CODE` | keyword + значення | так | повний C++ код для компіляції (включно з `main`) |
| `COMPILE_FLAGS` | keyword + список | ні | додаткові прапори для `try_compile` |

#### Кешування

Результат зберігається у `CACHE BOOL HAVE_<FEATURE>`. При повторному виклику
з тим самим `FEATURE` — одразу повертається (no-op).

#### Результат

Після виклику доступна змінна `HAVE_<FEATURE>`:
- `TRUE` — код скомпілювався успішно.
- `FALSE` — компіляція провалилась.

#### Поведінка

| Стан | Результат |
|---|---|
| `FEATURE` або `CODE` відсутні | `FATAL_ERROR` |
| `HAVE_<FEATURE>` вже визначена | no-op (повертається одразу) |
| Компіляція успішна | `HAVE_<FEATURE> = TRUE`, `STATUS` повідомлення |
| Компіляція провалена | `HAVE_<FEATURE> = FALSE`, `STATUS` повідомлення |

#### Приклад

```cmake
include(CrossCompileHelpers)

cross_feature_check(
    FEATURE CXX_HAS_INT128
    CODE    "int main() { __int128 x = 0; (void)x; return 0; }"
)
if(HAVE_CXX_HAS_INT128)
    target_compile_definitions(my_app PRIVATE HAS_INT128=1)
endif()
```

---

### cross_detect_platform

```cmake
cross_detect_platform()
```

Визначає кінцеву платформу і виставляє кешові змінні.

Параметрів немає. Безпечно викликати кілька разів (результат кешується).

#### Змінні що виставляються

| Змінна | Тип | Опис |
|---|---|---|
| `PLATFORM_NAME` | `STRING` | Конкретна назва: `"RPi4"`, `"RPi5"`, `"RPi3"`, `"Yocto"`, `"Ubuntu"`, `"Debian"`, `"Linux-aarch64"`, … |
| `PLATFORM_CROSS_COMPILE` | `BOOL` | Крос-компіляція (хост ≠ ціль) |
| `PLATFORM_RPI` | `BOOL` | Ціль — Raspberry Pi (будь-яка модель) |
| `PLATFORM_RPI4` | `BOOL` | Ціль — RPi 4/400/CM4 (BCM2711, VC4 ISP) |
| `PLATFORM_RPI5` | `BOOL` | Ціль — RPi 5/CM5 (BCM2712, PiSP ISP) |
| `PLATFORM_YOCTO` | `BOOL` | Ціль — Yocto Linux |
| `PLATFORM_ARM` | `BOOL` | Ціль — ARM (aarch64 або arm32) |
| `PLATFORM_X86_64` | `BOOL` | Ціль — x86_64 |

`PLATFORM_ARM` / `PLATFORM_X86_64` визначаються виключно з `CMAKE_SYSTEM_PROCESSOR`
і не залежать від того, крос це чи нативна збірка.

#### Логіка визначення PLATFORM_NAME

| Режим | Джерело | Приклади |
|---|---|---|
| Крос | Ім'я toolchain-файлу (без `.cmake`) | `RaspberryPi4.cmake` → `"RPi4"`, `Yocto.cmake` → `"Yocto"` |
| Нативна ARM | `/proc/device-tree/model` | `"Raspberry Pi 4 …"` → `"RPi4"` |
| Нативна x86_64 | `/etc/os-release` → `NAME=` | `"Ubuntu"`, `"Debian"`, `"Linux-x86_64"` |

#### Приклад

```cmake
cross_detect_platform()
message(STATUS "Target: ${PLATFORM_NAME}")

if(PLATFORM_RPI4)
    target_compile_options(my_app PRIVATE -mcpu=cortex-a72)
elseif(PLATFORM_RPI5)
    target_compile_options(my_app PRIVATE -mcpu=cortex-a76)
endif()
```

---

### cross_get_target_info

```cmake
cross_get_target_info()
```

Виводить діагностичну інформацію про поточну конфігурацію.

Параметрів немає. Виводить через `message(STATUS ...)`:

```
=== Cross-compile configuration ===
  CMAKE_CROSSCOMPILING     : TRUE/FALSE
  CMAKE_SYSTEM_NAME        : Linux
  CMAKE_SYSTEM_PROCESSOR   : aarch64
  CMAKE_C_COMPILER         : /usr/bin/aarch64-linux-gnu-gcc
  CMAKE_CXX_COMPILER       : /usr/bin/aarch64-linux-gnu-g++
  CMAKE_SYSROOT            : /srv/rpi4-sysroot
  CMAKE_FIND_ROOT_PATH     : /srv/rpi4-sysroot
  PLATFORM_NAME            : RPi4
  PLATFORM_CROSS_COMPILE   : TRUE
  PLATFORM_RPI             : TRUE
  PLATFORM_RPI4            : TRUE
  PLATFORM_RPI5            : FALSE
  PLATFORM_YOCTO           : FALSE
  PLATFORM_ARM             : TRUE
  PLATFORM_X86_64          : FALSE
===================================
```

> Для відображення `PLATFORM_*` змінних потрібно попередньо викликати `cross_detect_platform()`.

---

## GitVersion.cmake

### git_get_version

```cmake
git_get_version(<out_var> [FALLBACK <version>])
```

Отримує версію проєкту з найближчого git тегу у форматі `X.Y.Z` або `vX.Y.Z`.

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `out_var` | змінна | так | куди записується результат |
| `FALLBACK` | keyword + значення | ні | версія при відсутності тегу або git (за замовч. `"0.0.0"`) |

#### Алгоритм пошуку тегу

1. `git describe --tags --match "[0-9]*.[0-9]*.[0-9]*" --abbrev=0`
2. Якщо не знайдено: `git describe --tags --match "v[0-9]*.[0-9]*.[0-9]*" --abbrev=0`
3. Відкидає префікс `v` / `V`.
4. Перевіряє формат `^[0-9]+\.[0-9]+\.[0-9]+$`.

#### Поведінка

| Умова | Результат |
|---|---|
| Тег знайдений, формат вірний | `out_var = "X.Y.Z"` |
| git не знайдено | `WARNING`, `out_var = FALLBACK` |
| Тег не знайдено | `WARNING`, `out_var = FALLBACK` |
| Тег не відповідає формату | `WARNING`, `out_var = FALLBACK` |

#### Приклади

```cmake
include(GitVersion)

git_get_version(MY_VERSION)                  # → "1.2.3" або "0.0.0"
git_get_version(MY_VERSION FALLBACK "1.0.0") # → "1.2.3" або "1.0.0"

project(MyApp VERSION ${MY_VERSION})
```

---

### git_get_commit_hash

```cmake
git_get_commit_hash(<out_var> [LENGTH <n>])
```

Отримує скорочений хеш останнього коміту (`git rev-parse --short=<n> HEAD`).

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `out_var` | змінна | так | куди записується результат |
| `LENGTH` | keyword + число | ні | кількість символів хешу (за замовч. `7`) |

#### Поведінка

| Умова | Результат |
|---|---|
| Успіх | `out_var = "<hash>"` (рядок з `LENGTH` символів) |
| git не знайдено | `WARNING`, `out_var = "unknown"` |
| HEAD недоступний (порожній репозиторій) | `WARNING`, `out_var = "unknown"` |

#### Приклади

```cmake
include(GitVersion)

git_get_commit_hash(GIT_HASH)               # → "a1b2c3d" (7 символів)
git_get_commit_hash(GIT_HASH_LONG LENGTH 12) # → "a1b2c3d4e5f6"

# Вбудувати у бінарник
configure_file(version.h.in version.h @ONLY)
# version.h.in: #define GIT_COMMIT "@GIT_HASH@"
```

---

## BinaryDeps.cmake

### ep_check_binary_deps

```cmake
ep_check_binary_deps(<binary_path> [<out_var>])
```

Рекурсивно знаходить усі динамічні залежності бінарного файлу та класифікує
їх за джерелом. Виводить дерево залежностей у лог CMake (`message(STATUS ...)`).

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `binary_path` | шлях | так | шлях до бінарника або `.so` |
| `out_var` | змінна | ні | якщо вказано — записує повні шляхи EP бібліотек для деплою (без TOOLCHAIN при крос-збірці, без MISSING, без дублів) |

#### Категорії залежностей

| Мітка | Джерело | Рекурсія |
|---|---|---|
| `[EP]` | `EXTERNAL_INSTALL_PREFIX/lib` | так |
| `[TOOLCHAIN]` | директорія компілятора (`gcc -print-libgcc-file-name`) | тільки без sysroot |
| `[SYSROOT]` | `CMAKE_SYSROOT/lib`, `/usr/lib` + multiarch | ні (листовий вузол) |
| `[SYSTEM]` | `/lib`, `/usr/lib`, `/lib64`, `/usr/lib64` + multiarch | ні (листовий вузол) |
| `[MISSING]` | не знайдено жодним шляхом | — |

> **Крос-збірка (`CMAKE_SYSROOT` задано):** бібліотеки категорії `[TOOLCHAIN]` (libstdc++,
> libgcc_s тощо) **не включаються** у deploy list і рекурсія по них не відбувається —
> вони вже присутні на цільовій платформі в правильній версії.

#### Зовнішні залежності

| Змінна | Звідки | Призначення |
|---|---|---|
| `CMAKE_READELF` | CMake (крос-білд) або `find_program(readelf)` | читання ELF dynamic section |
| `EXTERNAL_INSTALL_PREFIX` | `cmake/external/Common.cmake` | директорія EP артефактів |
| `CMAKE_SYSROOT` | toolchain файл (опційно) | sysroot для крос-компіляції |
| `CMAKE_C_COMPILER` | toolchain / системний | пошук директорії тулчейна |

#### Поведінка

| Стан | Результат |
|---|---|
| `binary_path` не існує | `WARNING`, повернення |
| `readelf` не знайдено | `FATAL_ERROR` |
| Цикл залежностей | захист через список відвіданих вузлів |
| `out_var` не переданий | результат тільки у логу |
| `out_var` переданий | список повних шляхів у PARENT_SCOPE |

#### Вивід

Дерево з відступами (2 пробіли на рівень) + зведення:

```
-- [BinaryDeps] /path/to/libopencv_core.so
-- [BinaryDeps] ─────────────────────────────────────────
--   [EP]        libjpeg.so.62  (/opt/ep/lib/libjpeg.so.62)
--     [EP]        libz.so.1  (/opt/ep/lib/libz.so.1)
--   [TOOLCHAIN] libstdc++.so.6  (/usr/lib/gcc/.../libstdc++.so.6)
--   [SYSROOT]   libc.so.6  (/srv/sysroot/lib/aarch64-linux-gnu/libc.so.6)
--   [SYSTEM]    libm.so.6  (/usr/lib/x86_64-linux-gnu/libm.so.6)
-- [BinaryDeps] ─────────────────────────────────────────
-- [BinaryDeps] Зведення:
-- [BinaryDeps]   [EP]        5 бібліотек(и)
-- [BinaryDeps]   [TOOLCHAIN] 2 бібліотек(и)
-- [BinaryDeps]   [SYSROOT]   8 бібліотек(и)
-- [BinaryDeps]   [SYSTEM]    3 бібліотек(и)
```

#### Приклади

```cmake
include(BinaryDeps)

# Тільки вивід у лог
ep_check_binary_deps("/path/to/mybinary")

# Отримати список повних шляхів
ep_check_binary_deps("/path/to/mybinary" MY_DEPS)
foreach(_lib IN LISTS MY_DEPS)
    message(STATUS "  dep: ${_lib}")
endforeach()

# З generator expression (у post-build кроці)
ep_check_binary_deps($<TARGET_FILE:my_target> MY_TARGET_DEPS)

# Скопіювати всі EP залежності поряд з бінарником
ep_check_binary_deps("${_mylib}" _deps)
foreach(_dep IN LISTS _deps)
    if(_dep MATCHES "^${EXTERNAL_INSTALL_PREFIX}")
        file(COPY "${_dep}" DESTINATION "${CMAKE_INSTALL_PREFIX}/lib")
    endif()
endforeach()
```

---

## InstallHelpers.cmake

### target_add_ep_rpath

```cmake
target_add_ep_rpath(<target>)
```

Додає `$ORIGIN/../lib` до `INSTALL_RPATH` таргету — так само як EP-бібліотеки
(еквівалент `-DCMAKE_INSTALL_RPATH=$ORIGIN/../lib` у `ep_cmake_args()`).

Використовує `APPEND`, тому безпечно якщо `INSTALL_RPATH` вже задано.
Також виставляє `BUILD_WITH_INSTALL_RPATH=ON` та `INSTALL_RPATH_USE_LINK_PATH=OFF`.

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `target` | ім'я CMake цілі | так | ціль (executable або shared library) |

#### Приклад

```cmake
add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE PNG::PNG OpenCV::opencv_core)
target_add_ep_rpath(my_app)
```

---

### project_setup_install

```cmake
project_setup_install(<target>)
```

Налаштовує кастомну інсталяцію головного виконуваного файлу.
Підключається автоматично через `cmake/BuildConfig.cmake`.

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `target` | ім'я CMake цілі | так | ціль для інсталяції |

#### Цілі що створюються

| Ціль | Умова | Призначення |
|---|---|---|
| `install_<target>` | завжди | Копіює виконуваний файл і EP залежності |
| `install_<target>_stripped` | тільки `RelWithDebInfo` | Те саме + strip debug-інформації |

#### Структура директорій інсталяції

Для бінарника з runtime ресурсами (наприклад, libcamera):

```
${CMAKE_BINARY_DIR}/
└── install_<BuildType>/
    ├── bin/
    │   └── camera_app
    ├── lib/
    │   ├── libcamera.so            ← EP залежності (BinaryDeps)
    │   ├── libcamera-base.so
    │   └── libcamera/              ← runtime ресурси (RuntimeDeps)
    │       ├── ipa_rpi_vc4.so
    │       ├── ipa_rpi_vc4.so.sign
    │       └── ipa_rpi_vc4_proxy
    ├── share/
    │   └── libcamera/
    │       └── pipeline/rpi/vc4/
    └── etc/
        └── libcamera/ipa/
```

#### Реалізація

Обидві цілі запускають `cmake/install_project.cmake` через `add_custom_target` з
`cmake -P`. Аналіз залежностей виконується через `ep_check_binary_deps` (BinaryDeps.cmake).
Runtime ресурси збираються через `ep_collect_runtime_resources` (RuntimeDeps.cmake) — обидва
кроки виконуються у момент запуску цілі, а не під час конфігурації.

**Порядок виконання:**
1. `ep_check_binary_deps` → копіює `lib/*.so` (link-time залежності)
2. Strip `lib/*.so` (якщо `DO_STRIP=ON`) — IPA модулів іще нема, вони не стріпуються
3. RuntimeDeps → копіює `lib/libcamera/`, `share/libcamera/`, `etc/libcamera/`
4. Strip + resign IPA `.so` (якщо `DO_STRIP=ON` + `SIGN_KEY` є)

При стрипуванні:
- `--strip-all` для виконуваного файлу (видаляє всі символи та налагоджувальну інформацію)
- `--strip-debug` для кожної link-time `.so` (зберігає таблицю символів для `dlopen`)
- IPA `.so` — `--strip-debug` + автоматичний ре-підпис через `openssl` (якщо `SIGN_KEY` задано)
- Симлінки та `.sign` файли пропускаються

#### Зовнішні залежності

| Змінна | Звідки | Призначення |
|---|---|---|
| `EXTERNAL_INSTALL_PREFIX` | `cmake/external/Common.cmake` | пошук EP бібліотек |
| `CMAKE_READELF` | toolchain або `find_program(readelf)` | аналіз ELF залежностей |
| `CMAKE_STRIP` | toolchain або системний | стрипування |
| `CMAKE_SYSROOT` | toolchain файл | класифікація sysroot бібліотек |
| `CMAKE_INSTALL_BINDIR` / `LIBDIR` | `GNUInstallDirs` | відносні шляхи (bin/, lib/) |

#### Помилки

| Умова | Поведінка |
|---|---|
| `target` не існує | `FATAL_ERROR` |
| `cmake/install_project.cmake` не знайдено | `FATAL_ERROR` |
| `DO_STRIP=ON` + `CMAKE_STRIP` не передано | `WARNING`, стрипування пропускається |
| `DO_STRIP=ON` + `openssl` не в PATH | `WARNING`, IPA ре-підпис пропускається |
| Runtime ресурс не знайдено (EP не зібрано) | `WARNING`, продовжує |

#### Приклад — стандартний (без libcamera)

```cmake
add_executable(opencv_example main.cpp)
target_link_libraries(opencv_example PRIVATE OpenCV::opencv_core)
ep_target_add_compile_deps(opencv_example)
project_setup_install(opencv_example)
```

```bash
cmake --build build/rpi4-relwithdebinfo --target install_opencv_example
cmake --build build/rpi4-relwithdebinfo --target install_opencv_example_stripped
```

#### Приклад — з libcamera (runtime ресурси + IPA модулі)

```cmake
add_executable(camera_app main.cpp)
target_link_libraries(camera_app PRIVATE libcamera::libcamera)
target_add_ep_rpath(camera_app)
ep_target_add_compile_deps(camera_app)
project_setup_install(camera_app)
# → install_camera_app, install_camera_app_stripped
#
# install_camera_app_stripped автоматично:
#   1. strip --strip-debug libcamera.so, libcamera-base.so
#   2. Копіює lib/libcamera/ (IPA modules + proxy + .sign)
#   3. strip --strip-debug ipa_rpi_vc4.so + openssl resign → оновлює .sign
```

```bash
# Деплой на RPi (стрипований, з IPA модулями)
cmake --build build/rpi4-relwithdebinfo --target install_camera_app_stripped
rsync -av build/rpi4-relwithdebinfo/install_RelWithDebInfo_stripped/ pi@192.168.1.100:~/app/
```

---

## RuntimeDeps.cmake

Модуль управління runtime-ресурсами бібліотек з динамічними плагінами.

Підключається автоматично через `cmake/external/Common.cmake` (не потребує явного
`include`) і через `InstallHelpers.cmake` для `project_setup_install`.

**Проблема яку вирішує:** деякі бібліотеки завантажують плагіни та конфіги через
`dlopen()` — вони не є link-time залежностями (не видимі `ep_check_binary_deps`/`readelf`)
і тому не копіюються автоматично при інсталяції. Приклад: libcamera завантажує
IPA модулі (`ipa_rpi_vc4.so`) з `lib/libcamera/` у runtime.

**Додаткова складність:** IPA `.so` мають SHA256-підпис (`ipa_rpi_vc4.so.sign`).
При стрипуванні підпис інвалідується — модуль повинен бути ре-підписаний тим самим
приватним ключем що використовувався при збірці.

---

### ep_register_runtime_dirs

```cmake
ep_register_runtime_dirs(<target>
    BASE_DIR <abs_path>
    DIRS <rel_dir1> [<rel_dir2>...]
    [NO_STRIP]
    [SIGN_KEY <key_path>]
)
```

Реєструє runtime-директорії як властивості IMPORTED target.
Викликати у `Lib*.cmake` після `ep_imported_library_from_ep()`.

#### Параметри

| Параметр | Тип | Обов'язковий | Опис |
|---|---|---|---|
| `target` | ім'я CMake цілі | так | IMPORTED target (напр. `libcamera::libcamera`) |
| `BASE_DIR` | абсолютний шлях | так | базова директорія (зазвичай `EXTERNAL_INSTALL_PREFIX`) |
| `DIRS` | список відносних шляхів | так | директорії відносно `BASE_DIR`; перший компонент → destination parent |
| `NO_STRIP` | keyword | ні | `.so` у цих директоріях не стріпувати без ре-підпису |
| `SIGN_KEY` | шлях | ні | приватний ключ для strip + resign; якщо відсутній і `NO_STRIP` — `.so` не стріпуються зовсім |

#### Destination mapping

| DIRS запис | Джерело | Призначення |
|---|---|---|
| `lib/libcamera` | `BASE_DIR/lib/libcamera/` | `INSTALL_PREFIX/lib/libcamera/` |
| `share/libcamera` | `BASE_DIR/share/libcamera/` | `INSTALL_PREFIX/share/libcamera/` |
| `etc/libcamera` | `BASE_DIR/etc/libcamera/` | `INSTALL_PREFIX/etc/libcamera/` |

#### Target properties що виставляються

| Property | Тип | Вміст |
|---|---|---|
| `EP_RUNTIME_DIRS_SRC` | list | абсолютні шляхи до директорій ресурсів |
| `EP_RUNTIME_DIRS_DST` | list | відносні destination parent (перший компонент DIRS) |
| `EP_RUNTIME_NO_STRIP` | BOOL | `TRUE` / `FALSE` |
| `EP_RUNTIME_SIGN_KEY` | string | шлях до ключа або порожній рядок |

#### Поведінка при install

| Умова | Результат |
|---|---|
| Директорія існує | Рекурсивне копіювання у destination |
| Директорія не існує (EP не зібрано) | `WARNING`, пропуск |
| `NO_STRIP=FALSE`, `DO_STRIP=ON` | `.so` стріпуються в загальному циклі |
| `NO_STRIP=TRUE`, `SIGN_KEY` відсутній, `DO_STRIP=ON` | `.so` **не** стріпуються |
| `NO_STRIP=TRUE`, `SIGN_KEY` є, `DO_STRIP=ON` | `.so` стріпуються + ре-підписуються |

#### Приклад (у Lib*.cmake)

```cmake
# У LibCamera.cmake, після ep_imported_library_from_ep():
ep_register_runtime_dirs(libcamera::libcamera
    BASE_DIR "${EXTERNAL_INSTALL_PREFIX}"
    DIRS
        lib/libcamera      # IPA .so + .sign + proxy executables
        share/libcamera    # pipeline configs (rpi/vc4/, rpi/pisp/)
        etc/libcamera      # system IPA configs
    NO_STRIP
    SIGN_KEY
        "${EXTERNAL_INSTALL_PREFIX}/dependencies/libcamera/key/ipa/ipa-priv-key.pem"
)
```

---

### ep_collect_runtime_resources

```cmake
ep_collect_runtime_resources(<main_target> <out_file_var>)
```

Рекурсивно обходить `LINK_LIBRARIES` `<main_target>` і транзитивно
`INTERFACE_LINK_LIBRARIES` усіх залежностей, збирає всі targets з
`EP_RUNTIME_DIRS_SRC` property і серіалізує результат у cmake-файл.

Викликається **автоматично** з `project_setup_install()` — ручний виклик не потрібен.

#### Алгоритм обходу

1. Стартує з `LINK_LIBRARIES` головного таргету (прямі залежності)
2. Для кожного dependency рекурсивно обходить `INTERFACE_LINK_LIBRARIES`
3. Пропускає `$<...>` generator expressions, нетаргети, `_ep_sync_*` обгортки
4. Захист від циклів — глобальний visited-список

#### Формат згенерованого файлу

```cmake
# _ep_cfg/runtime_resources_<target>.cmake
set(EP_RT_COUNT 3)
# [0] libcamera::libcamera
set(EP_RT_SRC_0      "/path/external/lib/libcamera")
set(EP_RT_DST_0      "lib")
set(EP_RT_NO_STRIP_0 TRUE)
set(EP_RT_SIGN_KEY_0 "/path/external/dependencies/libcamera/key/ipa/ipa-priv-key.pem")
# [1] libcamera::libcamera
set(EP_RT_SRC_1      "/path/external/share/libcamera")
set(EP_RT_DST_1      "share")
set(EP_RT_NO_STRIP_1 TRUE)
set(EP_RT_SIGN_KEY_1 "/path/external/dependencies/libcamera/key/ipa/ipa-priv-key.pem")
# ...
```

#### Транзитивне виявлення

Якщо `my_app → rpicam_apps::camera_app → libcamera::libcamera`, ресурси
libcamera виявляються і копіюються автоматично — навіть якщо `my_app` не
лінкується з libcamera напряму.

---

## Сумісність між модулями

| Комбінація | Статус |
|---|---|
| `CompilerWarnings` + `Sanitizers` | сумісні |
| `Sanitizers(ASAN)` + `Sanitizers(TSAN)` на одному target | **FATAL_ERROR** |
| `Sanitizers` при `CMAKE_CROSSCOMPILING=TRUE` | `WARNING`, продовжує |
| `cross_check_cxx_flag` + `target_enable_warnings` | сумісні, незалежні |
| `GitVersion` при відсутньому git | `WARNING`, повертає fallback/unknown |
| `BinaryDeps` при відсутньому `readelf` | `FATAL_ERROR` |
| `InstallHelpers` + `BinaryDeps` | сумісні (InstallHelpers викликає BinaryDeps внутрішньо) |
| `InstallHelpers` + `RuntimeDeps` | сумісні (InstallHelpers включає RuntimeDeps автоматично) |
| `RuntimeDeps` без `InstallHelpers` | `ep_register_runtime_dirs` доступна через `Common.cmake` |
