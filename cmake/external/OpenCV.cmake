# cmake/external/OpenCV.cmake
#
# Збирає або знаходить OpenCV разом з opencv_contrib.
# opencv_contrib завантажується як окремий EP (тільки unpack, без збірки).
#
# При збірці автоматично використовує вже підключені залежності:
#   JPEG::JPEG, PNG::PNG, TIFF::TIFF, OpenSSL::SSL
#
# Provides imported targets (після першої успішної збірки — через find_package):
#   Core: opencv_core, opencv_imgproc, opencv_imgcodecs, opencv_highgui,
#         opencv_videoio, opencv_video, opencv_features2d, opencv_calib3d,
#         opencv_objdetect, opencv_dnn, opencv_ml, opencv_flann, opencv_photo
#   Contrib: opencv_aruco, opencv_bgsegm, opencv_bioinspired, opencv_ccalib,
#            opencv_datasets, opencv_dnn_objdetect, opencv_dnn_superres, opencv_dpm,
#            opencv_face, opencv_freetype, opencv_fuzzy, opencv_hdf, opencv_hfs,
#            opencv_img_hash, opencv_intensity_transform, opencv_line_descriptor,
#            opencv_mcc, opencv_optflow, opencv_ovis, opencv_phase_unwrapping,
#            opencv_plot, opencv_quality, opencv_rapid, opencv_reg, opencv_rgbd,
#            opencv_saliency, opencv_sfm, opencv_shape, opencv_stereo,
#            opencv_structured_light, opencv_superres, opencv_surface_matching,
#            opencv_text, opencv_tracking, opencv_videostab, opencv_viz,
#            opencv_wechat_qrcode, opencv_xfeatures2d, opencv_ximgproc,
#            opencv_xobjdetect, opencv_xphoto
#   Всі таргети доступні як OpenCV::<module_name>
#
# При першій збірці (бібліотека ще не встановлена) — placeholder targets
# з майбутніми шляхами. Після `cmake --build` повторна конфігурація
# автоматично перейде на реальні targets через find_package.
#
# Опції:
#   USE_SYSTEM_OPENCV      — ON: find_package в системі/sysroot
#                            OFF (за замовченням): зібрати через ExternalProject
#   OPENCV_ENABLE_CONTRIB  — ON (за замовченням): включати opencv_contrib модулі
#   OPENCV_WITH_FFMPEG     — ON (за замовченням): увімкнути підтримку FFmpeg
#                            Потребує libavcodec/avformat/avutil/swscale-dev в sysroot.
#                            При крос-збірці: pkg-config повинен бачити ffmpeg з sysroot.
#   OPENCV_WITH_OPENCL     — ON (за замовченням): увімкнути підтримку OpenCL
#                            Потребує OpenCL ICD loader (libOpenCL.so) і заголовків
#                            (opencl-headers) в sysroot або на хості.
#   OPENCV_WITH_V4L2       — ON (за замовченням): увімкнути підтримку V4L2 (kernel headers)
#                            Потребує linux/videodev2.h в sysroot.
#   OPENCV_WITH_LIBV4L     — ON (за замовченням): використовувати libv4l2 userspace wrapper
#                            Потребує libv4l-dev в sysroot; якщо відсутній — OpenCV ігнорує.
#   OPENCV_WITH_LAPACK     — ON (за замовченням): увімкнути підтримку BLAS/LAPACK у OpenCV
#                            Потребує libblas-dev і liblapacke-dev (або libopenblas-dev) в sysroot.
#                            Прискорює SVD, solve та інші операції лінійної алгебри.
#   OPENCV_ENABLE_NONFREE  — ON (за замовченням): non-free алгоритми (SIFT, SURF тощо)
#                            Увага: патентні обмеження в деяких юрисдикціях.
#
# Кеш-змінні:
#   OPENCV_VERSION          — версія (git тег або архів)
#   OPENCV_GIT_REPO         — URL git репозиторію OpenCV (тільки при OPENCV_USE_GIT=ON)
#   OPENCV_CONTRIB_GIT_REPO — URL git репозиторію opencv_contrib (тільки при OPENCV_USE_GIT=ON)

option(USE_SYSTEM_OPENCV
    "Використовувати системний OpenCV (find_package) замість збірки з джерел"
    OFF)

option(OPENCV_ENABLE_CONTRIB
    "Включати opencv_contrib модулі при збірці"
    ON)

option(OPENCV_WITH_FFMPEG
    "Збирати OpenCV з підтримкою FFmpeg (потребує ffmpeg dev-libs в sysroot/системі)"
    ON)

option(OPENCV_WITH_OPENCL
    "Збирати OpenCV з підтримкою OpenCL (потребує OpenCL ICD loader в sysroot/системі)"
    ON)

option(OPENCV_WITH_V4L2
    "Збирати OpenCV з підтримкою V4L2 (потребує linux/videodev2.h в sysroot)"
    ON)

option(OPENCV_WITH_LIBV4L
    "Використовувати libv4l2 userspace wrapper (потребує libv4l-dev в sysroot; auto-detected)"
    ON)

option(OPENCV_WITH_LAPACK
    "Збирати OpenCV з підтримкою BLAS/LAPACK (потребує libblas-dev і liblapacke-dev або libopenblas-dev в sysroot)"
    ON)

option(OPENCV_ENABLE_NONFREE
    "Увімкнути non-free алгоритми OpenCV (SIFT, SURF тощо; обмеження патентів)"
    ON)

option(OPENCV_USE_GIT
    "Завантажувати OpenCV через git clone (OFF = архів з GitHub Releases)"
    OFF)

set(OPENCV_VERSION  "4.13.0"
    CACHE STRING "Версія OpenCV для збірки з джерел")

set(OPENCV_SHA256  ""
    CACHE STRING "SHA256 для OpenCV архіву (порожньо = без верифікації; заповнити через build-system-update-hashes.sh)")

set(OPENCV_CONTRIB_SHA256  ""
    CACHE STRING "SHA256 для opencv_contrib архіву (порожньо = без верифікації; заповнити через build-system-update-hashes.sh)")

set(OPENCV_GIT_REPO
    "https://github.com/opencv/opencv.git"
    CACHE STRING "Git репозиторій OpenCV (використовується тільки при OPENCV_USE_GIT=ON)")

set(OPENCV_CONTRIB_GIT_REPO
    "https://github.com/opencv/opencv_contrib.git"
    CACHE STRING "Git репозиторій opencv_contrib (використовується тільки при OPENCV_USE_GIT=ON)")

# ---------------------------------------------------------------------------

ep_resolve_prefix(_ocv_prefix "lib/libopencv_core.so")
set(_ocv_lib_dir "${_ocv_prefix}/lib")
set(_ocv_inc_dir "${_ocv_prefix}/include/opencv4")
set(_ocv_core    "${_ocv_lib_dir}/libopencv_core.so")

# Список модулів для placeholder targets (використовується якщо бібліотека ще не зібрана)
set(_ocv_modules
    # core modules
    opencv_core
    opencv_imgproc
    opencv_imgcodecs
    opencv_highgui
    opencv_videoio
    opencv_video
    opencv_features2d
    opencv_calib3d
    opencv_objdetect
    opencv_dnn
    opencv_ml
    opencv_flann
    opencv_photo
    # contrib modules
    opencv_aruco
    opencv_bgsegm
    opencv_bioinspired
    opencv_ccalib
    opencv_datasets
    opencv_dnn_objdetect
    opencv_dnn_superres
    opencv_dpm
    opencv_face
    opencv_freetype
    opencv_fuzzy
    opencv_hdf
    opencv_hfs
    opencv_img_hash
    opencv_intensity_transform
    opencv_line_descriptor
    opencv_mcc
    opencv_optflow
    opencv_ovis
    opencv_phase_unwrapping
    opencv_plot
    opencv_quality
    opencv_rapid
    opencv_reg
    opencv_rgbd
    opencv_saliency
    opencv_sfm
    opencv_shape
    opencv_stereo
    opencv_structured_light
    opencv_superres
    opencv_surface_matching
    opencv_text
    opencv_tracking
    opencv_videostab
    opencv_viz
    opencv_wechat_qrcode
    opencv_xfeatures2d
    opencv_ximgproc
    opencv_xobjdetect
    opencv_xphoto
)

# Хелпер: створює OpenCV:: IMPORTED targets для вже встановленого або EP OpenCV
macro(_ocv_make_imported_targets ep_name_or_empty)
    # CMake 3.28+ валідує INTERFACE_INCLUDE_DIRECTORIES при конфігурації.
    # Для placeholder-targets (EP ще не зібрано) директорії можуть не існувати.
    file(MAKE_DIRECTORY "${_ocv_inc_dir}" "${_ocv_prefix}/include")
    foreach(_mod ${_ocv_modules})
        if(NOT TARGET OpenCV::${_mod})
            set(_mod_lib "${_ocv_lib_dir}/lib${_mod}.so")
            add_library(OpenCV::${_mod} SHARED IMPORTED GLOBAL)
            set_target_properties(OpenCV::${_mod} PROPERTIES
                IMPORTED_LOCATION             "${_mod_lib}"
                INTERFACE_INCLUDE_DIRECTORIES "${_ocv_inc_dir};${_ocv_prefix}/include"
            )
            if(ep_name_or_empty AND TARGET ${ep_name_or_empty})
                _ep_make_sync_target(${ep_name_or_empty})
                set_property(TARGET OpenCV::${_mod} APPEND PROPERTY
                    INTERFACE_LINK_LIBRARIES _ep_sync_${ep_name_or_empty})
            endif()
        endif()
    endforeach()
endmacro()

# Хелпер: OpenCV:: ALIAS для targets, які створює сам OpenCV CMake config (opencv_core тощо)
macro(_ocv_make_namespace_aliases)
    foreach(_mod ${_ocv_modules})
        if(TARGET ${_mod} AND NOT TARGET OpenCV::${_mod})
            add_library(OpenCV::${_mod} ALIAS ${_mod})
        endif()
    endforeach()
endmacro()

# ---------------------------------------------------------------------------

if(USE_SYSTEM_OPENCV)
    # ── Системна бібліотека / sysroot ───────────────────────────────────────
    find_package(OpenCV REQUIRED)
    _ocv_make_namespace_aliases()
    message(STATUS "[OpenCV] Системна бібліотека версії ${OpenCV_VERSION}")

else()
    # ── Алгоритм: find_package → ExternalProject_Add ────────────────────────
    find_package(OpenCV QUIET HINTS "${_ocv_prefix}" NO_DEFAULT_PATH)
    if(OpenCV_FOUND)
        _ocv_make_namespace_aliases()
        message(STATUS "[OpenCV] Знайдено готову бібліотеку у ${_ocv_prefix} (${OpenCV_VERSION})")

    elseif(EXISTS "${_ocv_core}")
        _ocv_make_imported_targets("")
        message(STATUS "[OpenCV] Знайдено .so у ${_ocv_prefix}")

    else()
        message(STATUS "[OpenCV] Буде зібрано з джерел (версія ${OPENCV_VERSION})")

        # ── opencv_contrib: тільки clone, збірка відбувається у opencv_ep ─
        set(_contrib_src "${EP_SOURCES_DIR}/opencv_contrib")

        if(OPENCV_ENABLE_CONTRIB)
            if(OPENCV_USE_GIT)
                set(_ocv_contrib_download_args
                    GIT_REPOSITORY   "${OPENCV_CONTRIB_GIT_REPO}"
                    GIT_TAG          "${OPENCV_VERSION}"
                    GIT_SHALLOW      ON
                )
            else()
                set(_ocv_contrib_download_args
                    URL "https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.tar.gz"
                    DOWNLOAD_EXTRACT_TIMESTAMP ON
                )
                if(OPENCV_CONTRIB_SHA256)
                    list(APPEND _ocv_contrib_download_args URL_HASH "SHA256=${OPENCV_CONTRIB_SHA256}")
                endif()
            endif()

            ExternalProject_Add(opencv_contrib_ep
                ${_ocv_contrib_download_args}
                SOURCE_DIR       "${_contrib_src}"
                CONFIGURE_COMMAND ""
                BUILD_COMMAND     ""
                INSTALL_COMMAND   ""
                LOG_DOWNLOAD      ON
            )
            set(_ocv_contrib_arg
                "-DOPENCV_EXTRA_MODULES_PATH=${_contrib_src}/modules")
        else()
            set(_ocv_contrib_arg "")
        endif()

        # ── Збираємо аргументи залежних бібліотек ─────────────────────────
        set(_ocv_dep_args
            # Вимикаємо пошук системних бібліотек якщо не вказано явно
            -DWITH_JASPER=OFF
            -DWITH_WEBP=OFF
            -DWITH_OPENJPEG=OFF
        )

        if(TARGET JPEG::JPEG)
            get_target_property(_jpeg_loc JPEG::JPEG IMPORTED_LOCATION)
            if(_jpeg_loc AND NOT _jpeg_loc MATCHES "NOTFOUND")
                list(APPEND _ocv_dep_args
                    -DWITH_JPEG=ON
                    "-DJPEG_LIBRARY=${_jpeg_loc}"
                    "-DJPEG_INCLUDE_DIR=${EXTERNAL_INSTALL_PREFIX}/include"
                )
            endif()
        endif()

        if(TARGET PNG::PNG)
            get_target_property(_png_loc PNG::PNG IMPORTED_LOCATION)
            if(_png_loc AND NOT _png_loc MATCHES "NOTFOUND")
                list(APPEND _ocv_dep_args
                    -DWITH_PNG=ON
                    "-DPNG_LIBRARY=${_png_loc}"
                    "-DPNG_PNG_INCLUDE_DIR=${EXTERNAL_INSTALL_PREFIX}/include"
                )
            endif()
        endif()

        if(TARGET TIFF::TIFF)
            get_target_property(_tiff_loc TIFF::TIFF IMPORTED_LOCATION)
            if(_tiff_loc AND NOT _tiff_loc MATCHES "NOTFOUND")
                list(APPEND _ocv_dep_args
                    -DWITH_TIFF=ON
                    "-DTIFF_LIBRARY=${_tiff_loc}"
                    "-DTIFF_INCLUDE_DIR=${EXTERNAL_INSTALL_PREFIX}/include"
                )
            endif()
        endif()

        if(TARGET OpenSSL::SSL)
            list(APPEND _ocv_dep_args
                -DWITH_OPENSSL=ON
                "-DOPENSSL_ROOT_DIR=${EXTERNAL_INSTALL_PREFIX}"
            )
        endif()

        # TBB: передаємо шлях до нашого EP TBB щоб OpenCV не взяв системний
        set(_ocv_tbb_args "")
        if(TARGET TBB::tbb)
            list(APPEND _ocv_tbb_args
                -DWITH_TBB=ON
                "-DTBB_DIR=${EXTERNAL_INSTALL_PREFIX}/lib/cmake/TBB"
                -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF
            )
        else()
            list(APPEND _ocv_tbb_args -DWITH_TBB=ON)
        endif()

        # BLAS/LAPACK: при крос-компіляції CMake's FindBLAS/FindLAPACK не знаходять
        # бібліотеки у нестандартних Debian multiarch підкаталогах (openblas-pthread/ тощо).
        #
        # OpenCV cmake (OpenCVFindLAPACK.cmake) активує LAPACK тільки якщо задані:
        #   BLAS_LIBRARIES / LAPACK_LIBRARIES — шляхи до .so
        #   LAPACK_CBLAS_H / LAPACK_LAPACKE_H — імена заголовків (не шляхи!)
        #   LAPACK_INCLUDE_DIR — директорії де знаходяться ці заголовки
        #     (повний sysroot-prefixed шлях: cmake strip-and-re-roots через ONLY mode,
        #      та передає напряму до try_compile INCLUDE_DIRECTORIES)
        set(_ocv_lapack_ep_args "")
        if(OPENCV_WITH_LAPACK AND CMAKE_CROSSCOMPILING AND CMAKE_SYSROOT AND CMAKE_LIBRARY_ARCHITECTURE)
            set(_ocv_sr  "${CMAKE_SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}")
            set(_ocv_sr2 "${CMAKE_SYSROOT}/lib/${CMAKE_LIBRARY_ARCHITECTURE}")

            set(_ocv_blas_lib "")
            foreach(_ocv_d
                    "${_ocv_sr}/openblas-pthread"  "${_ocv_sr2}/openblas-pthread"
                    "${_ocv_sr}"                    "${_ocv_sr2}")
                foreach(_ocv_n "libblas.so" "libopenblas.so")
                    if(EXISTS "${_ocv_d}/${_ocv_n}")
                        set(_ocv_blas_lib "${_ocv_d}/${_ocv_n}")
                        break()
                    endif()
                endforeach()
                if(_ocv_blas_lib)
                    break()
                endif()
            endforeach()

            set(_ocv_lapack_lib "")
            foreach(_ocv_d
                    "${_ocv_sr}/openblas-pthread"  "${_ocv_sr2}/openblas-pthread"
                    "${_ocv_sr}/lapack"             "${_ocv_sr2}/lapack"
                    "${_ocv_sr}"                    "${_ocv_sr2}")
                if(EXISTS "${_ocv_d}/liblapack.so")
                    set(_ocv_lapack_lib "${_ocv_d}/liblapack.so")
                    break()
                endif()
            endforeach()

            # cblas.h: шукаємо у нестандартних multiarch include підкаталогах
            set(_ocv_cblas_inc "")
            set(_ocv_inc_base "${CMAKE_SYSROOT}/usr/include")
            foreach(_ocv_d
                    "${_ocv_inc_base}/${CMAKE_LIBRARY_ARCHITECTURE}/openblas-pthread"
                    "${_ocv_inc_base}/${CMAKE_LIBRARY_ARCHITECTURE}"
                    "${_ocv_inc_base}")
                if(EXISTS "${_ocv_d}/cblas.h")
                    set(_ocv_cblas_inc "${_ocv_d}")
                    break()
                endif()
            endforeach()

            if(_ocv_blas_lib AND _ocv_lapack_lib)
                # LAPACK_INCLUDE_DIR будуємо як cmake list (';'-розділювач).
                # Передається через init-cache (не через -D), щоб уникнути
                # проблем з екрануванням ';' при серіалізації ExternalProject cmake args.
                set(_ocv_lapack_inc_dirs "${_ocv_inc_base}")
                if(_ocv_cblas_inc AND NOT _ocv_cblas_inc STREQUAL _ocv_inc_base)
                    list(PREPEND _ocv_lapack_inc_dirs "${_ocv_cblas_inc}")
                endif()

                list(APPEND _ocv_lapack_ep_args
                    "-DBLAS_LIBRARIES=${_ocv_blas_lib}"
                    "-DLAPACK_LIBRARIES=${_ocv_lapack_lib}"
                    "-DLAPACK_CBLAS_H=cblas.h"
                    "-DLAPACK_LAPACKE_H=lapacke.h"
                    # cblas.h/lapacke.h мають власні extern "C" guards для C++;
                    # OpenCV's обгортка extern "C" {} зайва і ламає компіляцію
                    # коли lapack.h включає <complex> всередині extern "C" блоку.
                    -DOPENCV_SKIP_LAPACK_EXTERN_C=ON)
                message(STATUS "[OpenCV] BLAS:   ${_ocv_blas_lib}")
                message(STATUS "[OpenCV] LAPACK: ${_ocv_lapack_lib}")
                if(_ocv_cblas_inc)
                    message(STATUS "[OpenCV] cblas.h: ${_ocv_cblas_inc}")
                else()
                    message(STATUS "[OpenCV] cblas.h: не знайдено у sysroot")
                endif()
            else()
                message(STATUS "[OpenCV] BLAS/LAPACK не знайдено у sysroot — вимикаємо WITH_LAPACK")
                list(APPEND _ocv_lapack_ep_args -DWITH_LAPACK=OFF)
            endif()
            unset(_ocv_sr)
            unset(_ocv_sr2)
            unset(_ocv_blas_lib)
            unset(_ocv_lapack_lib)
            unset(_ocv_cblas_inc)
            unset(_ocv_inc_base)
            unset(_ocv_d)
            unset(_ocv_n)
        endif()

        ep_cmake_args(_ocv_cmake_args
            # Мінімізуємо залежності для embedded/cross-compilation
            # BUILD_SHARED_LIBS=ON вже передається через ep_cmake_args()
            -DBUILD_TESTS=OFF
            -DBUILD_PERF_TESTS=OFF
            -DBUILD_EXAMPLES=OFF
            -DBUILD_DOCS=OFF
            -DWITH_GTK=OFF
            -DWITH_QT=${PLATFORM_X86_64}
            -DWITH_CUDA=OFF
            -DWITH_IPP=OFF
            -DOPENCV_GENERATE_PKGCONFIG=ON
            -DWITH_OPENGL=${PLATFORM_X86_64}
            # Керовані опції (OFF за замовченням; вмикаються через OPENCV_WITH_* / OPENCV_ENABLE_*)
            -DWITH_FFMPEG=${OPENCV_WITH_FFMPEG}
            -DWITH_OPENCL=${OPENCV_WITH_OPENCL}
            -DWITH_V4L=${OPENCV_WITH_V4L2}
            -DWITH_LIBV4L=${OPENCV_WITH_LIBV4L}
            -DWITH_LAPACK=${OPENCV_WITH_LAPACK}
            -DOPENCV_ENABLE_NONFREE=${OPENCV_ENABLE_NONFREE}
            ${_ocv_tbb_args}
            ${_ocv_contrib_arg}
            ${_ocv_dep_args}
            # Явні шляхи BLAS/LAPACK для cross-builds (overrides FindBLAS/FindLAPACK)
            ${_ocv_lapack_ep_args}
        )

        # Init-cache для pkg-config при крос-компіляції.
        # cmake's FindPkgConfig встановлює PKG_CONFIG_LIBDIR лише для usr/lib/pkgconfig,
        # але FFmpeg лежить в usr/lib/<arch>/pkgconfig — тому не знаходиться.
        # Через -C передаємо init-cache що виставляє PKG_CONFIG_LIBDIR до старту cmake.
        set(_ocv_init_cache "${CMAKE_BINARY_DIR}/_ep_cfg/opencv-init-cache.cmake")
        if(CMAKE_CROSSCOMPILING AND CMAKE_SYSROOT AND CMAKE_LIBRARY_ARCHITECTURE)
            set(_ocv_sysroot "${CMAKE_SYSROOT}")
            set(_ocv_arch    "${CMAKE_LIBRARY_ARCHITECTURE}")
            file(WRITE "${_ocv_init_cache}"
                "set(ENV{PKG_CONFIG_SYSROOT_DIR} \"${_ocv_sysroot}\")\n"
                "set(ENV{PKG_CONFIG_LIBDIR} "
                "\"${_ocv_sysroot}/usr/lib/${_ocv_arch}/pkgconfig:"
                "${_ocv_sysroot}/usr/lib/pkgconfig:"
                "${_ocv_sysroot}/usr/share/pkgconfig\")\n")
            if(_ocv_lapack_inc_dirs)
                # "Quoted ${var}" у file(APPEND) зберігає ';' буквально →
                # cmake list у init-cache читається коректно через -C
                file(APPEND "${_ocv_init_cache}"
                    "set(LAPACK_INCLUDE_DIR \"${_ocv_lapack_inc_dirs}\" CACHE PATH \"\" FORCE)\n")
            endif()
            unset(_ocv_sysroot)
            unset(_ocv_arch)
        else()
            file(WRITE "${_ocv_init_cache}" "# native build — no extra pkg-config setup\n")
        endif()
        unset(_ocv_lapack_inc_dirs)

        # BYPRODUCTS — основні модулі для Ninja
        set(_ocv_byproducts "")
        foreach(_mod IN LISTS _ocv_modules)
            list(APPEND _ocv_byproducts "${_ocv_lib_dir}/lib${_mod}.so")
        endforeach()

        # Патч-скрипт — генерується зараз, запускається під час cmake --build.
        # Два патчи:
        #   1. cmake_minimum_required(VERSION 2.x) → 3.28 у OpenCVGenPkgconfig.cmake
        #   2. #undef complex після #include <complex.h> у hal_internal.cpp
        #      Sysroot complex.h визначає #define complex _Complex без __cplusplus guard →
        #      std::complex<T> у hal_internal.cpp розкривається у std::_Complex<T> → помилка.
        set(_ocv_cfg_cmake  "${EP_SOURCES_DIR}/opencv/cmake/OpenCVGenPkgconfig.cmake")
        set(_ocv_hal_cpp    "${EP_SOURCES_DIR}/opencv/modules/core/src/hal_internal.cpp")
        set(_ocv_patch_script "${CMAKE_BINARY_DIR}/_ep_cfg/opencv-patch.cmake")
        file(WRITE "${_ocv_patch_script}"
            "file(READ \"${_ocv_cfg_cmake}\" _c)\n"
            "string(REGEX REPLACE\n"
            "    \"cmake_minimum_required\\\\(VERSION 2\\\\.[0-9][0-9.]*\"\n"
            "    \"cmake_minimum_required(VERSION 3.28\" _c \"\${_c}\")\n"
            "file(WRITE \"${_ocv_cfg_cmake}\" \"\${_c}\")\n"
            "file(READ \"${_ocv_hal_cpp}\" _c)\n"
            "string(REPLACE\n"
            "    \"#include <complex.h>\\n#include \\\"opencv_lapack.h\\\"\"\n"
            "    \"#include <complex.h>\\n#undef complex\\n#include \\\"opencv_lapack.h\\\"\"\n"
            "    _c \"\${_c}\")\n"
            "file(WRITE \"${_ocv_hal_cpp}\" \"\${_c}\")\n"
        )
        unset(_ocv_cfg_cmake)
        unset(_ocv_hal_cpp)

        if(OPENCV_USE_GIT)
            message(STATUS "[OpenCV] Джерело: git clone (${OPENCV_GIT_REPO})")
            set(_ocv_download_args
                GIT_REPOSITORY   "${OPENCV_GIT_REPO}"
                GIT_TAG          "${OPENCV_VERSION}"
                GIT_SHALLOW      ON
            )
        else()
            set(_ocv_archive_url
                "https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.tar.gz")
            message(STATUS "[OpenCV] Джерело: архів (${_ocv_archive_url})")
            set(_ocv_download_args
                URL                 "${_ocv_archive_url}"
                DOWNLOAD_EXTRACT_TIMESTAMP ON
            )
            if(OPENCV_SHA256)
                list(APPEND _ocv_download_args URL_HASH "SHA256=${OPENCV_SHA256}")
            endif()
            unset(_ocv_archive_url)
        endif()

        ExternalProject_Add(opencv_ep
            ${_ocv_download_args}
            SOURCE_DIR       "${EP_SOURCES_DIR}/opencv"
            PATCH_COMMAND    "${CMAKE_COMMAND}" -P "${_ocv_patch_script}"
            CMAKE_ARGS       "-C${_ocv_init_cache}" ${_ocv_cmake_args}
            BUILD_BYPRODUCTS ${_ocv_byproducts}
            LOG_DOWNLOAD     ON
            LOG_BUILD        ON
            LOG_INSTALL      ON
        )

        # Placeholder imported targets з майбутніми шляхами
        _ocv_make_imported_targets(opencv_ep)

        ep_track_cmake_file(opencv_ep "${CMAKE_CURRENT_LIST_FILE}")

        if(OPENCV_USE_GIT)
            ep_prestamp_git(opencv_ep "${EP_SOURCES_DIR}/opencv" "${OPENCV_VERSION}")
            if(OPENCV_ENABLE_CONTRIB)
                ep_prestamp_git(opencv_contrib_ep "${EP_SOURCES_DIR}/opencv_contrib" "${OPENCV_VERSION}")
            endif()
        else()
            if(EXISTS "${EP_SOURCES_DIR}/opencv/CMakeLists.txt")
                set(_s "${CMAKE_BINARY_DIR}/opencv_ep-prefix/src/opencv_ep-stamp")
                if(NOT EXISTS "${_s}/opencv_ep-download")
                    file(MAKE_DIRECTORY "${_s}")
                    file(WRITE "${_s}/opencv_ep-download" "")
                    message(STATUS "[OpenCV] Джерела вже є у ${EP_SOURCES_DIR}/opencv — download stamp створено (пропускаємо завантаження)")
                endif()
                unset(_s)
            endif()
            if(OPENCV_ENABLE_CONTRIB AND EXISTS "${EP_SOURCES_DIR}/opencv_contrib/modules")
                set(_s "${CMAKE_BINARY_DIR}/opencv_contrib_ep-prefix/src/opencv_contrib_ep-stamp")
                if(NOT EXISTS "${_s}/opencv_contrib_ep-download")
                    file(MAKE_DIRECTORY "${_s}")
                    file(WRITE "${_s}/opencv_contrib_ep-download" "")
                    message(STATUS "[OpenCV] Contrib джерела вже є у ${EP_SOURCES_DIR}/opencv_contrib — download stamp створено (пропускаємо завантаження)")
                endif()
                unset(_s)
            endif()
        endif()
    endif()
endif()

unset(_ocv_prefix)
unset(_ocv_lib_dir)
unset(_ocv_inc_dir)
unset(_ocv_core)
unset(_ocv_lapack_ep_args)
unset(_ocv_patch_script)
