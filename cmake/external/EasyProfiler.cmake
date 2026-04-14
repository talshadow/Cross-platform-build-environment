# cmake/external/EasyProfiler.cmake
#
# easy_profiler — легкий інструментований C++ профілювальник.
# Надає макроси для вимірювання часу блоків коду та GUI-переглядач.
# https://github.com/yse/easy_profiler
#
# Provides imported target:
#   easy_profiler::easy_profiler  — SHARED IMPORTED
#
# Опції:
#   USE_SYSTEM_EASYPROFILER  — ON: find_package / OFF (default): ExternalProject
#
# Кеш-змінні:
#   EASYPROFILER_VERSION, EASYPROFILER_URL, EASYPROFILER_URL_HASH

option(USE_SYSTEM_EASYPROFILER
    "Використовувати системну easy_profiler замість збірки з джерел"
    OFF)

set(EASYPROFILER_VERSION "v2.1.0"
    CACHE STRING "Версія easy_profiler для збірки з джерел")

set(EASYPROFILER_URL
    "https://github.com/yse/easy_profiler/archive/refs/tags/${EASYPROFILER_VERSION}.tar.gz"
    CACHE STRING "URL архіву easy_profiler")

set(EASYPROFILER_URL_HASH ""
    CACHE STRING "SHA256 хеш архіву easy_profiler (порожньо = не перевіряти)")

# ---------------------------------------------------------------------------

set(_ep_lib "${EXTERNAL_INSTALL_PREFIX}/lib/libeasy_profiler.so")
set(_ep_inc "${EXTERNAL_INSTALL_PREFIX}/include")

if(USE_SYSTEM_EASYPROFILER)
    # ── Системна бібліотека ─────────────────────────────────────────────────
    find_package(easy_profiler REQUIRED)
    message(STATUS "[EasyProfiler] Системна: easy_profiler::easy_profiler")

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    find_package(easy_profiler QUIET
        HINTS "${EXTERNAL_INSTALL_PREFIX}"
        NO_DEFAULT_PATH)

    if(easy_profiler_FOUND)
        message(STATUS "[EasyProfiler] Знайдено готову бібліотеку у ${EXTERNAL_INSTALL_PREFIX}")

    else()
        message(STATUS "[EasyProfiler] Буде зібрано з джерел (${EASYPROFILER_VERSION})")

        set(_hash_arg "")
        if(EASYPROFILER_URL_HASH)
            set(_hash_arg URL_HASH "SHA256=${EASYPROFILER_URL_HASH}")
        endif()

        ep_cmake_args(_ep_cmake_args
            -DEASY_PROFILER_NO_GUI=ON
            -DEASY_PROFILER_NO_SAMPLES=ON
        )

        ExternalProject_Add(easyprofiler_ep
            URL             "${EASYPROFILER_URL}"
            ${_hash_arg}
            DOWNLOAD_DIR    "${EP_SOURCES_DIR}/easyprofiler"
            CMAKE_ARGS      ${_ep_cmake_args}
            BUILD_BYPRODUCTS "${_ep_lib}"
            LOG_DOWNLOAD    ON
            LOG_BUILD       ON
            LOG_INSTALL     ON
        )

        ep_imported_library_from_ep(
            easy_profiler::easy_profiler easyprofiler_ep "${_ep_lib}" "${_ep_inc}")
    endif()
endif()

unset(_ep_lib)
unset(_ep_inc)
