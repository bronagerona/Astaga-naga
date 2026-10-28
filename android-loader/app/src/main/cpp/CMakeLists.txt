cmake_minimum_required(VERSION 3.22.1)
project(zenia_llama LANGUAGES C CXX)
include(FetchContent)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
FetchContent_Declare(llama_cpp
    GIT_REPOSITORY https://github.com/ggerganov/llama.cpp.git
    GIT_TAG b4510
    GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(llama_cpp)
add_library(zenia-llama SHARED native-lib.cpp)
target_compile_features(zenia-llama PRIVATE cxx_std_17)
target_link_libraries(zenia-llama PRIVATE llama android log)
