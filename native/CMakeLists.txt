# Builds libdinor_core.so for Dart FFI (DynamicLibrary.open('libdinor_core.so')).
cmake_minimum_required(VERSION 3.18)
project(dinor_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

add_library(dinor_core SHARED src/dinor_core.cpp)
target_include_directories(dinor_core PUBLIC src)
target_compile_options(dinor_core PRIVATE -Wall -Wextra)
