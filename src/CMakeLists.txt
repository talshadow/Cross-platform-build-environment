add_executable(opencv_example main.cpp)

target_link_libraries(opencv_example PRIVATE
    OpenCV::opencv_core
    OpenCV::opencv_imgproc
    OpenCV::opencv_imgcodecs
)

ep_target_add_compile_deps(opencv_example)

target_enable_warnings(opencv_example STRICT)

if(ENABLE_ASAN OR ENABLE_UBSAN)
    target_enable_sanitizers(opencv_example
        $<$<BOOL:${ENABLE_ASAN}>:ASAN>
        $<$<BOOL:${ENABLE_UBSAN}>:UBSAN>
    )
endif()

project_setup_install(opencv_example)
