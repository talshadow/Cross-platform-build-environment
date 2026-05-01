#!/usr/bin/env bash
# scripts/build-system-update-hashes.sh
#
# Обчислює SHA256 для EP-архівів і оновлює відповідні <LIB>_SHA256 змінні
# у cmake/external/Lib*.cmake.
#
# Використання:
#   ./scripts/build-system-update-hashes.sh
#   ./scripts/build-system-update-hashes.sh --dry-run   # лише вивести хеші
#   ./scripts/build-system-update-hashes.sh --lib zlib  # тільки одна бібліотека
#
# Вимоги: curl, sha256sum (GNU coreutils)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

DRY_RUN=false
FILTER_LIB=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true ;;
        --lib)      FILTER_LIB="$2"; shift ;;
        --help|-h)
            echo "Використання: $0 [--dry-run] [--lib <ім'я>]"
            echo ""
            echo "  --dry-run  Лише обчислити і вивести хеші, не записувати в файли"
            echo "  --lib      Оновити тільки вказану бібліотеку (zlib, onetbb, boost, opencv, opencv_contrib)"
            exit 0 ;;
        *) log_error "Невідомий аргумент: $1"; exit 1 ;;
    esac
    shift
done

TMPDIR_HASHES="$(mktemp -d)"
cleanup() { rm -rf "${TMPDIR_HASHES}"; }
trap cleanup EXIT

# --- Допоміжні функції -------------------------------------------------------

download_and_hash() {
    local name="$1"
    local url="$2"
    local dest="${TMPDIR_HASHES}/${name}.archive"

    log_info "${name}: завантаження ${url}"
    if ! curl -fsSL --retry 3 --retry-delay 2 -o "${dest}" "${url}"; then
        log_error "${name}: завантаження провалилось"
        return 1
    fi

    local hash
    hash=$(sha256sum "${dest}" | awk '{print $1}')
    log_ok "${name}: SHA256=${hash}"
    echo "${hash}"
}

update_cmake_var() {
    local file="$1"
    local var="$2"
    local hash="$3"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[dry-run] ${file}: ${var} = ${hash}"
        return
    fi

    if grep -q "^set(${var}  \"\"" "${file}"; then
        sed -i "s|^set(${var}  \"\".*|set(${var}  \"${hash}\"|" "${file}"
        log_ok "Оновлено ${file}: ${var}"
    elif grep -q "^set(${var}  \"" "${file}"; then
        # Вже є значення — замінюємо
        sed -i "s|^set(${var}  \"[^\"]*\"|set(${var}  \"${hash}\"|" "${file}"
        log_ok "Замінено ${file}: ${var}"
    else
        log_warn "${file}: змінна ${var} не знайдена, пропускаємо"
    fi
}

should_process() {
    local name="$1"
    [[ -z "${FILTER_LIB}" || "${FILTER_LIB}" == "${name}" ]]
}

# --- Версії (читаємо з cmake-файлів) ----------------------------------------

get_cmake_version() {
    local file="$1"
    local var="$2"
    grep -oP "(?<=set\(${var}  \")[^\"]*" "${file}" || \
    grep -oP "(?<=set\(${var} \")[^\"]*" "${file}" || echo ""
}

# --- Обробка кожної бібліотеки -----------------------------------------------

# Zlib
if should_process "zlib"; then
    ZLIB_FILE="${PROJECT_ROOT}/cmake/external/Zlib.cmake"
    ZLIB_VER=$(get_cmake_version "${ZLIB_FILE}" "ZLIB_VERSION")
    if [[ -n "${ZLIB_VER}" ]]; then
        ZLIB_URL="https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VER}.tar.gz"
        ZLIB_HASH=$(download_and_hash "zlib-${ZLIB_VER}" "${ZLIB_URL}")
        update_cmake_var "${ZLIB_FILE}" "ZLIB_SHA256" "${ZLIB_HASH}"
    else
        log_warn "Не вдалося визначити ZLIB_VERSION"
    fi
fi

# OneTBB
if should_process "onetbb"; then
    TBB_FILE="${PROJECT_ROOT}/cmake/external/OneTBB.cmake"
    TBB_VER=$(get_cmake_version "${TBB_FILE}" "ONETBB_VERSION")
    if [[ -n "${TBB_VER}" ]]; then
        TBB_URL="https://github.com/uxlfoundation/oneTBB/archive/refs/tags/v${TBB_VER}.tar.gz"
        TBB_HASH=$(download_and_hash "onetbb-${TBB_VER}" "${TBB_URL}")
        update_cmake_var "${TBB_FILE}" "ONETBB_SHA256" "${TBB_HASH}"
    else
        log_warn "Не вдалося визначити ONETBB_VERSION"
    fi
fi

# Boost
if should_process "boost"; then
    BOOST_FILE="${PROJECT_ROOT}/cmake/external/Boost.cmake"
    BOOST_VER=$(get_cmake_version "${BOOST_FILE}" "BOOST_VERSION")
    if [[ -n "${BOOST_VER}" ]]; then
        BOOST_VER_U="${BOOST_VER//./_}"
        BOOST_URL="https://archives.boost.io/release/${BOOST_VER}/source/boost_${BOOST_VER_U}.tar.gz"
        BOOST_HASH=$(download_and_hash "boost-${BOOST_VER}" "${BOOST_URL}")
        update_cmake_var "${BOOST_FILE}" "BOOST_SHA256" "${BOOST_HASH}"
    else
        log_warn "Не вдалося визначити BOOST_VERSION"
    fi
fi

# OpenCV (main + contrib мають однаковий OPENCV_VERSION)
if should_process "opencv"; then
    OCV_FILE="${PROJECT_ROOT}/cmake/external/OpenCV.cmake"
    OCV_VER=$(get_cmake_version "${OCV_FILE}" "OPENCV_VERSION")
    if [[ -n "${OCV_VER}" ]]; then
        OCV_URL="https://github.com/opencv/opencv/archive/${OCV_VER}.tar.gz"
        OCV_HASH=$(download_and_hash "opencv-${OCV_VER}" "${OCV_URL}")
        update_cmake_var "${OCV_FILE}" "OPENCV_SHA256" "${OCV_HASH}"
    else
        log_warn "Не вдалося визначити OPENCV_VERSION"
    fi
fi

if should_process "opencv_contrib"; then
    OCV_FILE="${PROJECT_ROOT}/cmake/external/OpenCV.cmake"
    OCV_VER=$(get_cmake_version "${OCV_FILE}" "OPENCV_VERSION")
    if [[ -n "${OCV_VER}" ]]; then
        CONTRIB_URL="https://github.com/opencv/opencv_contrib/archive/${OCV_VER}.tar.gz"
        CONTRIB_HASH=$(download_and_hash "opencv_contrib-${OCV_VER}" "${CONTRIB_URL}")
        update_cmake_var "${OCV_FILE}" "OPENCV_CONTRIB_SHA256" "${CONTRIB_HASH}"
    else
        log_warn "Не вдалося визначити OPENCV_VERSION для contrib"
    fi
fi

echo ""
if [[ "${DRY_RUN}" == true ]]; then
    log_ok "Dry-run завершено. Для запису змін запустіть без --dry-run."
else
    log_ok "SHA256 оновлено. Перевірте зміни через: git diff cmake/external/"
fi
