# cmake/toolchains/common.cmake
#
# Спільні утиліти для всіх toolchain файлів.
# Підключається через include() на початку кожного toolchain.
#
# Використання:
#   include("${CMAKE_CURRENT_LIST_DIR}/common.cmake")

cmake_minimum_required(VERSION 3.28)

# ---------------------------------------------------------------------------
# cross_toolchain_find_compiler
#
# Шукає компілятор за префіксом. При невдачі видає зрозуміле повідомлення
# з інструкцією з встановлення.
#
# Аргументи:
#   PREFIX   — префікс тулчейну (напр. aarch64-linux-gnu)
#   INSTALL  — пакет для встановлення (напр. gcc-aarch64-linux-gnu)
# ---------------------------------------------------------------------------
macro(cross_toolchain_find_compiler PREFIX INSTALL)
    find_program(_CC  "${PREFIX}-gcc"  HINTS ENV PATH)
    find_program(_CXX "${PREFIX}-g++" HINTS ENV PATH)

    if(NOT _CC OR NOT _CXX)
        message(FATAL_ERROR
            "\n[Toolchain] Компілятор '${PREFIX}-gcc' не знайдено.\n"
            "Встановіть пакет командою:\n"
            "  sudo apt install ${INSTALL}\n"
            "Або вкажіть власний префікс через -D${_TOOLCHAIN_PREFIX_VAR}=<prefix>\n")
    endif()

    set(CMAKE_C_COMPILER   "${_CC}"  CACHE FILEPATH "C compiler"   FORCE)
    set(CMAKE_CXX_COMPILER "${_CXX}" CACHE FILEPATH "C++ compiler" FORCE)

    find_program(_AR     "${PREFIX}-ar")
    find_program(_STRIP  "${PREFIX}-strip")
    find_program(_RANLIB "${PREFIX}-ranlib")

    if(_AR)
        set(CMAKE_AR     "${_AR}"     CACHE FILEPATH "Archiver" FORCE)
    endif()
    if(_STRIP)
        set(CMAKE_STRIP  "${_STRIP}"  CACHE FILEPATH "Strip"    FORCE)
    endif()
    if(_RANLIB)
        set(CMAKE_RANLIB "${_RANLIB}" CACHE FILEPATH "Ranlib"   FORCE)
    endif()

    unset(_CC)
    unset(_CXX)
    unset(_AR)
    unset(_STRIP)
    unset(_RANLIB)
endmacro()

# ---------------------------------------------------------------------------
# cross_toolchain_setup_sysroot
#
# Налаштовує sysroot та режими пошуку бібліотек.
# Викликати після встановлення CMAKE_SYSROOT.
# ---------------------------------------------------------------------------
macro(cross_toolchain_setup_sysroot)
    # Програми (cmake, python тощо) завжди беремо з хост-системи
    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
    # Бібліотеки, заголовки та пакети — тільки з sysroot
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
endmacro()

# ---------------------------------------------------------------------------
# cross_toolchain_no_sysroot
#
# Режим без sysroot: нативна збірка або збірка без прив'язки до конкретного
# образу цільової системи.
# ---------------------------------------------------------------------------
macro(cross_toolchain_no_sysroot)
    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
    set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
endmacro()
