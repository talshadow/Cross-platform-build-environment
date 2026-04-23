# cmake/modules/InstallHelpers.cmake
#
# project_setup_install(<target>)
#
# Налаштовує кастомну інсталяцію головного виконуваного файлу.
#
# Створює цілі:
#
#   install_<target>
#     Копіює <target> та всі EP/toolchain залежності у:
#       ${CMAKE_BINARY_DIR}/install_<BUILD_TYPE>/
#         bin/  — виконуваний файл
#         lib/  — shared libraries (EP + toolchain)
#
#   install_<target>_stripped          [тільки RelWithDebInfo]
#     Те саме, але з --strip-all (bin) та --strip-debug (libs):
#       ${CMAKE_BINARY_DIR}/install_RelWithDebInfo_stripped/
#
# Залежності та структура директорій визначаються через GNUInstallDirs.
# Аналіз бінарних залежностей виконується ep_check_binary_deps (BinaryDeps.cmake)
# у момент запуску цілі (після збірки), а не під час конфігурації.
#
# Використання:
#   # (автоматично підключається з BuildConfig.cmake)
#   project_setup_install(opencv_example)
#   # → створює: install_opencv_example, install_opencv_example_stripped (RelWithDebInfo)

include(GNUInstallDirs)

function(project_setup_install target)
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "[InstallHelpers] Target '${target}' не існує")
    endif()

    set(_script "${CMAKE_SOURCE_DIR}/cmake/install_project.cmake")
    if(NOT EXISTS "${_script}")
        message(FATAL_ERROR "[InstallHelpers] Скрипт не знайдено: ${_script}")
    endif()

    # Визначаємо тип збірки (для single-config генераторів)
    set(_build_type "${CMAKE_BUILD_TYPE}")
    if(_build_type STREQUAL "")
        set(_build_type "unknown")
    endif()

    # Аргументи, спільні для обох цілей
    # Змінні часу конфігурації запікаються у рядок; шляхи з пробілами
    # коректно передаються завдяки VERBATIM у add_custom_target.
    set(_common_defs
        "-DCMAKE_MODULE_PATH=${CMAKE_SOURCE_DIR}/cmake/modules"
        "-DEXTERNAL_INSTALL_PREFIX=${EXTERNAL_INSTALL_PREFIX}"
        "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
        "-DCMAKE_READELF=${CMAKE_READELF}"
        "-DCMAKE_STRIP=${CMAKE_STRIP}"
        "-DCMAKE_SYSROOT=${CMAKE_SYSROOT}"
        "-DINSTALL_BINDIR=${CMAKE_INSTALL_BINDIR}"
        "-DINSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}"
    )

    # ── install_<target> ─────────────────────────────────────────────────────
    set(_prefix "${CMAKE_BINARY_DIR}/install_${_build_type}")

    add_custom_target(install_${target}
        COMMAND ${CMAKE_COMMAND}
            "-DBINARY_FILE=$<TARGET_FILE:${target}>"
            "-DINSTALL_PREFIX=${_prefix}"
            "-DDO_STRIP=OFF"
            ${_common_defs}
            -P "${_script}"
        DEPENDS "${target}"
        COMMENT "Installing ${target} → install_${_build_type}/"
        VERBATIM
    )

    message(STATUS "[InstallHelpers] Ціль 'install_${target}' → ${_prefix}/")

    # ── install_<target>_stripped (тільки RelWithDebInfo) ───────────────────
    if(_build_type STREQUAL "RelWithDebInfo")
        set(_stripped_prefix "${CMAKE_BINARY_DIR}/install_RelWithDebInfo_stripped")

        add_custom_target(install_${target}_stripped
            COMMAND ${CMAKE_COMMAND}
                "-DBINARY_FILE=$<TARGET_FILE:${target}>"
                "-DINSTALL_PREFIX=${_stripped_prefix}"
                "-DDO_STRIP=ON"
                ${_common_defs}
                -P "${_script}"
            DEPENDS "${target}"
            COMMENT "Installing ${target} (stripped) → install_RelWithDebInfo_stripped/"
            VERBATIM
        )

        message(STATUS "[InstallHelpers] Ціль 'install_${target}_stripped' → ${_stripped_prefix}/")
    endif()
endfunction()
