# cmake/external/patches/airsim-configure.cmake
#
# Патчить два файли AirSim після клонування.
# Запускається через: cmake -P airsim-configure.cmake
#   -DAIRSIM_SOURCE_DIR=<шлях до git-клону AirSim>
#   -DEIGEN_INC=<шлях до include/eigen3 в EXTERNAL_INSTALL_PREFIX>
#
# Обидва патчі ідемпотентні: перевіряють чи патч вже застосовано.

cmake_minimum_required(VERSION 3.16)

# ── Патч 1: eigen3 include path у CommonSetup.cmake ────────────────────────
# AirSim хардкодить шлях до bundled AirLib/deps/eigen3 якого немає в репо.
# Замінюємо include_directories(…deps/eigen3…) на наш EXTERNAL_INSTALL_PREFIX.
set(_f "${AIRSIM_SOURCE_DIR}/cmake/cmake-modules/CommonSetup.cmake")
file(READ "${_f}" _content)
if(_content MATCHES "deps/eigen3")
    string(REGEX REPLACE
        "include_directories\\([^)]*deps/eigen3[^)]*\\)"
        "include_directories(${EIGEN_INC})"
        _content "${_content}")
    file(WRITE "${_f}" "${_content}")
    message(STATUS "[airsim-patch] CommonSetup.cmake: eigen3 → ${EIGEN_INC}")
else()
    message(STATUS "[airsim-patch] CommonSetup.cmake: eigen3 вже пропатчено")
endif()
unset(_f)
unset(_content)

# ── Патч 2: AirLib STATIC → SHARED ─────────────────────────────────────────
# AirLib хардкодить STATIC. MavLinkCom/rpclib лишаються STATIC і
# компілюються з -fPIC (CommonSetup встановлює CMAKE_POSITION_INDEPENDENT_CODE),
# тому лінкуються у libAirLib.so без проблем.
set(_f "${AIRSIM_SOURCE_DIR}/cmake/AirLib/CMakeLists.txt")
file(READ "${_f}" _content)
if(_content MATCHES "add_library\\([^)]+STATIC")
    string(REPLACE
        "add_library(\${PROJECT_NAME} STATIC"
        "add_library(\${PROJECT_NAME} SHARED"
        _content "${_content}")
    file(WRITE "${_f}" "${_content}")
    message(STATUS "[airsim-patch] AirLib/CMakeLists.txt: STATIC → SHARED")
else()
    message(STATUS "[airsim-patch] AirLib/CMakeLists.txt: SHARED вже встановлено")
endif()
unset(_f)
unset(_content)
