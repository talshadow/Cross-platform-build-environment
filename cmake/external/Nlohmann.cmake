# cmake/external/Nlohmann.cmake
#
# nlohmann/json — header-only JSON бібліотека для C++11 і новіших.
# https://github.com/nlohmann/json
#
# Provides imported target:
#   nlohmann_json::nlohmann_json  — INTERFACE IMPORTED (header-only)
#
# Опції:
#   USE_SYSTEM_NLOHMANN  — ON: find_package / OFF (default): ExternalProject
#
# Кеш-змінні:
#   NLOHMANN_VERSION, NLOHMANN_URL, NLOHMANN_URL_HASH

option(USE_SYSTEM_NLOHMANN
    "Використовувати системну nlohmann/json замість збірки з джерел"
    OFF)

set(NLOHMANN_VERSION "v3.11.3"
    CACHE STRING "Версія nlohmann/json для збірки з джерел")

set(NLOHMANN_URL
    "https://github.com/nlohmann/json/archive/refs/tags/${NLOHMANN_VERSION}.tar.gz"
    CACHE STRING "URL архіву nlohmann/json")

set(NLOHMANN_URL_HASH ""
    CACHE STRING "SHA256 хеш архіву nlohmann/json (порожньо = не перевіряти)")

# ---------------------------------------------------------------------------

set(_nlohmann_inc "${EXTERNAL_INSTALL_PREFIX}/include")

if(USE_SYSTEM_NLOHMANN)
    # ── Системна бібліотека ─────────────────────────────────────────────────
    find_package(nlohmann_json REQUIRED)
    message(STATUS "[Nlohmann] Системна: nlohmann_json::nlohmann_json")

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    find_package(nlohmann_json QUIET
        HINTS "${EXTERNAL_INSTALL_PREFIX}"
        NO_DEFAULT_PATH)

    if(nlohmann_json_FOUND)
        message(STATUS "[Nlohmann] Знайдено готові заголовки у ${EXTERNAL_INSTALL_PREFIX}")
        # nlohmann_json::nlohmann_json вже створено find_package

    elseif(EXISTS "${_nlohmann_inc}/nlohmann/json.hpp")
        ep_imported_interface(nlohmann_json::nlohmann_json "${_nlohmann_inc}")
        message(STATUS "[Nlohmann] Знайдено заголовки у ${EXTERNAL_INSTALL_PREFIX}")

    else()
        message(STATUS "[Nlohmann] Буде встановлено з джерел (${NLOHMANN_VERSION})")

        set(_hash_arg "")
        if(NLOHMANN_URL_HASH)
            set(_hash_arg URL_HASH "SHA256=${NLOHMANN_URL_HASH}")
        endif()

        ep_cmake_args(_nlohmann_cmake_args
            -DJSON_BuildTests=OFF
            -DJSON_Install=ON
            -DJSON_MultipleHeaders=ON
        )

        ExternalProject_Add(nlohmann_ep
            URL             "${NLOHMANN_URL}"
            ${_hash_arg}
            DOWNLOAD_DIR    "${EP_SOURCES_DIR}/nlohmann"
            CMAKE_ARGS      ${_nlohmann_cmake_args}
            BUILD_BYPRODUCTS "${_nlohmann_inc}/nlohmann/json.hpp"
            LOG_DOWNLOAD    ON
            LOG_BUILD       ON
            LOG_INSTALL     ON
        )

        ep_imported_interface_from_ep(
            nlohmann_json::nlohmann_json nlohmann_ep "${_nlohmann_inc}")
    endif()
endif()

unset(_nlohmann_inc)
