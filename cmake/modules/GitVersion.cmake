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
#   TAG_PREFIX — початок імені тегу (напр. "kolay" → матчить "kolay_v1.2.3.4",
#                "kolay-1.2.3.4" тощо); версія витягується regex з тегу.
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

    set(_GV_RAW "")
    set(_GV_RESULT 1)

    if(DEFINED _GV_TAG_PREFIX)
        # Шукаємо теги що починаються з вказаного префіксу
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" describe --tags
                --match "${_GV_TAG_PREFIX}*"
                --abbrev=0
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE _GV_RAW
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE _GV_RESULT
        )
    else()
        # Шукаємо тег у форматі NNN.NNN.NNN.NNN (без префіксу)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" describe --tags
                --match "[0-9]*.[0-9]*.[0-9]*.[0-9]*"
                --abbrev=0
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            OUTPUT_VARIABLE _GV_RAW
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE _GV_RESULT
        )
        # Якщо не знайдено — спробуємо з префіксом "v"
        if(NOT _GV_RESULT EQUAL 0 OR _GV_RAW STREQUAL "")
            execute_process(
                COMMAND "${GIT_EXECUTABLE}" describe --tags
                    --match "v[0-9]*.[0-9]*.[0-9]*.[0-9]*"
                    --abbrev=0
                WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
                OUTPUT_VARIABLE _GV_RAW
                ERROR_QUIET
                OUTPUT_STRIP_TRAILING_WHITESPACE
                RESULT_VARIABLE _GV_RESULT
            )
        endif()
    endif()

    if(NOT _GV_RESULT EQUAL 0 OR _GV_RAW STREQUAL "")
        message(WARNING "GitVersion: тег не знайдено, використовується FALLBACK=${_GV_FALLBACK}")
        set(${OUT_VAR} "${_GV_FALLBACK}" PARENT_SCOPE)
        return()
    endif()

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
