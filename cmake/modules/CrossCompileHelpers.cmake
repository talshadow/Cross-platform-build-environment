# cmake/modules/CrossCompileHelpers.cmake
#
# Допоміжні функції для крос-компіляції.
# Вирішують типові проблеми: перевірка фічей, try_run vs try_compile тощо.
#
# Використання:
#   include(CrossCompileHelpers)

# ---------------------------------------------------------------------------
# cross_check_cxx_flag
#
# Перевіряє, чи підтримує компілятор прапор, і додає його до таргету.
# При крос-компіляції використовує try_compile (не try_run).
#
# cross_check_cxx_flag(TARGET <target> FLAG <flag> [REQUIRED])
# ---------------------------------------------------------------------------
include(CheckCXXCompilerFlag)

function(cross_check_cxx_flag)
    cmake_parse_arguments(_ARG "REQUIRED" "TARGET;FLAG" "" ${ARGN})

    if(NOT _ARG_TARGET OR NOT _ARG_FLAG)
        message(FATAL_ERROR "[cross_check_cxx_flag] TARGET та FLAG обов'язкові")
    endif()

    # Перетворюємо прапор на ім'я змінної (напр. -march=armv8 → HAVE_CXX_FLAG_march_armv8)
    string(REGEX REPLACE "[^a-zA-Z0-9_]" "_" _VAR_NAME "HAVE_CXX_FLAG_${_ARG_FLAG}")

    check_cxx_compiler_flag("${_ARG_FLAG}" "${_VAR_NAME}")

    if(${_VAR_NAME})
        target_compile_options("${_ARG_TARGET}" PRIVATE "${_ARG_FLAG}")
    elseif(_ARG_REQUIRED)
        message(FATAL_ERROR
            "[CrossCompileHelpers] Обов'язковий прапор '${_ARG_FLAG}' "
            "не підтримується компілятором ${CMAKE_CXX_COMPILER}")
    else()
        message(STATUS
            "[CrossCompileHelpers] Прапор '${_ARG_FLAG}' не підтримується, пропущено")
    endif()
endfunction()

# ---------------------------------------------------------------------------
# cross_feature_check
#
# Перевіряє наявність C++ фічі через try_compile.
# При крос-компіляції НІКОЛИ не використовує try_run.
# Результат кешується у змінній HAVE_<FEATURE>.
#
# cross_feature_check(
#     FEATURE  <назва фічі>    # ім'я для кешованої змінної HAVE_<FEATURE>
#     CODE     <код>           # C++ код для перевірки (повна функція main)
#     [COMPILE_FLAGS <flags>]  # додаткові прапори компілятора
# )
# ---------------------------------------------------------------------------
function(cross_feature_check)
    cmake_parse_arguments(_ARG "" "FEATURE;CODE" "COMPILE_FLAGS" ${ARGN})

    if(NOT _ARG_FEATURE OR NOT _ARG_CODE)
        message(FATAL_ERROR "[cross_feature_check] FEATURE та CODE обов'язкові")
    endif()

    set(_CACHE_VAR "HAVE_${_ARG_FEATURE}")

    if(DEFINED "${_CACHE_VAR}")
        return()  # вже перевірено
    endif()

    set(_SRC_FILE "${CMAKE_BINARY_DIR}/CMakeTmp/check_${_ARG_FEATURE}.cpp")
    file(WRITE "${_SRC_FILE}" "${_ARG_CODE}")

    try_compile(_RESULT
        "${CMAKE_BINARY_DIR}/CMakeTmp"
        SOURCES "${_SRC_FILE}"
        COMPILE_DEFINITIONS ${_ARG_COMPILE_FLAGS}
        CXX_STANDARD ${CMAKE_CXX_STANDARD}
    )

    set("${_CACHE_VAR}" "${_RESULT}" CACHE BOOL
        "Результат перевірки фічі ${_ARG_FEATURE}" FORCE)

    if(_RESULT)
        message(STATUS "[cross_feature_check] ${_ARG_FEATURE}: знайдено")
    else()
        message(STATUS "[cross_feature_check] ${_ARG_FEATURE}: НЕ знайдено")
    endif()
endfunction()

# ---------------------------------------------------------------------------
# cross_detect_platform
#
# Визначає цільову платформу і виставляє кешові змінні:
#
#   PLATFORM_NAME          — рядок: "rpi-cross" | "rpi-native" | "yocto-cross"
#                                   | "native-arm" | "x86_64" | "native-<proc>"
#   PLATFORM_CROSS_COMPILE — BOOL: крос-компіляція (хост ≠ ціль)
#   PLATFORM_RPI           — BOOL: ціль Raspberry Pi (крос або нативна збірка на RPi)
#   PLATFORM_YOCTO         — BOOL: ціль Yocto Linux
#   PLATFORM_ARM           — BOOL: ARM-процесор (aarch64 або arm32)
#   PLATFORM_X86_64        — BOOL: x86_64-процесор
#
# Логіка визначення:
#   CMAKE_CROSSCOMPILING=TRUE + RPI_SYSROOT або toolchain=RaspberryPi* → rpi-cross
#   CMAKE_CROSSCOMPILING=TRUE + YOCTO_SDK_SYSROOT або toolchain=Yocto  → yocto-cross
#   CMAKE_CROSSCOMPILING=FALSE + aarch64/arm + /proc/device-tree/model  → rpi-native або native-arm
#   CMAKE_CROSSCOMPILING=FALSE + x86_64                                 → x86_64
#
# Використання:
#   cross_detect_platform()
#   if(PLATFORM_RPI) ... endif()
# ---------------------------------------------------------------------------
function(cross_detect_platform)
    set(_cross FALSE)
    set(_rpi   FALSE)
    set(_yocto FALSE)
    set(_arm   FALSE)
    set(_x86   FALSE)
    set(_name  "unknown")

    if(CMAKE_CROSSCOMPILING)
        set(_cross TRUE)
        if(DEFINED RPI_SYSROOT OR CMAKE_TOOLCHAIN_FILE MATCHES "RaspberryPi")
            set(_rpi  TRUE)
            set(_arm  TRUE)
            set(_name "rpi-cross")
        elseif(DEFINED YOCTO_SDK_SYSROOT OR CMAKE_TOOLCHAIN_FILE MATCHES "Yocto")
            set(_yocto TRUE)
            set(_name  "yocto-cross")
        else()
            set(_name "cross-${CMAKE_SYSTEM_PROCESSOR}")
        endif()
    else()
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|armv[6-8]|^arm")
            set(_arm TRUE)
            set(_name "native-arm")
            if(EXISTS "/proc/device-tree/model")
                file(READ "/proc/device-tree/model" _model)
                if(_model MATCHES "Raspberry Pi")
                    set(_rpi  TRUE)
                    set(_name "rpi-native")
                endif()
            endif()
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
            set(_x86  TRUE)
            set(_name "x86_64")
        else()
            set(_name "native-${CMAKE_SYSTEM_PROCESSOR}")
        endif()
    endif()

    set(PLATFORM_NAME          "${_name}"  CACHE STRING "Назва платформи" FORCE)
    set(PLATFORM_CROSS_COMPILE  ${_cross}  CACHE BOOL "Крос-компіляція (хост ≠ ціль)" FORCE)
    set(PLATFORM_RPI            ${_rpi}    CACHE BOOL "Ціль — Raspberry Pi" FORCE)
    set(PLATFORM_YOCTO          ${_yocto}  CACHE BOOL "Ціль — Yocto Linux" FORCE)
    set(PLATFORM_ARM            ${_arm}    CACHE BOOL "ARM-процесор (aarch64 або arm32)" FORCE)
    set(PLATFORM_X86_64         ${_x86}    CACHE BOOL "x86_64-процесор" FORCE)

    message(STATUS
        "[cross_detect_platform] ${_name}"
        " (cross=${_cross} rpi=${_rpi} yocto=${_yocto}"
        " arm=${_arm} x86_64=${_x86})")
endfunction()

# ---------------------------------------------------------------------------
# cross_get_target_info
#
# Виводить інформацію про поточну конфігурацію крос-компіляції.
# Корисно для діагностики у CI або при першому налаштуванні.
# ---------------------------------------------------------------------------
function(cross_get_target_info)
    message(STATUS "=== Cross-compile configuration ===")
    message(STATUS "  CMAKE_CROSSCOMPILING     : ${CMAKE_CROSSCOMPILING}")
    message(STATUS "  CMAKE_SYSTEM_NAME        : ${CMAKE_SYSTEM_NAME}")
    message(STATUS "  CMAKE_SYSTEM_PROCESSOR   : ${CMAKE_SYSTEM_PROCESSOR}")
    message(STATUS "  CMAKE_C_COMPILER         : ${CMAKE_C_COMPILER}")
    message(STATUS "  CMAKE_CXX_COMPILER       : ${CMAKE_CXX_COMPILER}")
    message(STATUS "  CMAKE_SYSROOT            : ${CMAKE_SYSROOT}")
    message(STATUS "  CMAKE_FIND_ROOT_PATH     : ${CMAKE_FIND_ROOT_PATH}")
    message(STATUS "  PLATFORM_NAME            : ${PLATFORM_NAME}")
    message(STATUS "  PLATFORM_CROSS_COMPILE   : ${PLATFORM_CROSS_COMPILE}")
    message(STATUS "  PLATFORM_RPI             : ${PLATFORM_RPI}")
    message(STATUS "  PLATFORM_YOCTO           : ${PLATFORM_YOCTO}")
    message(STATUS "  PLATFORM_ARM             : ${PLATFORM_ARM}")
    message(STATUS "  PLATFORM_X86_64          : ${PLATFORM_X86_64}")
    message(STATUS "===================================")
endfunction()
