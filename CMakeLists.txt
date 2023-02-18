cmake_minimum_required(VERSION 3.24)
project(Facade CXX)

set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 17)

find_package(Boost COMPONENTS program_options REQUIRED)

include_directories(.)
include_directories(Include)

add_executable(Facade
        Include/facade.h CLI/main.cpp CLI/commands.cpp CLI/commands.hpp)

if(APPLE)
    target_link_directories(Facade PUBLIC
            /Applications/Facade.app/Contents/Frameworks
            /Applications/Facade.app/Contents/Frameworks/libfacade.dylib.framework)
    target_link_libraries(Facade facade Boost::program_options)
endif()