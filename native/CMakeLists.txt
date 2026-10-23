cmake_minimum_required(VERSION 3.10)
project(dinor_core)
add_library(dinor_core SHARED src/dinor_core.cpp)
target_compile_options(dinor_core PRIVATE -fvisibility=hidden)
