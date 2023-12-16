if(APPLE)
    set(BUNDLE_DEFAULT ON)
else()
    set(BUNDLE_DEFAULT OFF)
endif()

option(LENS_FEATURE_ONNX "Support ONNX models for inference" OFF)
option(LENS_FEATURE_BUNDLE "Bundle Lens into an application" ${BUNDLE_DEFAULT})
option(LENS_FEATURE_DEBUG_CENTER_FACE "Debug CenterFace face detection and face fed into face swap" OFF)
option(LENS_FEATURE_DEBUG_FACE_MESH "Debug FaceMesh landmarks" OFF)
option(LENS_FEATURE_FILE_IO "Support reading input from & writing output to files for the video pipeline" ON)

add_executable(lens
        Lens/include/internal.h
        Lens/include/lens.h
        Lens/lens/center_face.cc
        Lens/lens/data.cc
        Lens/lens/face_mesh.cc
        Lens/lens/face_pipeline.cc
        Lens/lens/face_swap.cc
        Lens/lens/main.cc
        Lens/lens/output/base_output.cc
        Lens/lens/output/base_output.h
        Lens/lens/output/facade_output.cc
        Lens/lens/output/facade_output.h
        Lens/lens/output/output.cc)

target_include_directories(lens PUBLIC ./Lens/include)

if(LENS_FEATURE_FILE_IO)
    add_compile_definitions(LENS_FEATURE_FILE_IO)
    pkg_check_modules(LIBAV REQUIRED IMPORTED_TARGET
            libavdevice
            libavfilter
            libavformat
            libavcodec
            libswresample
            libswscale
            libavutil)

    include_directories(${LIBAV_INCLUDE_DIRS})
    target_link_directories(lens PUBLIC ${LIBAV_LIBRARY_DIRS})
    target_link_libraries(lens ${LIBAV_LIBRARIES})

    target_sources(lens PUBLIC
            Lens/lens/input/video.cc
            Lens/lens/output/file_output.cc
            Lens/lens/output/file_output.h)
endif()

if(LENS_FEATURE_ONNX)
    target_sources(lens PUBLIC
            Lens/onnx/center_face.cc
            Lens/onnx/face_mesh.cc
            Lens/onnx/face_swap.cc)
elseif(APPLE)
    target_sources(lens PUBLIC
            Lens/darwin/center_face.mm
            Lens/darwin/face_compositor.metal
            Lens/darwin/face_mesh.mm
            Lens/darwin/face_swap.mm
            Lens/darwin/model_loader.h
            Lens/darwin/model_loader.mm)
endif()

if(APPLE)
    add_compile_definitions(APPLE=ON)

    find_library(ACCELERATE Accelerate)
    find_library(AV_FOUNDATION AVFoundation)
    find_library(CORE_GRAPHICS CoreGraphics)
    find_library(CORE_IMAGE CoreImage)
    find_library(CORE_MEDIA CoreMedia)
    find_library(CORE_ML CoreML)
    find_library(CORE_VIDEO CoreVideo)
    find_library(METAL Metal)
    find_library(METAL_KIT MetalKit)
    find_library(MPS MetalPerformanceShaders)
    find_library(FOUNDATION Foundation)

    target_sources(lens PUBLIC
            Lens/darwin/filters.mm
            Lens/darwin/load.mm)

    target_link_directories(lens PUBLIC
            ~/Workspace/Facade/onnxruntime/build/MacOS/RelWithDebInfo
            Darwin/DerivedData/Facade/Build/Products/Debug/libfacade.dylib.framework/
            /usr/local/lib
            /opt/homebrew/lib)

    target_link_libraries(lens
            facade
            Boost::program_options
            tbb
            ${OpenCV_LIBS}
            ${ACCELERATE}
            ${AV_FOUNDATION}
            ${CORE_GRAPHICS}
            ${CORE_IMAGE}
            ${CORE_MEDIA}
            ${CORE_ML}
            ${CORE_VIDEO}
            ${FOUNDATION}
            ${METAL}
            ${METAL_KIT}
            ${MPS})

    set(FACE_COMPOSITOR_LIB ${CMAKE_CURRENT_BINARY_DIR}/face_compositor.metallib)
    add_custom_command(OUTPUT FACE_COMPOSITOR_LIB
            COMMAND xcrun -sdk macosx metal -c Lens/darwin/face_compositor.metal -o ${CMAKE_CURRENT_BINARY_DIR}/face_compositor.air &&
            xcrun -sdk macosx metallib ${CMAKE_CURRENT_BINARY_DIR}/face_compositor.air -o ${FACE_COMPOSITOR_LIB}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            COMMENT "Creating ${FACE_COMPOSITOR_LIB}"
            VERBATIM)
    add_custom_target(face_compositor ALL DEPENDS FACE_COMPOSITOR_LIB)
    add_dependencies(lens face_compositor)

    if(LENS_FEATURE_BUNDLE)
        set_target_properties(lens PROPERTIES
                MACOSX_BUNDLE TRUE
                MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Lens/Info.plist.in"
                OUTPUT_NAME ${LENS}
                INSTALL_RPATH "@executable_path/../Frameworks;/Applications/Facade.app/Contents/Frameworks"
                BUILD_WITH_INSTALL_RPATH TRUE
                INSTALL_RPATH_USE_LINK_PATH FALSE)

        add_custom_command(TARGET lens POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E echo "Running bundle.py"
                COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${CMAKE_CURRENT_SOURCE_DIR}/Buildscripts ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/Buildscripts/bundle.py ${LENS_BUNDLE} ${LENS}
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    endif()
endif()

if(LENS_FEATURE_ONNX)
    add_compile_definitions(LENS_FEATURE_ONNX=ON)
    target_link_libraries(lens onnxruntime)
endif()

if(LENS_FEATURE_DEBUG_CENTER_FACE)
    add_compile_definitions(LENS_FEATURE_DEBUG_CENTER_FACE=ON)
endif()

if(LENS_FEATURE_DEBUG_FACE_MESH)
    add_compile_definitions(LENS_FEATURE_DEBUG_FACE_MESH=ON)
endif()

if(LENS_FEATURE_DEBUG_NO_COMPOSITE)
    add_compile_definitions(LENS_FEATURE_DEBUG_NO_COMPOSITE=ON)
endif()