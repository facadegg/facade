cmake_minimum_required(VERSION 3.24)
project(Facade CXX)

if(APPLE)
    set(BUNDLE_DEFAULT ON)
else()
    set(BUNDLE_DEFAULT OFF)
endif()

option(LENS_FEATURE_ONNX "Support ONNX models for inference" OFF)
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

set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wall -g")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Wall")

include_directories(.)
include_directories(Include)

include(lens/CMakeLists.txt)

add_executable(Facade
        Include/facade.h
        CLI/main.cpp
        CLI/commands.cpp
        CLI/commands.hpp)

if(APPLE)
    include_directories(/usr/local/include ~/PaalMaxima/onnxruntime/include ~/Workspace/PaalMaxima/onnxruntime/include /opt/homebrew/include SYSTEM)
    include_directories(~/PaalMaxima/onnxruntime/include/onnxruntime/core/session
            ~/Workspace/PaalMaxima/onnxruntime/include/onnxruntime/core/session ~/Workspace/PaalMaxima/onnxruntime/onnxruntime
            ~/PaalMaxima/onnxruntime/onnxruntime)

    target_link_directories(Facade PUBLIC
            /Applications/Facade.app/Contents/Frameworks
            /Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework)
    target_link_libraries(Facade facade Boost::program_options)
endif()