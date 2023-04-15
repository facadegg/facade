cmake_minimum_required(VERSION 3.24)
project(Facade CXX)

set(CMAKE_C_STANDARD 20)
set(CMAKE_CXX_STANDARD 20)
set(TBB_DIR /usr/local/opt/onetbb/onetbb/lib/cmake/TBB)

find_package(Boost COMPONENTS program_options REQUIRED)
find_package(OpenCV REQUIRED)
find_package(TBB REQUIRED)
find_package(PkgConfig REQUIRED)

#pkg_check_modules(libonnxruntime REQUIRED IMPORTED_TARGET libonnxruntime)

include_directories(.)
include_directories(Include)

add_executable(Facade
        Include/facade.h CLI/main.cpp CLI/commands.cpp CLI/commands.hpp)

add_executable(Lens Lens/main.cpp Lens/include/lens.hpp Lens/face_pipeline.cpp Lens/data.cpp Lens/include/ml.h Lens/ml/coreml.mm)
add_executable(ttest Test/main.cpp)

if(APPLE)
    find_library(FOUNDATION Foundation)
    find_library(CORE_ML CoreML)
    find_library(CORE_VIDEO CoreVideo)

    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wall")
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

    target_link_directories(Lens PUBLIC
            /Applications/Facade.app/Contents/Frameworks
            /Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework
            ~/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            ~/Workspace/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            /usr/local/lib
            /opt/homebrew/lib)
    target_link_directories(ttest PUBLIC
            ~/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            ~/Workspace/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            /usr/local/lib
            /opt/homebrew/lib)

    target_link_libraries(Lens facade ${OpenCV_LIBS} tbb onnxruntime ${CORE_ML} ${CORE_VIDEO} ${FOUNDATION})
    target_link_libraries(ttest tbb onnxruntime)
endif()