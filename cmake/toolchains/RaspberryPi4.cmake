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

    # Debian multiarch sysroot (RPi OS): бібліотеки лежать у
    # lib/aarch64-linux-gnu/, а не в lib/ як очікує Arch cross-compiler.
    # Додаємо ці шляхи явно щоб лінкер знаходив libc.so.6 тощо.
    #
    # ВАЖЛИВО: multiarch-триплет у sysroot може відрізнятися від префіксу
    # toolchain. Наприклад, CT-NG toolchain з префіксом aarch64-unknown-linux-gnu
    # може цілитися в Debian sysroot, де бібліотеки лежать у aarch64-linux-gnu/.
    # Автовизначаємо реальний триплет по наявності директорії у sysroot.
    if(IS_DIRECTORY "${RPI_SYSROOT}/lib/${RPI4_TOOLCHAIN_PREFIX}")
        set(_SYSROOT_MULTIARCH "${RPI4_TOOLCHAIN_PREFIX}")
    else()
        foreach(_triple "aarch64-linux-gnu" "aarch64-linux-gnueabi")
            if(IS_DIRECTORY "${RPI_SYSROOT}/lib/${_triple}")
                set(_SYSROOT_MULTIARCH "${_triple}")
                break()
            endif()
        endforeach()
        if(NOT _SYSROOT_MULTIARCH)
            set(_SYSROOT_MULTIARCH "${RPI4_TOOLCHAIN_PREFIX}")
            message(WARNING
                "[RaspberryPi4] Не вдалося визначити multiarch-триплет sysroot, "
                "використовується ${_SYSROOT_MULTIARCH}")
        else()
            message(STATUS
                "[RaspberryPi4] Sysroot multiarch: ${_SYSROOT_MULTIARCH} "
                "(toolchain prefix: ${RPI4_TOOLCHAIN_PREFIX})")
        endif()
    endif()

    set(_MULTIARCH_LIB "${RPI_SYSROOT}/lib/${_SYSROOT_MULTIARCH}")
    set(_MULTIARCH_USR "${RPI_SYSROOT}/usr/lib/${_SYSROOT_MULTIARCH}")

    # -L: лінкер знаходить libc.so.6 та інші розділені бібліотеки
    foreach(_flags_var CMAKE_EXE_LINKER_FLAGS_INIT
                       CMAKE_SHARED_LINKER_FLAGS_INIT
                       CMAKE_MODULE_LINKER_FLAGS_INIT)
        set(${_flags_var}
            "-L${_MULTIARCH_LIB} -L${_MULTIARCH_USR} ${${_flags_var}}"
            CACHE INTERNAL "")
    endforeach()

    # Наступні прапори потрібні лише коли триплет toolchain відрізняється від
    # multiarch-триплета sysroot (напр. CT-NG aarch64-unknown-linux-gnu →
    # Debian sysroot aarch64-linux-gnu).  Коли вони збігаються (стандартний
    # Ubuntu cross-compiler), GCC вже знає ці шляхи автоматично.
    if(NOT _SYSROOT_MULTIARCH STREQUAL RPI4_TOOLCHAIN_PREFIX)
        # -B: GCC-driver знаходить startup-файли (crt1.o, crti.o)
        # -isystem: multiarch include-директорія sysroot (bits/wordsize.h тощо).
        # CT-NG з триплетом aarch64-unknown-linux-gnu не знає про
        # /usr/include/aarch64-linux-gnu/ у sysroot автоматично.
        set(_multiarch_extra
            " -B${_MULTIARCH_LIB} -B${_MULTIARCH_USR}"
            " -isystem${RPI_SYSROOT}/usr/include/${_SYSROOT_MULTIARCH}")
        string(CONCAT _multiarch_extra ${_multiarch_extra})
        foreach(_flags_var CMAKE_C_FLAGS_INIT CMAKE_CXX_FLAGS_INIT)
            set(${_flags_var}
                "${${_flags_var}}${_multiarch_extra}"
                CACHE INTERNAL "")
        endforeach()
        unset(_multiarch_extra)

        # Виставляємо CACHE-змінну для не-cmake sub-builds (OpenSSL make, meson):
        # вони не читають CMAKE_C_FLAGS_INIT, тому потребують явної передачі шляхів.
        # Змінна встановлюється ТІЛЬКИ коли триплети різняться — Ubuntu build
        # (де вони збігаються) цю змінну не отримує, поведінка залишається незмінною.
        set(RPI_SYSROOT_MULTIARCH "${_SYSROOT_MULTIARCH}" CACHE INTERNAL
            "Multiarch triple sysroot (відмінний від toolchain prefix)")
    endif()

    unset(_MULTIARCH_LIB)
    unset(_MULTIARCH_USR)

    # Коли host cross-compiler новіший за GCC у sysroot (напр. Arch GCC 15 +
    # RPi OS sysroot з GCC 12/glibc 2.36), його libstdc++ потребує символів
    # GLIBC_2.38+, яких немає у sysroot.  Використовуємо -B щоб GCC шукав
    # libstdc++ / libgcc_s у відповідному каталозі GCC із самого sysroot.
    #
    # УВАГА: -B також перенаправляє GCC-internal headers (arm_neon.h тощо) на
    # версію з sysroot, яка несумісна з builtins host compiler.
    # Виправлення: отримуємо include-dir host GCC і додаємо його через -I
    # (шукається РАНІШЕ ніж -B include dir), щоб arm_neon.h host GCC мав пріоритет.
    file(GLOB _SYSROOT_GCC_DIRS
        "${RPI_SYSROOT}/usr/lib/gcc/${_SYSROOT_MULTIARCH}/[0-9]*")
    if(_SYSROOT_GCC_DIRS)
        list(SORT _SYSROOT_GCC_DIRS ORDER DESCENDING)
        list(GET _SYSROOT_GCC_DIRS 0 _SYSROOT_GCC_DIR)

        # Отримуємо власний include-dir host cross-compiler
        execute_process(
            COMMAND "${CMAKE_C_COMPILER}" -print-file-name=include
            OUTPUT_VARIABLE _HOST_GCC_INCLUDE
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)

        foreach(_flags_var CMAKE_C_FLAGS_INIT CMAKE_CXX_FLAGS_INIT)
            set(_extra "")
            # -I host include: пріоритет над -B sysroot include для arm_neon.h тощо
            if(_HOST_GCC_INCLUDE AND IS_DIRECTORY "${_HOST_GCC_INCLUDE}")
                string(APPEND _extra " -I${_HOST_GCC_INCLUDE}")
            endif()
            set(${_flags_var}
                "${${_flags_var}} -B${_SYSROOT_GCC_DIR}${_extra}"
                CACHE INTERNAL "")
        endforeach()

        unset(_HOST_GCC_INCLUDE)
        unset(_SYSROOT_GCC_DIR)
        unset(_extra)
    endif()
    unset(_SYSROOT_GCC_DIRS)
    unset(_SYSROOT_MULTIARCH)
else()
    message(STATUS
        "[RaspberryPi4] Збірка без sysroot. "
        "Для повної підтримки задайте -DRPI_SYSROOT=<path>")
    cross_toolchain_no_sysroot()
endif()
