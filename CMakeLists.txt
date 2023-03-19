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

add_executable(mirage Mirage/main.cpp Mirage/mirage.hpp Mirage/face_pipeline.cpp Mirage/pipeline_control_delegate.cpp)

if(APPLE)
    include_directories(/usr/local/include ~/PaalMaxima/onnxruntime/include SYSTEM)
    include_directories(~/PaalMaxima/onnxruntime/include/onnxruntime/core/session)

    target_link_directories(Facade PUBLIC
            /Applications/Facade.app/Contents/Frameworks
            /Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework)
    target_link_libraries(Facade facade Boost::program_options)

    target_link_directories(mirage PUBLIC
            /Applications/Facade.app/Contents/Frameworks
            /Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework
            ~/PaalMaxima/onnxruntime/build/MacOS/RelWithDebInfo
            /usr/local/lib)
    target_link_libraries(mirage facade ${OpenCV_LIBS} tbb onnxruntime)
endif()