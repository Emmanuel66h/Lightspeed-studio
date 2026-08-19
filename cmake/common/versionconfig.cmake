# OBS CMake common version helper module

include_guard(GLOBAL)

# ============================================================
# Lightspeed Studio version handling
# ============================================================
#
# The Lightspeed Studio repository may not contain the original
# OBS release tags. In that case:
#
#     git describe --always --tags
#
# can return a commit hash such as:
#
#     6260d73c2
#
# which is not a valid CMake project version.
#
# We therefore support OBS_VERSION_OVERRIDE from either:
#
#   1. A CMake variable:
#        -DOBS_VERSION_OVERRIDE=30.0.0-lightspeed
#
#   2. The environment:
#        OBS_VERSION_OVERRIDE=30.0.0-lightspeed
#
# ============================================================

set(_obs_version ${_obs_default_version})
set(_obs_version_canonical ${_obs_default_version})

# Read version override from environment if CMake variable
# was not already supplied.
if(NOT DEFINED OBS_VERSION_OVERRIDE AND DEFINED ENV{OBS_VERSION_OVERRIDE})
  set(OBS_VERSION_OVERRIDE "$ENV{OBS_VERSION_OVERRIDE}")
endif()

# ============================================================
# Determine OBS version
# ============================================================

if(DEFINED OBS_VERSION_OVERRIDE)

  if(OBS_VERSION_OVERRIDE MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+(-.*)?$")

    string(
      REGEX REPLACE
      "^([0-9]+)\\.([0-9]+)\\.([0-9]+).*$"
      "\\1;\\2;\\3"
      _obs_version_canonical
      "${OBS_VERSION_OVERRIDE}"
    )

    set(_obs_version "${OBS_VERSION_OVERRIDE}")

  else()

    message(
      FATAL_ERROR
      "Invalid OBS_VERSION_OVERRIDE supplied: '${OBS_VERSION_OVERRIDE}'. "
      "Expected <MAJOR>.<MINOR>.<PATCH>[-suffix]."
    )

  endif()

# ============================================================
# Automatically discover version from Git
# ============================================================

elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")

  execute_process(
    COMMAND git describe --always --tags --dirty=-modified
    OUTPUT_VARIABLE _obs_version
    ERROR_VARIABLE _git_describe_err
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    RESULT_VARIABLE _obs_version_result
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  if(_git_describe_err)
    message(
      FATAL_ERROR
      "Could not fetch OBS version tag from git.\n${_git_describe_err}"
    )
  endif()

  if(_obs_version_result EQUAL 0)

    string(
      REGEX REPLACE
      "([0-9]+)\\.([0-9]+)\\.([0-9]+).*"
      "\\1;\\2;\\3"
      _obs_version_canonical
      "${_obs_version}"
    )

  endif()

endif()

# ============================================================
# Validate canonical version
# ============================================================

list(LENGTH _obs_version_canonical _obs_version_canonical_length)

if(NOT _obs_version_canonical_length EQUAL 3)

  message(
    FATAL_ERROR
    "Unable to determine a valid OBS version. "
    "Detected version: '${_obs_version}'. "
    "Expected <MAJOR>.<MINOR>.<PATCH>."
  )

endif()

# ============================================================
# Set beta / release candidate versions
# ============================================================

if(_obs_version MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+-rc[0-9]+")

  string(
    REGEX REPLACE
    "^[0-9]+\\.[0-9]+\\.[0-9]+-rc([0-9]+).*$"
    "\\1"
    _obs_release_candidate
    "${_obs_version}"
  )

elseif(_obs_version MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+-beta[0-9]+")

  string(
    REGEX REPLACE
    "^[0-9]+\\.[0-9]+\\.[0-9]+-beta([0-9]+).*$"
    "\\1"
    _obs_beta
    "${_obs_version}"
  )

endif()

# ============================================================
# Set version components
# ============================================================

list(GET _obs_version_canonical 0 OBS_VERSION_MAJOR)
list(GET _obs_version_canonical 1 OBS_VERSION_MINOR)
list(GET _obs_version_canonical 2 OBS_VERSION_PATCH)

set(OBS_RELEASE_CANDIDATE ${_obs_release_candidate})
set(OBS_BETA ${_obs_beta})

string(
  REPLACE ";"
  "."
  OBS_VERSION_CANONICAL
  "${_obs_version_canonical}"
)

string(
  REPLACE ";"
  "."
  OBS_VERSION
  "${_obs_version}"
)

# ============================================================
# Display version information
# ============================================================

message(STATUS "OBS Studio version: ${OBS_VERSION}")
message(STATUS "OBS Studio canonical version: ${OBS_VERSION_CANONICAL}")
message(STATUS "OBS Studio major: ${OBS_VERSION_MAJOR}")
message(STATUS "OBS Studio minor: ${OBS_VERSION_MINOR}")
message(STATUS "OBS Studio patch: ${OBS_VERSION_PATCH}")

if(OBS_RELEASE_CANDIDATE GREATER 0)

  message(
    AUTHOR_WARNING
    "******************************************************************************\n"
    "  + OBS-Studio - Release candidate detected, OBS_VERSION is now: ${OBS_VERSION}\n"
    "******************************************************************************"
  )

elseif(OBS_BETA GREATER 0)

  message(
    AUTHOR_WARNING
    "******************************************************************************\n"
    "  + OBS-Studio - Beta detected, OBS_VERSION is now: ${OBS_VERSION}\n"
    "******************************************************************************"
  )

endif()

# ============================================================
# Cleanup
# ============================================================

unset(_obs_default_version)
unset(_obs_version)
unset(_obs_version_canonical)
unset(_obs_version_canonical_length)
unset(_obs_release_candidate)
unset(_obs_beta)
unset(_obs_version_result)
unset(_git_describe_err)