# cmake/external/BoostDI.cmake
#
# Boost.DI (boost-ext/di) — header-only бібліотека dependency injection.
# НЕ є частиною офіційного Boost — це розширення boost-ext.
# https://github.com/boost-ext/di
#
# Provides imported target:
#   boost::di  — INTERFACE IMPORTED (header-only)
#
# Опції:
#   USE_SYSTEM_BOOSTDI  — ON: find_package / OFF (default): ExternalProject
#
# Кеш-змінні:
#   BOOSTDI_VERSION, BOOSTDI_URL, BOOSTDI_URL_HASH

option(USE_SYSTEM_BOOSTDI
    "Використовувати системну Boost.DI замість збірки з джерел"
    OFF)

set(BOOSTDI_VERSION "v1.3.0"
    CACHE STRING "Версія Boost.DI (boost-ext/di) для збірки з джерел")

set(BOOSTDI_URL
    "https://github.com/boost-ext/di/archive/refs/tags/${BOOSTDI_VERSION}.tar.gz"
    CACHE STRING "URL архіву Boost.DI")

set(BOOSTDI_URL_HASH ""
    CACHE STRING "SHA256 хеш архіву Boost.DI (порожньо = не перевіряти)")

# ---------------------------------------------------------------------------

set(_boostdi_inc "${EXTERNAL_INSTALL_PREFIX}/include")

if(USE_SYSTEM_BOOSTDI)
    # ── Системна бібліотека ─────────────────────────────────────────────────
    find_package(di REQUIRED
        HINTS "${CMAKE_SYSROOT}/usr" "${CMAKE_SYSROOT}/usr/local")
    message(STATUS "[BoostDI] Системна: boost::di")

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    find_package(di QUIET
        HINTS "${EXTERNAL_INSTALL_PREFIX}"
        NO_DEFAULT_PATH)

    if(di_FOUND)
        message(STATUS "[BoostDI] Знайдено готові заголовки у ${EXTERNAL_INSTALL_PREFIX}")
        # boost::di вже створено find_package

    elseif(EXISTS "${_boostdi_inc}/boost/di.hpp")
        ep_imported_interface(boost::di "${_boostdi_inc}")
        message(STATUS "[BoostDI] Знайдено заголовки у ${EXTERNAL_INSTALL_PREFIX}")

    else()
        message(STATUS "[BoostDI] Буде встановлено з джерел (${BOOSTDI_VERSION})")

        set(_hash_arg "")
        if(BOOSTDI_URL_HASH)
            set(_hash_arg URL_HASH "SHA256=${BOOSTDI_URL_HASH}")
        endif()

        ep_cmake_args(_boostdi_cmake_args
            -DBOOST_DI_OPT_BUILD_TESTS=OFF
            -DBOOST_DI_OPT_BUILD_EXAMPLES=OFF
        )

        ExternalProject_Add(boostdi_ep
            URL             "${BOOSTDI_URL}"
            ${_hash_arg}
            DOWNLOAD_DIR    "${EP_SOURCES_DIR}/boostdi"
            CMAKE_ARGS      ${_boostdi_cmake_args}
            BUILD_BYPRODUCTS "${_boostdi_inc}/boost/di.hpp"
            LOG_DOWNLOAD    ON
            LOG_BUILD       ON
            LOG_INSTALL     ON
        )

        ep_imported_interface_from_ep(boost::di boostdi_ep "${_boostdi_inc}")
    endif()
endif()

unset(_boostdi_inc)
