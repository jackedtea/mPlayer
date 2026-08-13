# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(mplayer LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "mPlayer")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# --- Full libmpv ------------------------------------------------------------
#
# media_kit_libs_windows_video bundles a deliberately trimmed libmpv (its
# repository is literally named libmpv-win32-*video*-build) whose FFmpeg is
# built without subtitle decoders. Image-based subtitles therefore fail with
#
#   [error] sub: Could not find subtitle decoder for format 'hdmv_pgs_subtitle'
#
# which is media-kit/media-kit#1269. The decoder is named `pgssub`; the string
# `hdmv_pgs_subtitle` is only the codec descriptor and is present either way,
# so do not use it to check whether a build is complete.
#
# This fetches a complete upstream build and installs it *after* the plugin's
# copy, overwriting it. Downloaded rather than vendored so the repository does
# not carry a ~120 MB binary; the guard makes it a one-time cost per build dir.
#
# LICENCE: these builds are GPL, not LGPL like the trimmed one. That is fine
# precisely because mPlayer is GPL-3.0-or-later — see README's third-party
# table. It would not be fine for a permissively licensed app.
set(FULL_LIBMPV_ARCHIVE "mpv-dev-x86_64-20260812-git-f4d13e1c2c.7z")
set(FULL_LIBMPV_URL
  "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/20260812/${FULL_LIBMPV_ARCHIVE}")
set(FULL_LIBMPV_SHA256
  "f3cbd91e8f275a119e95ce4b458dd62768b5b571b3c1ad12aff430a4a85290da")
set(FULL_LIBMPV_DIR "${CMAKE_BINARY_DIR}/libmpv-full")

if(NOT EXISTS "${FULL_LIBMPV_DIR}/libmpv-2.dll")
  message(STATUS "Downloading full libmpv (subtitle decoders): ${FULL_LIBMPV_URL}")
  file(DOWNLOAD
    "${FULL_LIBMPV_URL}"
    "${FULL_LIBMPV_DIR}/${FULL_LIBMPV_ARCHIVE}"
    EXPECTED_HASH "SHA256=${FULL_LIBMPV_SHA256}"
    TLS_VERIFY ON
    SHOW_PROGRESS)
  file(ARCHIVE_EXTRACT
    INPUT "${FULL_LIBMPV_DIR}/${FULL_LIBMPV_ARCHIVE}"
    DESTINATION "${FULL_LIBMPV_DIR}")
endif()

if(NOT EXISTS "${FULL_LIBMPV_DIR}/libmpv-2.dll")
  message(FATAL_ERROR
    "Full libmpv was not extracted to ${FULL_LIBMPV_DIR}. Image-based "
    "subtitles would silently fail, so this is a hard error rather than a "
    "fallback to the trimmed build.")
endif()

# Ordered after the block above so it replaces the plugin's trimmed copy.
install(FILES "${FULL_LIBMPV_DIR}/libmpv-2.dll"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
