# cmake/external/PhysFSCpp.cmake
#
# PhysFSCpp — header-only C++ обгортка для PhysFS (upstream: physfs-hpp).
# Надає RAII-класи та ітератори поверх C API PhysFS.
# https://github.com/Lectem/physfs-hpp
#
# Provides imported target:
#   PhysFSCpp::PhysFSCpp  — INTERFACE IMPORTED (ALIAS на physfs-hpp::physfs-hpp)
#
# Залежності:
#   - PhysFS::PhysFS (physfs_ep)
#
# Опції:
#   USE_SYSTEM_PHYSFSCPP  — ON: find_package / OFF (default): ExternalProject
#
# Кеш-змінні:
#   PHYSFSCPP_VERSION, PHYSFSCPP_GIT_REPO

option(USE_SYSTEM_PHYSFSCPP
    "Використовувати системну physfs-hpp замість збірки з джерел"
    OFF)

set(PHYSFSCPP_VERSION "master"
    CACHE STRING "Версія physfs-hpp для збірки з джерел")

set(PHYSFSCPP_GIT_REPO
    "https://github.com/Ybalrid/physfs-hpp.git"
    CACHE STRING "Git репозиторій physfs-hpp")

# ---------------------------------------------------------------------------

ep_resolve_prefix(_physfscpp_prefix "include/physfs.hpp")
set(_physfscpp_inc "${_physfscpp_prefix}/include")

if(USE_SYSTEM_PHYSFSCPP)
    # ── Системна бібліотека ─────────────────────────────────────────────────
    find_package(physfs-hpp REQUIRED
        HINTS "${CMAKE_SYSROOT}/usr" "${CMAKE_SYSROOT}/usr/local")
    message(STATUS "[PhysFSCpp] Системна: physfs-hpp::physfs-hpp")
    if(NOT TARGET PhysFSCpp::PhysFSCpp)
        add_library(PhysFSCpp::PhysFSCpp ALIAS physfs-hpp::physfs-hpp)
    endif()

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    find_package(physfs-hpp QUIET
        HINTS ${_EP_HINT_DIRS}
        NO_DEFAULT_PATH)

    if(physfs-hpp_FOUND)
        message(STATUS "[PhysFSCpp] Знайдено готові заголовки у ${EXTERNAL_INSTALL_PREFIX}")
        if(NOT TARGET PhysFSCpp::PhysFSCpp)
            add_library(PhysFSCpp::PhysFSCpp ALIAS physfs-hpp::physfs-hpp)
        endif()

    elseif(EXISTS "${_physfscpp_inc}/physfs.hpp")
        ep_imported_interface(physfs-hpp::physfs-hpp "${_physfscpp_inc}")
        message(STATUS "[PhysFSCpp] Знайдено заголовки у ${EXTERNAL_INSTALL_PREFIX}")
        if(NOT TARGET PhysFSCpp::PhysFSCpp)
            add_library(PhysFSCpp::PhysFSCpp ALIAS physfs-hpp::physfs-hpp)
        endif()

    else()
        message(STATUS "[PhysFSCpp] Буде встановлено з джерел (${PHYSFSCPP_VERSION})")

        # physfs-hpp — header-only, cmake не потрібен.
        # Просто копіюємо physfs.hpp після клонування.
        ExternalProject_Add(physfscpp_ep
            GIT_REPOSITORY    "${PHYSFSCPP_GIT_REPO}"
            GIT_TAG           "${PHYSFSCPP_VERSION}"
            GIT_SHALLOW       ON
            SOURCE_DIR        "${EP_SOURCES_DIR}/physfscpp"
            PATCH_COMMAND
                sh -c "patch -p1 -N -i '${CMAKE_CURRENT_LIST_DIR}/patches/physfscpp-return-values.patch' || true"
            CONFIGURE_COMMAND ""
            BUILD_COMMAND     ""
            INSTALL_COMMAND
                ${CMAKE_COMMAND} -E copy
                    "${EP_SOURCES_DIR}/physfscpp/include/physfs.hpp"
                    "${EXTERNAL_INSTALL_PREFIX}/include/physfs.hpp"
            BUILD_BYPRODUCTS  "${_physfscpp_inc}/physfs.hpp"
            LOG_DOWNLOAD      ON
            LOG_INSTALL       ON
        )

        ep_imported_interface_from_ep(
            physfs-hpp::physfs-hpp physfscpp_ep "${_physfscpp_inc}")
        ep_track_cmake_file(physfscpp_ep "${CMAKE_CURRENT_LIST_FILE}")
        if(NOT TARGET PhysFSCpp::PhysFSCpp)
            add_library(PhysFSCpp::PhysFSCpp ALIAS physfs-hpp::physfs-hpp)
        endif()
    endif()
endif()

unset(_physfscpp_inc)
