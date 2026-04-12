# cmake/modules/Sanitizers.cmake
#
# Функція target_enable_sanitizers() — підключає санітайзери до таргету.
#
# ВАЖЛИВО: санітайзери не підтримуються при крос-компіляції з sysroot.
# Використовуйте їх лише для нативної збірки або збірки з QEMU.
#
# Використання:
#   include(Sanitizers)
#   target_enable_sanitizers(my_target
#       ASAN    # AddressSanitizer (memory errors)
#       UBSAN   # UndefinedBehaviorSanitizer
#       TSAN    # ThreadSanitizer (не сумісний з ASAN)
#       LSAN    # LeakSanitizer (вбудований в ASAN на Linux)
#   )
#
# Глобальна опція для вимкнення:
#   cmake ... -DSANITIZERS_ENABLED=OFF

option(SANITIZERS_ENABLED "Дозволити санітайзери" ON)

function(target_enable_sanitizers TARGET)
    if(NOT SANITIZERS_ENABLED)
        return()
    endif()

    # Санітайзери недоступні на MSVC у повному обсязі
    if(MSVC)
        message(WARNING "[Sanitizers] MSVC: підтримується лише /fsanitize=address")
        target_compile_options("${TARGET}" PRIVATE /fsanitize=address)
        return()
    endif()

    # При крос-компіляції попереджаємо, але не блокуємо
    if(CMAKE_CROSSCOMPILING)
        message(WARNING
            "[Sanitizers] Крос-компіляція: санітайзери можуть не запуститись "
            "на цільовій платформі без відповідних runtime-бібліотек.")
    endif()

    set(_ASAN  OFF)
    set(_UBSAN OFF)
    set(_TSAN  OFF)
    set(_LSAN  OFF)

    foreach(_SAN IN LISTS ARGN)
        if(_SAN STREQUAL "ASAN")
            set(_ASAN ON)
        elseif(_SAN STREQUAL "UBSAN")
            set(_UBSAN ON)
        elseif(_SAN STREQUAL "TSAN")
            set(_TSAN ON)
        elseif(_SAN STREQUAL "LSAN")
            set(_LSAN ON)
        else()
            message(WARNING "[Sanitizers] Невідомий санітайзер: '${_SAN}'")
        endif()
    endforeach()

    # TSAN та ASAN несумісні
    if(_TSAN AND (_ASAN OR _LSAN))
        message(FATAL_ERROR
            "[Sanitizers] TSAN несумісний з ASAN/LSAN. "
            "Використовуйте окремі build директорії.")
    endif()

    set(_SAN_FLAGS "")
    set(_SAN_LINK_FLAGS "")

    if(_ASAN)
        list(APPEND _SAN_FLAGS    -fsanitize=address -fno-omit-frame-pointer)
        list(APPEND _SAN_LINK_FLAGS -fsanitize=address)
    endif()

    if(_UBSAN)
        list(APPEND _SAN_FLAGS
            -fsanitize=undefined
            -fsanitize=float-divide-by-zero
            -fsanitize=integer-divide-by-zero
            -fno-sanitize-recover=undefined)
        list(APPEND _SAN_LINK_FLAGS -fsanitize=undefined)
    endif()

    if(_TSAN)
        list(APPEND _SAN_FLAGS    -fsanitize=thread -fno-omit-frame-pointer)
        list(APPEND _SAN_LINK_FLAGS -fsanitize=thread)
    endif()

    if(_LSAN AND NOT _ASAN)
        # LSAN вбудований в ASAN; окремо — тільки якщо без ASAN
        list(APPEND _SAN_FLAGS    -fsanitize=leak)
        list(APPEND _SAN_LINK_FLAGS -fsanitize=leak)
    endif()

    if(_SAN_FLAGS)
        target_compile_options("${TARGET}" PRIVATE ${_SAN_FLAGS})
        target_link_options(   "${TARGET}" PRIVATE ${_SAN_LINK_FLAGS})

        # Необхідно для читабельних stack traces
        target_compile_options("${TARGET}" PRIVATE -g)
    endif()
endfunction()
