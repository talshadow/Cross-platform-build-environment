# cmake/install_project.cmake
#
# CMake -P скрипт кастомної інсталяції головного виконуваного файлу.
# Аналізує EP/toolchain залежності через ep_check_binary_deps, копіює
# артефакти за GNUInstallDirs та, опційно, стрипує debug-інформацію.
#
# Виклик:
#   cmake
#     -DBINARY_FILE=<path>
#     -DINSTALL_PREFIX=<path>
#     -DEXTERNAL_INSTALL_PREFIX=<path>
#     -DCMAKE_MODULE_PATH=<path>
#     -DCMAKE_C_COMPILER=<path>          # для пошуку toolchain libs
#     -DCMAKE_READELF=<path>             # readelf (якщо не в PATH)
#     -DCMAKE_STRIP=<path>               # strip (обов'язково якщо DO_STRIP=ON)
#     -DDO_STRIP=<ON|OFF>
#     -DINSTALL_BINDIR=<rel>             # за замовч. "bin"
#     -DINSTALL_LIBDIR=<rel>             # за замовч. "lib"
#     -P cmake/install_project.cmake

cmake_minimum_required(VERSION 3.28)

# ---------------------------------------------------------------------------
# Валідація обов'язкових параметрів
# ---------------------------------------------------------------------------
foreach(_req BINARY_FILE INSTALL_PREFIX EXTERNAL_INSTALL_PREFIX CMAKE_MODULE_PATH)
    if(NOT DEFINED ${_req} OR "${${_req}}" STREQUAL "")
        message(FATAL_ERROR "[install_project] Не передано обов'язковий параметр: -D${_req}=...")
    endif()
endforeach()

if(NOT EXISTS "${BINARY_FILE}")
    message(FATAL_ERROR "[install_project] Виконуваний файл не знайдено: ${BINARY_FILE}")
endif()

# Директорії за GNUInstallDirs (bin/lib за замовч.)
if(NOT DEFINED INSTALL_BINDIR OR INSTALL_BINDIR STREQUAL "")
    set(INSTALL_BINDIR "bin")
endif()
if(NOT DEFINED INSTALL_LIBDIR OR INSTALL_LIBDIR STREQUAL "")
    set(INSTALL_LIBDIR "lib")
endif()

set(_bin_dir "${INSTALL_PREFIX}/${INSTALL_BINDIR}")
set(_lib_dir "${INSTALL_PREFIX}/${INSTALL_LIBDIR}")

# ---------------------------------------------------------------------------
# Збір залежностей через ep_check_binary_deps
# ---------------------------------------------------------------------------
include(BinaryDeps)

message(STATUS "[install_project] Аналіз залежностей: ${BINARY_FILE}")
ep_check_binary_deps("${BINARY_FILE}" _deploy_libs)

list(LENGTH _deploy_libs _n_libs)

# ---------------------------------------------------------------------------
# Копіювання артефактів
# ---------------------------------------------------------------------------
file(MAKE_DIRECTORY "${_bin_dir}" "${_lib_dir}")

get_filename_component(_binary_name "${BINARY_FILE}" NAME)

# -- Виконуваний файл
message(STATUS "[install_project] bin/ ← ${_binary_name}")
file(COPY "${BINARY_FILE}" DESTINATION "${_bin_dir}")
file(CHMOD "${_bin_dir}/${_binary_name}"
    FILE_PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)

# -- EP + toolchain бібліотеки
if(_n_libs GREATER 0)
    message(STATUS "[install_project] lib/ ← ${_n_libs} бібліотек(и)")
    foreach(_lib IN LISTS _deploy_libs)
        file(INSTALL "${_lib}"
            DESTINATION "${_lib_dir}"
            TYPE SHARED_LIBRARY
            FOLLOW_SYMLINK_CHAIN
        )
    endforeach()
else()
    message(STATUS "[install_project] Зовнішніх бібліотек не знайдено")
endif()

# ---------------------------------------------------------------------------
# Стрипування (DO_STRIP=ON)
# ---------------------------------------------------------------------------
if(DO_STRIP)
    if(NOT CMAKE_STRIP)
        message(WARNING "[install_project] DO_STRIP=ON, але CMAKE_STRIP не передано — пропускаємо")
    else()
        message(STATUS "[install_project] Стрипування (${CMAKE_STRIP})")

        # Виконуваний: --strip-all (видалити всі символи)
        set(_installed_bin "${_bin_dir}/${_binary_name}")
        execute_process(
            COMMAND "${CMAKE_STRIP}" --strip-all "${_installed_bin}"
            RESULT_VARIABLE _res
        )
        if(NOT _res EQUAL 0)
            message(WARNING "[install_project] strip --strip-all завершився з кодом ${_res}: ${_installed_bin}")
        endif()

        # Shared libs: --strip-debug (зберегти таблицю символів для dlopen)
        file(GLOB_RECURSE _installed_libs
            LIST_DIRECTORIES false
            "${_lib_dir}/*.so*"
        )
        foreach(_lib IN LISTS _installed_libs)
            if(NOT IS_SYMLINK "${_lib}")
                execute_process(
                    COMMAND "${CMAKE_STRIP}" --strip-debug "${_lib}"
                    RESULT_VARIABLE _res
                )
                if(NOT _res EQUAL 0)
                    message(WARNING "[install_project] strip --strip-debug завершився з кодом ${_res}: ${_lib}")
                endif()
            endif()
        endforeach()

        message(STATUS "[install_project] Стрипування завершено")
    endif()
endif()

# ---------------------------------------------------------------------------
# Підсумок
# ---------------------------------------------------------------------------
message(STATUS "")
message(STATUS "[install_project] ─────────────────────────────────────────")
message(STATUS "[install_project] Інсталяція завершена:")
message(STATUS "[install_project]   Префікс:       ${INSTALL_PREFIX}")
message(STATUS "[install_project]   Виконуваний:   ${INSTALL_BINDIR}/${_binary_name}")
message(STATUS "[install_project]   Бібліотеки:    ${_n_libs} у ${INSTALL_LIBDIR}/")
if(DO_STRIP)
    message(STATUS "[install_project]   Стрипований:   YES (--strip-all bin, --strip-debug libs)")
endif()
message(STATUS "")
