# cmake/modules/FindPhysFS.cmake
#
# Find-модуль для PhysFS (https://github.com/icculus/physfs).
# Upstream не постачає PhysFSConfig.cmake — потрібен власний Find.
#
# Imported target:
#   PhysFS::PhysFS — SHARED IMPORTED
#
# Output variables:
#   PhysFS_FOUND, PhysFS_VERSION, PhysFS_INCLUDE_DIR, PhysFS_LIBRARY
#
# Hints:
#   PhysFS_ROOT — корінь встановлення (auto-honored CMake 3.12+)

cmake_minimum_required(VERSION 3.28)

find_path(PhysFS_INCLUDE_DIR
    NAMES physfs.h
    PATH_SUFFIXES include)

find_library(PhysFS_LIBRARY
    NAMES physfs
    PATH_SUFFIXES lib lib64)

if(PhysFS_INCLUDE_DIR AND EXISTS "${PhysFS_INCLUDE_DIR}/physfs.h")
    file(STRINGS "${PhysFS_INCLUDE_DIR}/physfs.h" _physfs_ver_lines
         REGEX "^#define[ \t]+PHYSFS_VER_(MAJOR|MINOR|PATCH)[ \t]+[0-9]+")
    foreach(_p MAJOR MINOR PATCH)
        string(REGEX REPLACE ".*PHYSFS_VER_${_p}[ \t]+([0-9]+).*" "\\1"
            _physfs_v_${_p} "${_physfs_ver_lines}")
    endforeach()
    set(PhysFS_VERSION "${_physfs_v_MAJOR}.${_physfs_v_MINOR}.${_physfs_v_PATCH}")
    unset(_physfs_ver_lines)
    unset(_physfs_v_MAJOR)
    unset(_physfs_v_MINOR)
    unset(_physfs_v_PATCH)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PhysFS
    REQUIRED_VARS PhysFS_LIBRARY PhysFS_INCLUDE_DIR
    VERSION_VAR PhysFS_VERSION)

if(PhysFS_FOUND AND NOT TARGET PhysFS::PhysFS)
    add_library(PhysFS::PhysFS SHARED IMPORTED)
    set_target_properties(PhysFS::PhysFS PROPERTIES
        IMPORTED_LOCATION "${PhysFS_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${PhysFS_INCLUDE_DIR}")
endif()

mark_as_advanced(PhysFS_INCLUDE_DIR PhysFS_LIBRARY)
