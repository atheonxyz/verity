cmake_minimum_required(VERSION 3.14)
project(verity_dispatch C)

add_library(verity_dispatch STATIC
    verity_dispatch.c
    backends/pk_backend.c
    backends/bb_backend.c
)

target_include_directories(verity_dispatch
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/../include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
)

# Backend symbols (pk_*, bb_*) are resolved at link time from
# the pre-built static libraries (xcframework, .so, etc.).
# No additional link targets needed here.
