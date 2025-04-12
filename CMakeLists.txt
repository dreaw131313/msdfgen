
cmake_minimum_required(VERSION 3.15)
include(cmake/version.cmake)

option(MSDFGEN_CORE_ONLY "Only build the core library with no dependencies" OFF)
option(MSDFGEN_BUILD_STANDALONE "Build the msdfgen standalone executable" OFF)
option(MSDFGEN_USE_VCPKG "Use vcpkg package manager to link project dependencies" OFF)
option(MSDFGEN_USE_OPENMP "Build with OpenMP support for multithreaded code" OFF)
option(MSDFGEN_USE_CPP11 "Build with C++11 enabled" ON)
option(MSDFGEN_INSTALL "Generate installation target" OFF)
option(MSDFGEN_DYNAMIC_RUNTIME "Link dynamic runtime library instead of static" ON)
option(BUILD_SHARED_LIBS "Generate dynamic library files instead of static" OFF)

if(MSDFGEN_CORE_ONLY AND MSDFGEN_USE_VCPKG)
    message(STATUS "Option MSDFGEN_USE_VCPKG ignored due to MSDFGEN_CORE_ONLY - core has no dependencies")
    set(MSDFGEN_USE_VCPKG OFF)
endif()

get_property(MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT MULTI_CONFIG AND NOT CMAKE_BUILD_TYPE)
    message(STATUS "CMAKE_BUILD_TYPE not set, defaulting to Release")
    set(CMAKE_BUILD_TYPE Release)
endif()

if(MSDFGEN_DYNAMIC_RUNTIME)
    set(MSDFGEN_MSVC_RUNTIME "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
else()
    set(MSDFGEN_MSVC_RUNTIME "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

if(BUILD_SHARED_LIBS)
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

# Version is specified in vcpkg.json
project(msdfgen VERSION ${MSDFGEN_VERSION} LANGUAGES CXX)

if(MAX_WARNING_LEVEL)
    if (MSVC)
        add_compile_options(/W4)
    else()
        add_compile_options(-Wall -Wextra -Wpedantic)
    endif()
endif()

file(GLOB_RECURSE MSDFGEN_CORE_HEADERS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "core/*.h" "core/*.hpp")
file(GLOB_RECURSE MSDFGEN_CORE_SOURCES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "core/*.cpp")
file(GLOB_RECURSE MSDFGEN_EXT_HEADERS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "ext/*.h" "ext/*.hpp")
file(GLOB_RECURSE MSDFGEN_EXT_SOURCES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "ext/*.cpp" "lib/*.cpp")

# Core library
add_library(msdfgen-core "${CMAKE_CURRENT_SOURCE_DIR}/msdfgen.h" ${MSDFGEN_CORE_HEADERS} ${MSDFGEN_CORE_SOURCES})
add_library(msdfgen::msdfgen-core ALIAS msdfgen-core)
set_target_properties(msdfgen-core PROPERTIES PUBLIC_HEADER "${MSDFGEN_CORE_HEADERS}")
set_property(TARGET msdfgen-core PROPERTY MSVC_RUNTIME_LIBRARY "${MSDFGEN_MSVC_RUNTIME}")
target_compile_definitions(msdfgen-core PUBLIC
    MSDFGEN_VERSION=${MSDFGEN_VERSION}
    MSDFGEN_VERSION_MAJOR=${MSDFGEN_VERSION_MAJOR}
    MSDFGEN_VERSION_MINOR=${MSDFGEN_VERSION_MINOR}
    MSDFGEN_VERSION_REVISION=${MSDFGEN_VERSION_REVISION}
    MSDFGEN_COPYRIGHT_YEAR=${MSDFGEN_COPYRIGHT_YEAR}
)
target_include_directories(msdfgen-core INTERFACE
    $<INSTALL_INTERFACE:include/msdfgen>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/>
)
set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT msdfgen-core)

if(MSDFGEN_USE_CPP11)
    target_compile_features(msdfgen-core PUBLIC cxx_std_11)
    target_compile_definitions(msdfgen-core PUBLIC MSDFGEN_USE_CPP11)
endif()

if(MSDFGEN_USE_OPENMP)
    # Note: Clang doesn't support OpenMP by default...
    find_package(OpenMP REQUIRED COMPONENTS CXX)
    target_compile_definitions(msdfgen-core PUBLIC MSDFGEN_USE_OPENMP)
    target_link_libraries(msdfgen-core PUBLIC OpenMP::OpenMP_CXX)
endif()

if(BUILD_SHARED_LIBS AND WIN32)
    target_compile_definitions(msdfgen-core PRIVATE "MSDFGEN_PUBLIC=__declspec(dllexport)")
    target_compile_definitions(msdfgen-core INTERFACE "MSDFGEN_PUBLIC=__declspec(dllimport)")
else()
    target_compile_definitions(msdfgen-core PUBLIC MSDFGEN_PUBLIC=)
endif()

# Extensions library
if(NOT MSDFGEN_CORE_ONLY)
    
	set(FT_DISABLE_ZLIB ON)
	set(FT_DISABLE_BZIP2 ON)
	set(FT_DISABLE_PNG ON)
	set(FT_DISABLE_HARFBUZZ ON)
	set(FT_DISABLE_BROTLI ON)
	set(tinyxml2_BUILD_TESTING OFF)
	
	add_subdirectory(Libraries/freetype)
	add_subdirectory(Libraries/tinyxml2)


    add_library(msdfgen-ext "${CMAKE_CURRENT_SOURCE_DIR}/msdfgen-ext.h" ${MSDFGEN_EXT_HEADERS} ${MSDFGEN_EXT_SOURCES})
    add_library(msdfgen::msdfgen-ext ALIAS msdfgen-ext)
    set_target_properties(msdfgen-ext PROPERTIES PUBLIC_HEADER "${MSDFGEN_EXT_HEADERS}")
    set_property(TARGET msdfgen-ext PROPERTY MSVC_RUNTIME_LIBRARY "${MSDFGEN_MSVC_RUNTIME}")
    target_compile_definitions(msdfgen-ext INTERFACE MSDFGEN_EXTENSIONS)
    
    target_compile_definitions(msdfgen-ext PUBLIC MSDFGEN_DISABLE_PNG)
		
    if(MSDFGEN_DISABLE_VARIABLE_FONTS)
        target_compile_definitions(msdfgen-ext PUBLIC MSDFGEN_DISABLE_VARIABLE_FONTS)
    endif()
	
    target_link_libraries(msdfgen-ext PRIVATE freetype msdfgen::msdfgen-core)
	target_link_libraries(msdfgen-ext PRIVATE tinyxml2)
	
    target_include_directories(msdfgen-ext
        PUBLIC
            $<INSTALL_INTERFACE:include/msdfgen>
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/include
    )
    set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT msdfgen-ext)

    if(BUILD_SHARED_LIBS AND WIN32)
        target_compile_definitions(msdfgen-ext PRIVATE "MSDFGEN_EXT_PUBLIC=__declspec(dllexport)")
        target_compile_definitions(msdfgen-ext INTERFACE "MSDFGEN_EXT_PUBLIC=__declspec(dllimport)")
    else()
        target_compile_definitions(msdfgen-ext PUBLIC MSDFGEN_EXT_PUBLIC=)
    endif()

    add_library(msdfgen-full INTERFACE)
    add_library(msdfgen::msdfgen ALIAS msdfgen-full)
    target_link_libraries(msdfgen-full INTERFACE msdfgen::msdfgen-core msdfgen::msdfgen-ext)
else()
    add_library(msdfgen::msdfgen ALIAS msdfgen-core)
endif()

# Standalone executable
if(MSDFGEN_BUILD_STANDALONE)
    set(MSDFGEN_STANDALONE_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/main.cpp")
    if(MSVC)
        set(MSDFGEN_STANDALONE_SOURCES ${MSDFGEN_STANDALONE_SOURCES} "${CMAKE_CURRENT_SOURCE_DIR}/msdfgen.rc")
    endif()
    add_executable(msdfgen ${MSDFGEN_STANDALONE_SOURCES})
    target_compile_definitions(msdfgen PUBLIC MSDFGEN_STANDALONE)
    target_compile_definitions(msdfgen PRIVATE MSDFGEN_VERSION_UNDERLINE=${MSDFGEN_VERSION_UNDERLINE})
    set_property(TARGET msdfgen PROPERTY MSVC_RUNTIME_LIBRARY "${MSDFGEN_MSVC_RUNTIME}")
    target_link_libraries(msdfgen PRIVATE msdfgen::msdfgen)
    set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT msdfgen)
endif()

# Hide ZERO_CHECK and ALL_BUILD targets
set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER meta)
