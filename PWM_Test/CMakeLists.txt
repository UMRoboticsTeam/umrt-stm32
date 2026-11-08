cmake_minimum_required(VERSION 3.22)

#
# This file is generated only once,
# and is not re-generated if converter is called multiple times.
#
# User is free to modify the file as much as necessary
#
option(RE_SIMULATION "Build for Renode Simulation environment" ON)

set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")

# Setup compiler settings
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

set(STM32_CPU_FLAGS "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${STM32_CPU_FLAGS}" CACHE STRING "" FORCE)
set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} ${STM32_CPU_FLAGS}" CACHE STRING "" FORCE)

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${STM32_CPU_FLAGS} -T${CMAKE_CURRENT_LIST_DIR}/STM32F446RETX_FLASH.ld" CACHE STRING "" FORCE)

# Define the build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()

# Set the project name
set(CMAKE_PROJECT_NAME PWM_Test)

# Enable compile command to ease indexing with e.g. clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

# Core project settings
project(${CMAKE_PROJECT_NAME})
message("Build type: " ${CMAKE_BUILD_TYPE})

# Enable CMake support for ASM and C languages
enable_language(C ASM)

# Create an executable object type
add_executable(${CMAKE_PROJECT_NAME})

# Add STM32CubeMX generated sources
add_subdirectory(cmake/stm32cubemx)

# Link directories setup
target_link_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined library search paths
)

file(GLOB_RECURSE ECUAL_SOURCES 
    "${CMAKE_CURRENT_SOURCE_DIR}/ECUAL/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/ECUAL/*.cpp"
)

# Add sources to executable
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user sources here
    ${ECUAL_SOURCES}
    
    Core/Src/UMRT/CAN.c
    Core/Src/UMRT/messages.c
    Core/Src/UMRT/headlight_control.c
)

# Add include paths
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined include paths
    ECUAL
    ECUAL/inc
    ECUAL/Inc
)

# Add project symbols (macros)
target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined symbols
)

if(RE_SIMULATION)
    target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE RE_SIMULATION)
    message(STATUS ">>> RENODE SIMULATION FLAG IS ACTIVE (-DRE_SIMULATION) <<<")
else()
    target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE REAL_HARDWARE)
    message(STATUS ">>> BUILDING FOR PHYSICAL REAL HARDWARE (-DREAL_HARDWARE) <<<")
endif()

# Remove wrong libob.a library dependency when using cpp files
list(REMOVE_ITEM CMAKE_C_IMPLICIT_LINK_LIBRARIES ob)

# Add linked libraries
target_link_libraries(${CMAKE_PROJECT_NAME}
    stm32cubemx

    # Add user defined libraries
)
