# Специфікація: ExternalProject контракти

## Огляд архітектури

```
cmake/external/
├── Common.cmake        ← спільні утиліти, підключається першим
├── ExternalDeps.cmake  ← точка входу; include() усі бібліотеки в правильному порядку
├── LibPng.cmake
├── LibJpeg.cmake
├── LibTiff.cmake       ← залежить від LibJpeg + LibPng
├── OpenSSL.cmake
├── Boost.cmake
└── OpenCV.cmake        ← залежить від LibJpeg, LibPng, LibTiff, OpenSSL
cmake/SuperBuild.cmake  ← superbuild режим
```

---

## Контракт файлу Lib*.cmake

Кожен `cmake/external/Lib<Name>.cmake` зобов'язаний виконувати наведені нижче вимоги.

### 1. Надати CMake imported target

| Бібліотека | Target | Тип |
|---|---|---|
| libpng | `PNG::PNG` | `SHARED IMPORTED` |
| libjpeg-turbo | `JPEG::JPEG` | `SHARED IMPORTED` |
| libtiff | `TIFF::TIFF` | `SHARED IMPORTED` |
| OpenSSL | `OpenSSL::SSL`, `OpenSSL::Crypto` | `SHARED IMPORTED` |
| Boost | `Boost::headers` | `INTERFACE IMPORTED` |
| OpenCV | `opencv_core`, `opencv_imgproc`, … | `SHARED IMPORTED` |

Target повинен бути оголошений через `ep_imported_library()` або `ep_imported_library_from_ep()` з `Common.cmake`. Виклики ідемпотентні — повторний include() безпечний.

### 2. Підтримувати опцію USE_SYSTEM_<LIB>

```cmake
option(USE_SYSTEM_LIBFOO "Використовувати системний libfoo" OFF)
```

- `OFF` (за замовч.) → збирати через ExternalProject.
- `ON` → `find_package(Foo REQUIRED)` у системі / sysroot.

При крос-компіляції з sysroot `find_package` автоматично шукає в sysroot через `CMAKE_FIND_ROOT_PATH`.

### 3. Надати кеш-змінні версії та URL

```cmake
set(LIBFOO_VERSION "X.Y.Z" CACHE STRING "Версія для збірки")
set(LIBFOO_URL     "https://..." CACHE STRING "URL архіву")
set(LIBFOO_URL_HASH ""          CACHE STRING "SHA256 хеш (порожньо = не перевіряти)")
```

### 4. Перевіряти кеш перед запуском ExternalProject

```cmake
if(EXISTS "${_foo_lib}" AND EXISTS "${_foo_hdr}")
    # Вже встановлено — просто створити target, не перезбирати
    ep_imported_library(Foo::Foo "${_foo_lib}" "${_foo_inc}")
else()
    ExternalProject_Add(libfoo_ep ...)
    ep_imported_library_from_ep(Foo::Foo libfoo_ep "${_foo_lib}" "${_foo_inc}")
endif()
```

Шляхи визначаються відносно `EXTERNAL_INSTALL_PREFIX`.

### 5. Використовувати ep_cmake_args() для аргументів збірки

```cmake
ep_cmake_args(_foo_cmake_args
    -DFOO_SHARED=ON
    -DFOO_TESTS=OFF
)
ExternalProject_Add(libfoo_ep
    URL          "${LIBFOO_URL}"
    CMAKE_ARGS   ${_foo_cmake_args}
    BUILD_BYPRODUCTS "${_foo_lib}"
    LOG_DOWNLOAD ON
    LOG_BUILD    ON
    LOG_INSTALL  ON
)
```

`ep_cmake_args()` автоматично передає toolchain, sysroot, компілятори, RPATH.

### 6. Прибирати локальні змінні

```cmake
unset(_foo_lib)
unset(_foo_inc)
unset(_foo_hdr)
```

---

## Common.cmake — API утиліт

### EXTERNAL_INSTALL_PREFIX

Шлях встановлення всіх сторонніх бібліотек.

```
build/External/<toolchain>/<BuildType>/
```

Приклади:
- `build/External/RaspberryPi4/Release`
- `build/External/native/Debug`

Можна перевизначити через `-DEXTERNAL_INSTALL_PREFIX=<path>`.

Автоматично додається до `CMAKE_PREFIX_PATH` і `CMAKE_FIND_ROOT_PATH`.

---

### ep_cmake_args(out_var [extra...])

Формує список аргументів для `ExternalProject_Add(CMAKE_ARGS ...)`.

Автоматично включає:
- `-DCMAKE_BUILD_TYPE`
- `-DCMAKE_INSTALL_PREFIX=${EXTERNAL_INSTALL_PREFIX}`
- `-DBUILD_SHARED_LIBS=ON`
- `-DCMAKE_TOOLCHAIN_FILE` (якщо задано)
- `-DCMAKE_C_COMPILER`, `-DCMAKE_CXX_COMPILER`
- `-DCMAKE_SYSROOT`, `-DRPI_SYSROOT`, `-DYOCTO_SDK_SYSROOT` (якщо задано)
- `-DCMAKE_AR`, `-DCMAKE_RANLIB`, `-DCMAKE_STRIP`, `-DCMAKE_LINKER`
- `-DCMAKE_INSTALL_RPATH=$ORIGIN/../lib` (якщо `USE_ORIGIN_RPATH=ON`)

Додаткові аргументи передаються через `ARGN`.

---

### ep_imported_library(target lib_path inc_dir)

Створює `SHARED IMPORTED GLOBAL` target. Ідемпотентний.

```cmake
ep_imported_library(PNG::PNG
    "${EXTERNAL_INSTALL_PREFIX}/lib/libpng.so"
    "${EXTERNAL_INSTALL_PREFIX}/include"
)
```

---

### ep_imported_interface(target inc_dir)

Створює `INTERFACE IMPORTED GLOBAL` target (header-only). Ідемпотентний.

---

### ep_imported_library_from_ep(target ep_name lib_path inc_dir)

Як `ep_imported_library`, але додає `add_dependencies(target ep_name)`.
Викликати **після** `ExternalProject_Add`.

---

### ep_imported_interface_from_ep(target ep_name inc_dir)

Як `ep_imported_interface`, але з залежністю від ExternalProject.

---

### _ep_collect_deps(out_var [ep_target...])

Повертає список тих EP-цілей зі списку що реально оголошені (`TARGET` існує).
Безпечний при відсутності деяких targets.

```cmake
_ep_collect_deps(_deps libjpeg_ep libpng_ep)
ExternalProject_Add(libtiff_ep DEPENDS ${_deps} ...)
```

---

### USE_ORIGIN_RPATH

`option(USE_ORIGIN_RPATH ... ON)` — вбудовує `$ORIGIN/../lib` у RPATH бінарників.
Забезпечує пошук `.so` відносно самого бінарника. Важливо для розгортання на RPi.

---

## Порядок залежностей у ExternalDeps.cmake

```
LibPng   ──┐
LibJpeg  ──┼──▶ LibTiff ──┐
           │               └──▶ OpenCV
OpenSSL  ──┘──────────────────▶ OpenCV
Boost    ─────────────────────▶ OpenCV
```

Порядок `include()` у `ExternalDeps.cmake`:
1. `Common.cmake`
2. `LibPng.cmake`, `LibJpeg.cmake`, `OpenSSL.cmake`, `Boost.cmake` (незалежні)
3. `LibTiff.cmake` (залежить від LibJpeg + LibPng)
4. `OpenCV.cmake` (залежить від усіх вище)

---

## SuperBuild.cmake

Активується через `-DSUPERBUILD=ON`.

```cmake
# CMakeLists.txt
if(SUPERBUILD)
    include(cmake/SuperBuild.cmake)
    return()
endif()
```

### Що робить SuperBuild

1. Підключає `ExternalDeps.cmake` → оголошує EP для кожної бібліотеки.
2. Оголошує основний проєкт як `ExternalProject_Add(main_project_ep ...)` з `DEPENDS` на всі EP бібліотек.
3. Передає в основний проєкт: toolchain, sysroot, компілятори, `BUILD_TESTS`, санітайзери, `USE_SYSTEM_*`.
4. `BUILD_ALWAYS ON` — основний проєкт перебудовується при кожному `cmake --build`.

### Кешування в CI

```bash
# Перший запуск: збирає deps і основний проєкт
cmake -DSUPERBUILD=ON --preset rpi4-release -DRPI_SYSROOT=/srv/sysroot
cmake --build build/rpi4-release

# Кешувати між CI-запусками:
#   build/External/RaspberryPi4/Release/  ← deps (кешуються)
#   build/rpi4-release/main_project/      ← основний проєкт (завжди перебудовується)
```

---

## Кроки додавання нової бібліотеки

1. Створити `cmake/external/LibNew.cmake` за шаблоном:

```cmake
# cmake/external/LibNew.cmake
# Provides: New::New

option(USE_SYSTEM_LIBNEW "Використовувати системний libnew" OFF)

set(LIBNEW_VERSION  "X.Y.Z" CACHE STRING "Версія libnew")
set(LIBNEW_URL      "https://..." CACHE STRING "URL архіву")
set(LIBNEW_URL_HASH "" CACHE STRING "SHA256 хеш (порожньо = не перевіряти)")

set(_new_lib "${EXTERNAL_INSTALL_PREFIX}/lib/libnew.so")
set(_new_inc "${EXTERNAL_INSTALL_PREFIX}/include")
set(_new_hdr "${EXTERNAL_INSTALL_PREFIX}/include/new.h")

if(USE_SYSTEM_LIBNEW)
    find_package(New REQUIRED)
else()
    if(EXISTS "${_new_lib}" AND EXISTS "${_new_hdr}")
        ep_imported_library(New::New "${_new_lib}" "${_new_inc}")
    else()
        set(_new_hash_arg "")
        if(LIBNEW_URL_HASH)
            set(_new_hash_arg URL_HASH "SHA256=${LIBNEW_URL_HASH}")
        endif()

        ep_cmake_args(_new_cmake_args
            -DLIBNEW_BUILD_SHARED=ON
            -DLIBNEW_BUILD_TESTS=OFF
        )

        ExternalProject_Add(libnew_ep
            URL             "${LIBNEW_URL}"
            ${_new_hash_arg}
            CMAKE_ARGS      ${_new_cmake_args}
            BUILD_BYPRODUCTS "${_new_lib}"
            LOG_DOWNLOAD    ON
            LOG_BUILD       ON
            LOG_INSTALL     ON
        )

        ep_imported_library_from_ep(New::New libnew_ep "${_new_lib}" "${_new_inc}")
    endif()
endif()

unset(_new_lib)
unset(_new_inc)
unset(_new_hdr)
```

2. Додати `include("${_ep_dir}/LibNew.cmake")` у `ExternalDeps.cmake` у правильному місці за залежностями.

3. Якщо нова бібліотека є залежністю для іншої — передати через `_ep_collect_deps()`:

```cmake
_ep_collect_deps(_new_deps libnew_ep)
ExternalProject_Add(libother_ep DEPENDS ${_new_deps} ...)
```

4. Якщо використовується SuperBuild — додати `libnew_ep` до списку `_sb_all_lib_eps` у `SuperBuild.cmake`.

5. Якщо є опція `USE_SYSTEM_LIBNEW` — додати до циклу передачі прапорів у `SuperBuild.cmake`:

```cmake
# У SuperBuild.cmake список _lib IN ITEMS ...
foreach(_lib IN ITEMS LIBPNG LIBJPEG LIBTIFF BOOST OPENSSL OPENCV LIBNEW)
```
