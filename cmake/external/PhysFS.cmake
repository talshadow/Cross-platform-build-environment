# cmake/external/PhysFS.cmake
#
# PhysFS — портабельна абстракція файлової системи для ігор та застосунків.
# Надає уніфікований доступ до архівів ZIP, 7z, ISO та інших як до файлової системи.
# https://github.com/icculus/physfs
#
# Provides imported target:
#   PhysFS::PhysFS  — SHARED IMPORTED
#
# Опції:
#   USE_SYSTEM_PHYSFS  — ON: find_package / OFF (default): ExternalProject
#
# Кеш-змінні:
#   PHYSFS_VERSION, PHYSFS_GIT_REPO

option(USE_SYSTEM_PHYSFS
    "Використовувати системну PhysFS замість збірки з джерел"
    OFF)

set(PHYSFS_VERSION "release-3.2.0"
    CACHE STRING "Версія PhysFS для збірки з джерел")

set(PHYSFS_GIT_REPO
    "https://github.com/icculus/physfs.git"
    CACHE STRING "Git репозиторій PhysFS")

# ---------------------------------------------------------------------------

ep_resolve_prefix(_physfs_prefix "lib/libphysfs.so")
set(_physfs_lib "${_physfs_prefix}/lib/libphysfs.so")
set(_physfs_inc "${_physfs_prefix}/include")

if(USE_SYSTEM_PHYSFS)
    # ── Системна бібліотека ─────────────────────────────────────────────────
    find_package(PhysFS REQUIRED)
    message(STATUS "[PhysFS] Системна: PhysFS::PhysFS")

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    set(PhysFS_ROOT "${_physfs_prefix}")
    find_package(PhysFS QUIET)
    unset(PhysFS_ROOT)

    if(PhysFS_FOUND)
        message(STATUS "[PhysFS] Знайдено готову бібліотеку у ${EXTERNAL_INSTALL_PREFIX}")

    elseif(EXISTS "${_physfs_lib}")
        ep_imported_library(PhysFS::PhysFS "${_physfs_lib}" "${_physfs_inc}")
        message(STATUS "[PhysFS] Знайдено .so у ${EXTERNAL_INSTALL_PREFIX}")

    else()
        message(STATUS "[PhysFS] Буде зібрано з джерел (${PHYSFS_VERSION})")

        ep_cmake_args(_physfs_cmake_args
            -DPHYSFS_BUILD_STATIC=OFF
            -DPHYSFS_BUILD_SHARED=ON
            -DPHYSFS_BUILD_TEST=OFF
            -DPHYSFS_BUILD_DOCS=OFF
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5
        )

        ExternalProject_Add(physfs_ep
            GIT_REPOSITORY  "${PHYSFS_GIT_REPO}"
            GIT_TAG         "${PHYSFS_VERSION}"
            GIT_SHALLOW     ON
            SOURCE_DIR      "${EP_SOURCES_DIR}/physfs"
            CMAKE_ARGS      ${_physfs_cmake_args}
            BUILD_BYPRODUCTS "${_physfs_lib}"
            LOG_DOWNLOAD    ON
            LOG_BUILD       ON
            LOG_INSTALL     ON
        )

        ep_imported_library_from_ep(
            PhysFS::PhysFS physfs_ep "${_physfs_lib}" "${_physfs_inc}")
        ep_track_cmake_file(physfs_ep "${CMAKE_CURRENT_LIST_FILE}")
    endif()
endif()

unset(_physfs_lib)
unset(_physfs_inc)
