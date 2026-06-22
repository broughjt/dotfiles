cmake_minimum_required(VERSION 3.27)

project(c_template VERSION 0.1.0 LANGUAGES C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(c-template src/main.c)
target_compile_features(c-template PRIVATE c_std_17)
target_compile_options(
  c-template
  PRIVATE $<$<C_COMPILER_ID:Clang,GNU>:-Wall -Wextra -Wpedantic>)

install(TARGETS c-template RUNTIME DESTINATION bin)
