cmake_minimum_required(VERSION 3.20)
project(jvmstats CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(jvmstats SHARED src/jvmstats.cpp)
target_include_directories(jvmstats PUBLIC src)
target_compile_options(jvmstats PRIVATE -O2 -Wall)

install(TARGETS jvmstats LIBRARY DESTINATION lib)
install(FILES src/jvmstats.h DESTINATION include)
