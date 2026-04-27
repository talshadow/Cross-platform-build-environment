# cmake/modules/GitVersion.cmake
#
# Функції для отримання версії та хешу коміту з git.
#
# Використання:
#   include(GitVersion)
#   git_get_version(MY_VERSION)                       # → "1.2.3.4" або "0.0.0.0"
#   git_get_version(MY_VERSION TAG_PREFIX "kolay")    # тільки теги що починаються з "kolay"
#   git_get_commit_hash(MY_HASH)                      # → "a1b2c3d" або "unknown"
#
# git_get_version(<OUT_VAR> [FALLBACK <version>] [TAG_PREFIX <prefix>])
#   OUT_VAR    — змінна, куди записується версія у форматі NNN.NNN.NNN.NNN
#   FALLBACK   — версія за замовчуванням, якщо git недоступний або тег не знайдено
#                (за замовчуванням "0.0.0.0")
#   TAG_PREFIX — початок імені тегу; після префіксу обов'язковий роздільник _ або -
#                (напр. "kolay" → матчить "kolay_v1.2.3.4", "kolay-1.2.3.4",
#                але НЕ "kolayX1.2.3.4"); версія витягується regex з тегу.
#                Без TAG_PREFIX шукаються теги [0-9]*.*.*.* та v[0-9]*.*.*.*
#
# git_get_commit_hash(<OUT_VAR> [LENGTH <n>])
#   OUT_VAR — змінна, куди записується скорочений хеш останнього коміту
#   LENGTH  — кількість символів хешу (за замовчуванням 7)

# ---------------------------------------------------------------------------
function(git_get_version OUT_VAR)
    cmake_parse_arguments(_GV "" "FALLBACK;TAG_PREFIX" "" ${ARGN})

    if(NOT DEFINED _GV_FALLBACK)
        set(_GV_FALLBACK "0.0.0.0")
    endif()

    find_package(Git QUIET)

    if(NOT GIT_FOUND)
        message(WARNING "GitVersion: git не знайдено, використовується FALLBACK=${_GV_FALLBACK}")
        set(${OUT_VAR} "${_GV_FALLBACK}" PARENT_SCOPE)
        return()
    endif()

    # Примусове re-configure при зміні тегів:
    # теги зберігаються в packed-refs або в refs/tags/; відстежуємо обидва місця.
    foreach(_gv_git_file
            "${CMAKE_SOURCE_DIR}/.git/packed-refs"
            "${CMAKE_SOURCE_DIR}/.git/refs/tags")
        if(EXISTS "${_gv_git_file}")
            set_property(DIRECTORY "${CMAKE_SOURCE_DIR}" APPEND PROPERTY
                CMAKE_CONFIGURE_DEPENDS "${_gv_git_file}")
        endif()
    endforeach()

    # Формуємо glob-патерн(и) для git tag --list
    if(DEFINED _GV_TAG_PREFIX)
        # [-_] — обов'язковий роздільник після префіксу (крапка кінця префіксу)
        set(_GV_PATTERNS "${_GV_TAG_PREFIX}[-_]*")
    else()
        # Два патерни: з "v" і без — передаємо обидва одним викликом
        set(_GV_PATTERNS "[0-9]*.[0-9]*.[0-9]*.[0-9]*" "v[0-9]*.[0-9]*.[0-9]*.[0-9]*")
    endif()

    # --sort=-version:refname: сортування за спаданням версії (1.10 > 1.9 — коректно)
    # Перший рядок результату — найсвіжіший тег
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" tag --list ${_GV_PATTERNS} --sort=-version:refname
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE _GV_ALL_TAGS
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _GV_RESULT
    )

    if(NOT _GV_RESULT EQUAL 0 OR _GV_ALL_TAGS STREQUAL "")
        message(WARNING "GitVersion: тег не знайдено, використовується FALLBACK=${_GV_FALLBACK}")
        set(${OUT_VAR} "${_GV_FALLBACK}" PARENT_SCOPE)
        return()
    endif()

    # Беремо перший рядок (найсвіжіший тег за версією)
    string(REGEX MATCH "^[^\n\r]+" _GV_RAW "${_GV_ALL_TAGS}")

    # Витягуємо версію NNN.NNN.NNN.NNN з тегу (незалежно від префіксу/роздільника)
    string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" _GV_VERSION "${_GV_RAW}")

    if(_GV_VERSION STREQUAL "")
        message(WARNING "GitVersion: тег '${_GV_RAW}' не містить версії формату NNN.NNN.NNN.NNN, "
                        "використовується FALLBACK=${_GV_FALLBACK}")
        set(${OUT_VAR} "${_GV_FALLBACK}" PARENT_SCOPE)
        return()
    endif()

    set(${OUT_VAR} "${_GV_VERSION}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
function(git_get_commit_hash OUT_VAR)
    cmake_parse_arguments(_GH "" "LENGTH" "" ${ARGN})

    if(NOT DEFINED _GH_LENGTH)
        set(_GH_LENGTH 7)
    endif()

    find_package(Git QUIET)

    if(NOT GIT_FOUND)
        message(WARNING "GitVersion: git не знайдено, хеш = 'unknown'")
        set(${OUT_VAR} "unknown" PARENT_SCOPE)
        return()
    endif()

    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse "--short=${_GH_LENGTH}" HEAD
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE _GH_HASH
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _GH_RESULT
    )

    if(NOT _GH_RESULT EQUAL 0 OR _GH_HASH STREQUAL "")
        message(WARNING "GitVersion: не вдалося отримати хеш коміту, хеш = 'unknown'")
        set(${OUT_VAR} "unknown" PARENT_SCOPE)
        return()
    endif()

    set(${OUT_VAR} "${_GH_HASH}" PARENT_SCOPE)
endfunction()
