cmake_minimum_required(VERSION 4.1.2)

project(caro CXX)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(PROJECT_IS_TOP_LEVEL OFF)

# Vulkan 1.4.328
set(VULKAN_VER_MAJOR 1)
set(VULKAN_VER_MINOR 4)
set(VULKAN_VER_PATCH 328)
set(VULKAN_VERSION ${VULKAN_VER_MAJOR}.${VULKAN_VER_MINOR}.${VULKAN_VER_PATCH})

# Vulkan C Headers
add_subdirectory(external/Vulkan-Headers)

# Vulkan C++ Headers
add_subdirectory(external/Vulkan-Hpp)

# Define a library for Vulkan
add_library(vulkan INTERFACE)
target_include_directories(vulkan INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/external/Vulkan-Hpp
)
target_link_libraries(vulkan INTERFACE Vulkan::Headers)

# Main executable
add_executable(${PROJECT_NAME} src/main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE vulkan)
