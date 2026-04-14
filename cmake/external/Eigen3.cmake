# cmake/external/Eigen3.cmake
#
# Eigen3 — C++ бібліотека лінійної алгебри (матриці, вектори, чисельні методи).
# Бібліотека повністю header-only: немає .so, лише заголовкові файли.
# https://eigen.tuxfamily.org/
#
# Provides imported target:
#   Eigen3::Eigen  — INTERFACE IMPORTED (header-only)
#
# Опції:
#   USE_SYSTEM_EIGEN3  — ON: find_package в системі/sysroot
#                        OFF (за замовч.): зібрати через ExternalProject
#
# Кеш-змінні:
#   EIGEN3_VERSION    — версія для збірки
#   EIGEN3_URL        — URL архіву
#   EIGEN3_URL_HASH   — SHA256 хеш (порожньо = не перевіряти)

option(USE_SYSTEM_EIGEN3
    "Використовувати системний Eigen3 замість встановлення з джерел"
    OFF)

set(EIGEN3_VERSION "3.4.0"
    CACHE STRING "Версія Eigen3 для встановлення з джерел")

set(EIGEN3_URL
    "https://gitlab.com/libeigen/eigen/-/archive/${EIGEN3_VERSION}/eigen-${EIGEN3_VERSION}.tar.gz"
    CACHE STRING "URL архіву Eigen3")

set(EIGEN3_URL_HASH ""
    CACHE STRING "SHA256 хеш архіву Eigen3 (порожньо = не перевіряти)")

# ---------------------------------------------------------------------------
# Eigen встановлює заголовки у <prefix>/include/eigen3/
# Представницький файл як маркер для Ninja (BUILD_BYPRODUCTS)
set(_eigen_inc "${EXTERNAL_INSTALL_PREFIX}/include/eigen3")
set(_eigen_hdr "${_eigen_inc}/Eigen/Core")

if(USE_SYSTEM_EIGEN3)
    # ── Системна бібліотека / sysroot ───────────────────────────────────────
    find_package(Eigen3 REQUIRED)
    message(STATUS "[Eigen3] Системна: ${EIGEN3_VERSION_STRING} (include: ${EIGEN3_INCLUDE_DIRS})")

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    # Eigen встановлює Eigen3Config.cmake → find_package знайде його
    # в EXTERNAL_INSTALL_PREFIX через HINTS.
    find_package(Eigen3 QUIET
        HINTS "${EXTERNAL_INSTALL_PREFIX}"
        NO_DEFAULT_PATH)

    if(Eigen3_FOUND)
        message(STATUS "[Eigen3] Знайдено готову бібліотеку у ${EXTERNAL_INSTALL_PREFIX}")
        # Eigen3::Eigen вже створено find_package

    else()
        message(STATUS "[Eigen3] Буде встановлено з джерел (${EIGEN3_VERSION})")

        set(_eigen_hash_arg "")
        if(EIGEN3_URL_HASH)
            set(_eigen_hash_arg URL_HASH "SHA256=${EIGEN3_URL_HASH}")
        endif()

        # Eigen — header-only: CMake install копіює заголовки, нічого не компілює.
        # ep_cmake_args передає toolchain/sysroot (не потрібні для header-only,
        # але залишаємо для уніфікації). BUILD_SHARED_LIBS=ON з ep_cmake_args
        # Eigen ігнорує — це теж нешкідливо.
        ep_cmake_args(_eigen_cmake_args
            -DEIGEN_BUILD_DOC=OFF
            -DEIGEN_BUILD_TESTING=OFF
            -DEIGEN_BUILD_DEMOS=OFF
            # Вимикаємо пошук BLAS/LAPACK — вони є зовнішніми залежностями
            # яких немає в нашому EXTERNAL_INSTALL_PREFIX.
            -DEIGEN_USE_BLAS=OFF
            -DEIGEN_USE_LAPACKE=OFF
        )

        # Eigen не має залежностей від наших бібліотек
        ExternalProject_Add(eigen3_ep
            URL             "${EIGEN3_URL}"
            ${_eigen_hash_arg}
            DOWNLOAD_DIR    "${EP_SOURCES_DIR}/eigen3"
            CMAKE_ARGS      ${_eigen_cmake_args}
            # Заголовковий файл як маркер встановлення для Ninja
            BUILD_BYPRODUCTS "${_eigen_hdr}"
            LOG_DOWNLOAD    ON
            LOG_BUILD       ON
            LOG_INSTALL     ON
        )

        ep_imported_interface_from_ep(Eigen3::Eigen eigen3_ep "${_eigen_inc}")
    endif()
endif()

unset(_eigen_inc)
unset(_eigen_hdr)
