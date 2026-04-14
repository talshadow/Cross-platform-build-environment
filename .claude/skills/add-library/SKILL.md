---
name: add-library
description: Додати нову сторонню бібліотеку до проєкту через ExternalProject. Використовувати коли потрібно інтегрувати нову бібліотеку в cmake/external/.
argument-hint: [LibraryName]
---

Додай нову сторонню бібліотеку до цього CMake-проєкту за існуючим патерном.

## Назва бібліотеки

$ARGUMENTS

## Що потрібно зробити

### 1. Створи `cmake/external/<LibName>.cmake`

Використовуй такий шаблон:

```cmake
# cmake/external/<LibName>.cmake
#
# <Короткий опис бібліотеки>
#
# Provides imported target:
#   <Namespace>::<Name>  — SHARED IMPORTED
#
# Опції:
#   USE_SYSTEM_<LIBNAME>  — ON: find_package / OFF (default): ExternalProject
#
# Кеш-змінні:
#   <LIBNAME>_VERSION, <LIBNAME>_URL, <LIBNAME>_URL_HASH

option(USE_SYSTEM_<LIBNAME>
    "Використовувати системну <LibName> замість збірки з джерел"
    OFF)

set(<LIBNAME>_VERSION  "x.y.z"  CACHE STRING "Версія <LibName>")
set(<LIBNAME>_URL      "https://..."  CACHE STRING "URL архіву <LibName>")
set(<LIBNAME>_URL_HASH ""  CACHE STRING "SHA256 хеш (порожньо = не перевіряти)")

set(_lib "${EXTERNAL_INSTALL_PREFIX}/lib/lib<name>.so")
set(_inc "${EXTERNAL_INSTALL_PREFIX}/include")

if(USE_SYSTEM_<LIBNAME>)
    find_package(<CMakeFindName> REQUIRED)
    message(STATUS "[<LibName>] Системна: ${<Var>_LIBRARIES}")

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    find_package(<CMakeFindName> QUIET
        HINTS "${EXTERNAL_INSTALL_PREFIX}"
        NO_DEFAULT_PATH)

    if(<CMakeFindName>_FOUND)
        message(STATUS "[<LibName>] Знайдено готову бібліотеку у ${EXTERNAL_INSTALL_PREFIX}")
        # target вже створено find_package — нічого більше не потрібно

    else()
        message(STATUS "[<LibName>] Буде зібрано з джерел (${<LIBNAME>_VERSION})")

        set(_hash_arg "")
        if(<LIBNAME>_URL_HASH)
            set(_hash_arg URL_HASH "SHA256=${<LIBNAME>_URL_HASH}")
        endif()

        ep_cmake_args(_cmake_args
            -DSOME_OPTION=ON
            # КРИТИЧНО: якщо бібліотека залежить від інших external libs —
            # передати явні шляхи І вимкнути системний пошук:
            # -DFOO_LIBRARY=${EXTERNAL_INSTALL_PREFIX}/lib/libfoo.so
            # -DFOO_INCLUDE_DIR=${EXTERNAL_INSTALL_PREFIX}/include
            # -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF
            # -DCMAKE_FIND_USE_CMAKE_SYSTEM_PATH=OFF
        )

        # Залежності від інших EP (якщо є)
        _ep_collect_deps(_ep_deps libpng_ep libjpeg_ep)  # <- вказати реальні

        ExternalProject_Add(<libname>_ep
            URL             "${<LIBNAME>_URL}"
            ${_hash_arg}
            DOWNLOAD_DIR    "${EP_SOURCES_DIR}/<libname>"
            CMAKE_ARGS      ${_cmake_args}
            DEPENDS         ${_ep_deps}
            BUILD_BYPRODUCTS "${_lib}"
            LOG_DOWNLOAD    ON
            LOG_BUILD       ON
            LOG_INSTALL     ON
        )

        ep_imported_library_from_ep(
            <Namespace>::<Name> <libname>_ep "${_lib}" "${_inc}")
    endif()
endif()

unset(_lib)
unset(_inc)
```

**Особливі випадки:**
- **Header-only**: замість `ep_imported_library` використовуй `ep_imported_interface` / `ep_imported_interface_from_ep`, тип target — `INTERFACE IMPORTED`
- **Не-CMake збірка** (autotools/make/custom): замість `CMAKE_ARGS` вказуй явні `CONFIGURE_COMMAND`, `BUILD_COMMAND`, `INSTALL_COMMAND`. Дивись `OpenSSL.cmake` як зразок
- **b2/Boost-подібні**: дивись `Boost.cmake` — генерація user-config.jam для крос-компіляції

### 2. Визнач залежності між бібліотеками

Перевір чи нова бібліотека залежить від вже існуючих:
- libpng_ep, libjpeg_ep, libtiff_ep, openssl_ep, boost_ep, opencv_ep

Якщо залежить:
1. Додай `_ep_collect_deps(_ep_deps ...)` і `DEPENDS ${_ep_deps}` в `ExternalProject_Add`
2. **КРИТИЧНО**: передай явні шляхи до залежних бібліотек через CMake args
3. **КРИТИЧНО**: вимкни системний пошук цих залежностей (`-DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF`)

### 3. Додай include до `cmake/external/ExternalDeps.cmake`

Встав рядок у правильному місці (після залежностей, перед залежними):

```cmake
include("${_ep_dir}/<LibName>.cmake")
```

### 4. Додай EP-ціль до `cmake/SuperBuild.cmake`

У список `_sb_all_lib_eps` додай `<libname>_ep`.

### 5. Оновити пам'ять

Оновити файл `/home/tal/.claude/projects/-home-tal-projects-SupportRaspberryPI/memory/project_third_party_skill.md`:
- Додати рядок у таблицю бібліотек
- Оновити список версій

## Важливі деталі архітектури

- **EXTERNAL_INSTALL_PREFIX** за замовченням: `<BUILD_ROOT>/<project>/external/<toolchain>/<BuildType>`
  - `BUILD_ROOT` за замовч. `~/build`, змінюється через `-DBUILD_ROOT=<path>`
  - `<toolchain>` — ім'я файлу toolchain без .cmake (або `native`)
  - Приклад: `~/build/SupportRaspberryPI/external/RaspberryPi4/Release/`
- **EP_SOURCES_DIR**: `<BUILD_ROOT>/<project>/external_sources/` — архіви завантажуються один раз для всіх toolchain. Завжди передавай `DOWNLOAD_DIR "${EP_SOURCES_DIR}/<libname>"`
- **Алгоритм кешу**: `find_package(QUIET HINTS "${EXTERNAL_INSTALL_PREFIX}" NO_DEFAULT_PATH)` → якщо знайдено — не викликати ExternalProject_Add
- **Крос-компіляція**: `ep_cmake_args()` автоматично передає CMAKE_TOOLCHAIN_FILE, CMAKE_C/CXX_COMPILER, CMAKE_SYSROOT, RPI_SYSROOT, YOCTO_SDK_SYSROOT, CMAKE_AR/RANLIB/STRIP
- **RPATH**: `$ORIGIN/../lib` через USE_ORIGIN_RPATH (передається ep_cmake_args)
- **Toolchain завантажується двічі** в CMake — не використовуй FATAL_ERROR без перевірки CMAKE_CROSSCOMPILING

## КРИТИЧНА ВИМОГА: ізоляція залежностей

Якщо бібліотека залежить від інших external libs — **обов'язково**:
1. Передати явні шляхи: `-DFOO_LIBRARY=...`, `-DFOO_INCLUDE_DIR=...`
2. Вимкнути системний пошук: `-DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF`

Порушення → мовчазне лінкування проти системної бібліотеки = критична помилка при крос-компіляції.

## Утиліти (Common.cmake)

```cmake
ep_cmake_args(out_var [extra args])        # CMake args з toolchain/sysroot/RPATH
ep_imported_library(target lib inc)        # SHARED IMPORTED
ep_imported_interface(target inc)          # INTERFACE IMPORTED (header-only)
ep_imported_library_from_ep(t ep lib inc)  # SHARED + add_dependencies
ep_imported_interface_from_ep(t ep inc)    # INTERFACE + add_dependencies
_ep_collect_deps(out_var ep1 ep2...)       # список існуючих EP-цілей для DEPENDS
```

## Перевірка

Після створення файлів перевір:
1. `grep -r "<LibName>" cmake/external/ExternalDeps.cmake` — є include?
2. `grep -r "<libname>_ep" cmake/SuperBuild.cmake` — є в списку?
3. Чи правильний порядок includes в ExternalDeps.cmake (залежності раніше залежних)?
4. Чи передані явні шляхи до всіх external залежностей?
5. Чи вимкнений системний пошук для цих залежностей?
