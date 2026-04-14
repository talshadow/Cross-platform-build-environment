# cmake/external/PhySysCpp.cmake
#
# physfs-hpp — header-only C++ обгортка для PhysicsFS.
# Надає RAII-класи та ітератори поверх C API PhysicsFS.
# https://github.com/Lectem/physfs-hpp
#
# Provides imported target:
#   physfs-hpp::physfs-hpp  — INTERFACE IMPORTED (header-only)
#
# Залежності:
#   - PhysicsFS::PhysicsFS (physfs_ep)
#
# Опції:
#   USE_SYSTEM_PHYSYSCPP  — ON: find_package / OFF (default): ExternalProject
#
# Кеш-змінні:
#   PHYSYSCPP_VERSION, PHYSYSCPP_URL, PHYSYSCPP_URL_HASH

option(USE_SYSTEM_PHYSYSCPP
    "Використовувати системну physfs-hpp замість збірки з джерел"
    OFF)

set(PHYSYSCPP_VERSION "v0.7.0"
    CACHE STRING "Версія physfs-hpp для збірки з джерел")

set(PHYSYSCPP_URL
    "https://github.com/Lectem/physfs-hpp/archive/refs/tags/${PHYSYSCPP_VERSION}.tar.gz"
    CACHE STRING "URL архіву physfs-hpp")

set(PHYSYSCPP_URL_HASH ""
    CACHE STRING "SHA256 хеш архіву physfs-hpp (порожньо = не перевіряти)")

# ---------------------------------------------------------------------------

set(_physfscpp_inc "${EXTERNAL_INSTALL_PREFIX}/include")

if(USE_SYSTEM_PHYSYSCPP)
    # ── Системна бібліотека ─────────────────────────────────────────────────
    find_package(physfs-hpp REQUIRED
        HINTS "${CMAKE_SYSROOT}/usr" "${CMAKE_SYSROOT}/usr/local")
    message(STATUS "[PhysFSCpp] Системна: physfs-hpp::physfs-hpp")

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    find_package(physfs-hpp QUIET
        HINTS "${EXTERNAL_INSTALL_PREFIX}"
        NO_DEFAULT_PATH)

    if(physfs-hpp_FOUND)
        message(STATUS "[PhysFSCpp] Знайдено готові заголовки у ${EXTERNAL_INSTALL_PREFIX}")

    elseif(EXISTS "${_physfscpp_inc}/physfs.hpp")
        ep_imported_interface(physfs-hpp::physfs-hpp "${_physfscpp_inc}")
        message(STATUS "[PhysFSCpp] Знайдено заголовки у ${EXTERNAL_INSTALL_PREFIX}")

    else()
        message(STATUS "[PhysFSCpp] Буде встановлено з джерел (${PHYSYSCPP_VERSION})")

        set(_hash_arg "")
        if(PHYSYSCPP_URL_HASH)
            set(_hash_arg URL_HASH "SHA256=${PHYSYSCPP_URL_HASH}")
        endif()

        # physfs-hpp потребує PhysicsFS для свого CMake (знаходить headers)
        _ep_collect_deps(_physfscpp_ep_deps physfs_ep)

        ep_cmake_args(_physfscpp_cmake_args
            -DPHYSFS_LOCATION=${EXTERNAL_INSTALL_PREFIX}
            -DPhysicsFS_ROOT=${EXTERNAL_INSTALL_PREFIX}
            -DPHYSFSPP_BUILD_TESTS=OFF
        )

        ExternalProject_Add(physfscpp_ep
            URL             "${PHYSYSCPP_URL}"
            ${_hash_arg}
            DOWNLOAD_DIR    "${EP_SOURCES_DIR}/physfscpp"
            CMAKE_ARGS      ${_physfscpp_cmake_args}
            DEPENDS         ${_physfscpp_ep_deps}
            BUILD_BYPRODUCTS "${_physfscpp_inc}/physfs.hpp"
            LOG_DOWNLOAD    ON
            LOG_BUILD       ON
            LOG_INSTALL     ON
        )

        ep_imported_interface_from_ep(
            physfs-hpp::physfs-hpp physfscpp_ep "${_physfscpp_inc}")

        unset(_physfscpp_ep_deps)
    endif()
endif()

unset(_physfscpp_inc)
