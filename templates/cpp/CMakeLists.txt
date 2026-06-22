cmake_minimum_required(VERSION 3.27)

project(cpp_template VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(cpp-template src/main.cpp)
target_compile_features(cpp-template PRIVATE cxx_std_20)
target_compile_options(
  cpp-template
  PRIVATE $<$<CXX_COMPILER_ID:Clang,GNU>:-Wall -Wextra -Wpedantic>)

install(TARGETS cpp-template RUNTIME DESTINATION bin)
