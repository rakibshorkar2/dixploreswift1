Run bash make.sh
-- The C compiler identification is AppleClang 16.0.0.16000026
-- The CXX compiler identification is AppleClang 16.0.0.16000026
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working C compiler: /Applications/Xcode_16.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang - skipped
-- Detecting C compile features
-- Detecting C compile features - done
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Check for working CXX compiler: /Applications/Xcode_16.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++ - skipped
-- Detecting CXX compile features
-- Detecting CXX compile features - done
-- Performing Test CMAKE_HAVE_LIBC_PTHREAD
-- Performing Test CMAKE_HAVE_LIBC_PTHREAD - Success
-- Found Threads: TRUE
-- Performing Test HAVE_CXX_ATOMICS_WITHOUT_LIB
-- Performing Test HAVE_CXX_ATOMICS_WITHOUT_LIB - Success
-- Performing Test HAVE_CXX_ATOMICS8_WITHOUT_LIB
-- Performing Test HAVE_CXX_ATOMICS8_WITHOUT_LIB - Success
-- Performing Test HAVE_CXX_ATOMICS64_WITHOUT_LIB
-- Performing Test HAVE_CXX_ATOMICS64_WITHOUT_LIB - Success
CMake Warning (dev) at /opt/homebrew/share/cmake/Modules/FeatureSummary.cmake:970 (message):
  Policy CMP0183 is not set: add_feature_info() supports full Condition
  Syntax.  Run "cmake --help-policy CMP0183" for policy details.  Use the
  cmake_policy command to set the policy and suppress this warning.
Call Stack (most recent call first):
  cmake/Modules/LibtorrentMacros.cmake:10 (add_feature_info)
  CMakeLists.txt:702 (feature_option)
This warning is for project developers.  Use -Wno-dev to suppress it.

CMake Warning (dev) at /opt/homebrew/share/cmake/Modules/FeatureSummary.cmake:970 (message):
  Policy CMP0183 is not set: add_feature_info() supports full Condition
  Syntax.  Run "cmake --help-policy CMP0183" for policy details.  Use the
  cmake_policy command to set the policy and suppress this warning.
Call Stack (most recent call first):
  cmake/Modules/LibtorrentMacros.cmake:10 (add_feature_info)
  CMakeLists.txt:703 (feature_option)
This warning is for project developers.  Use -Wno-dev to suppress it.

CMake Warning (dev) at /opt/homebrew/share/cmake/Modules/FeatureSummary.cmake:970 (message):
  Policy CMP0183 is not set: add_feature_info() supports full Condition
  Syntax.  Run "cmake --help-policy CMP0183" for policy details.  Use the
  cmake_policy command to set the policy and suppress this warning.
Call Stack (most recent call first):
  cmake/Modules/LibtorrentMacros.cmake:10 (add_feature_info)
  CMakeLists.txt:704 (feature_option)
This warning is for project developers.  Use -Wno-dev to suppress it.

CMake Warning (dev) at /opt/homebrew/share/cmake/Modules/FeatureSummary.cmake:970 (message):
  Policy CMP0183 is not set: add_feature_info() supports full Condition
  Syntax.  Run "cmake --help-policy CMP0183" for policy details.  Use the
  cmake_policy command to set the policy and suppress this warning.
Call Stack (most recent call first):
  cmake/Modules/LibtorrentMacros.cmake:36 (add_feature_info)
  CMakeLists.txt:708 (target_optional_compile_definitions)
This warning is for project developers.  Use -Wno-dev to suppress it.

CMake Warning (dev) at /opt/homebrew/share/cmake/Modules/FeatureSummary.cmake:970 (message):
  Policy CMP0183 is not set: add_feature_info() supports full Condition
  Syntax.  Run "cmake --help-policy CMP0183" for policy details.  Use the
  cmake_policy command to set the policy and suppress this warning.
Call Stack (most recent call first):
  cmake/Modules/LibtorrentMacros.cmake:36 (add_feature_info)
  CMakeLists.txt:719 (target_optional_compile_definitions)
This warning is for project developers.  Use -Wno-dev to suppress it.

-- Found OpenSSL: /opt/homebrew/Cellar/openssl@3/3.6.2/lib/libcrypto.dylib (found version "3.6.2")
CMake Warning (dev) at cmake/Modules/LibtorrentMacros.cmake:43 (find_package):
  Policy CMP0167 is not set: The FindBoost module is removed.  Run "cmake
  --help-policy CMP0167" for policy details.  Use the cmake_policy command to
  set the policy and suppress this warning.

Call Stack (most recent call first):
  CMakeLists.txt:811 (find_public_dependency)
This warning is for project developers.  Use -Wno-dev to suppress it.

CMake Error at /opt/homebrew/share/cmake/Modules/FindPackageHandleStandardArgs.cmake:290 (message):
  Could NOT find Boost (missing: Boost_INCLUDE_DIR)
Call Stack (most recent call first):
  /opt/homebrew/share/cmake/Modules/FindPackageHandleStandardArgs.cmake:654 (_FPHSA_FAILURE_MESSAGE)
  /opt/homebrew/share/cmake/Modules/FindBoost.cmake:2455 (find_package_handle_standard_args)
  cmake/Modules/LibtorrentMacros.cmake:43 (find_package)
  CMakeLists.txt:811 (find_public_dependency)


-- Configuring incomplete, errors occurred!
Error: Process completed with exit code 1.