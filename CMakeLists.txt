cmake_minimum_required(VERSION 3.28)

project(cross-platform-build-environment
    VERSION     1.0.0
    DESCRIPTION "Cross-platform CMake build support for Raspberry Pi and Yocto Linux"
    LANGUAGES   C CXX
)

# ---------------------------------------------------------------------------
# Superbuild режим
# Якщо SUPERBUILD=ON — збирає всі сторонні залежності як ExternalProject,
# потім основний проєкт. return() зупиняє обробку файлу далі.
# ---------------------------------------------------------------------------
option(SUPERBUILD
    "Збирати залежності та основний проєкт через Superbuild (ExternalProject)"
    OFF)

if(SUPERBUILD)
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/SuperBuild.cmake")
    return()
endif()

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/BuildConfig.cmake")

# ---------------------------------------------------------------------------
# Цілі проєкту
# ---------------------------------------------------------------------------
add_subdirectory(src)
