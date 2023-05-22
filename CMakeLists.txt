cmake_minimum_required(VERSION 3.24)
project(Facade CXX)

if(APPLE)
    set(BUNDLE_DEFAULT ON)
else()
    set(BUNDLE_DEFAULT OFF)
endif()

option(LENS_FEATURE_ONNX "Support ONNX models for inference" ON)
option(LENS_FEATURE_BUNDLE "Bundle Lens into an application" ${BUNDLE_DEFAULT})

set(CMAKE_C_STANDARD 20)
set(CMAKE_CXX_STANDARD 20)
set(TBB_DIR /usr/local/opt/onetbb/onetbb/lib/cmake/TBB)
set(LENS Lens)
set(LENS_BUNDLE "${CMAKE_CURRENT_BINARY_DIR}/${LENS}.app")

find_package(Boost COMPONENTS program_options REQUIRED)
find_package(OpenCV REQUIRED)
find_package(TBB REQUIRED)
find_package(PkgConfig REQUIRED)

#pkg_check_modules(libonnxruntime REQUIRED IMPORTED_TARGET libonnxruntime)

include_directories(.)
include_directories(Include)

add_executable(Facade
        Include/facade.h
        CLI/main.cpp
        CLI/commands.cpp
        CLI/commands.hpp)

add_executable(lens
                Lens/main.cpp
                Lens/include/lens.hpp
                Lens/include/filters.hpp
                Lens/face_pipeline.cpp
                Lens/data.cpp
                Lens/include/ml.h
        Lens/ml/face_swap.mm
                Lens/include/filters.hpp
                Lens/platform/darwin/filters.mm
                Lens/platform/darwin/load.mm Lens/ml/center_face.mm Lens/ml/model_loader.h Lens/ml/model_loader.mm Lens/ml/center_face.cpp Lens/ml/face_mesh.mm Lens/ml/face_swap.cpp Lens/ml/face_compositor.metal)
add_executable(ttest Test/main.cpp)

if(APPLE)
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
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wall -g")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Wall")

    include_directories(/usr/local/include ~/PaalMaxima/onnxruntime/include ~/Workspace/PaalMaxima/onnxruntime/include /opt/homebrew/include SYSTEM)
    include_directories(~/PaalMaxima/onnxruntime/include/onnxruntime/core/session
            ~/Workspace/PaalMaxima/onnxruntime/include/onnxruntime/core/session ~/Workspace/PaalMaxima/onnxruntime/onnxruntime
            ~/PaalMaxima/onnxruntime/onnxruntime
            ./Lens/include)

    target_link_directories(Facade PUBLIC
            /Applications/Facade.app/Contents/Frameworks
            /Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework)
    target_link_libraries(Facade facade Boost::program_options)

    target_link_directories(lens PUBLIC
            /Applications/Facade.app/Contents/Frameworks
            /Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework
            ~/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            ~/Workspace/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            Darwin/DerivedData/Facade/Build/Products/Debug/libfacade.dylib.framework/
            /usr/local/lib
            /opt/homebrew/lib)
    target_link_directories(ttest PUBLIC
            ~/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            ~/Workspace/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            /usr/local/lib
            /opt/homebrew/lib)

    target_link_libraries(lens facade Boost::program_options tbb ${OpenCV_LIBS} onnxruntime ${ACCELERATE} ${AV_FOUNDATION} ${CORE_GRAPHICS} ${CORE_IMAGE} ${CORE_MEDIA} ${CORE_ML} ${CORE_VIDEO} ${FOUNDATION} ${METAL} ${METAL_KIT} ${MPS})
    target_link_libraries(ttest tbb onnxruntime)

    set(FACE_COMPOSITOR_LIB ${CMAKE_CURRENT_BINARY_DIR}/face_compositor.metallib)

    add_custom_command(OUTPUT FACE_COMPOSITOR_LIB
            COMMAND xcrun -sdk macosx metal -c Lens/ml/face_compositor.metal -o ${CMAKE_CURRENT_BINARY_DIR}/face_compositor.air &&
                    xcrun -sdk macosx metallib ${CMAKE_CURRENT_BINARY_DIR}/face_compositor.air -o ${FACE_COMPOSITOR_LIB}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            COMMENT "Creating ${FACE_COMPOSITOR_LIB}"
            VERBATIM)

    add_custom_target(face_compositor ALL DEPENDS FACE_COMPOSITOR_LIB)

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