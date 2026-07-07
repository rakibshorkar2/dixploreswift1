Run BOOST_DIR=$(brew --prefix boost)
  
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
-- Found GnuTLS: /opt/homebrew/opt/gnutls/lib/libgnutls.dylib (found version "3.8.13")
CMake Warning (dev) at cmake/Modules/LibtorrentMacros.cmake:43 (find_package):
  Policy CMP0167 is not set: The FindBoost module is removed.  Run "cmake
  --help-policy CMP0167" for policy details.  Use the cmake_policy command to
  set the policy and suppress this warning.
Call Stack (most recent call first):
  CMakeLists.txt:811 (find_public_dependency)
This warning is for project developers.  Use -Wno-dev to suppress it.
-- Found Boost: /opt/homebrew/opt/boost/include (found version "1.90.0")
-- The following features have been enabled:
 * dht, enable support for Mainline DHT
 * deprecated-functions, enable deprecated functions for backwards compatibility
 * encryption, Enables encryption in libtorrent
 * exceptions, build with exception support
 * extensions, Enables protocol extensions
 * i2p, build with I2P support
 * logging, build with logging
 * mutable-torrents, Enables mutable torrent support
 * streaming, Enables support for piece deadline
-- The following RECOMMENDED packages have been found:
 * GnuTLS, GnuTLS is a free software implementation of the TLS and DTLS protocols, <https://www.gnutls.org/>
   Provides HTTPS support to libtorrent
-- The following REQUIRED packages have been found:
 * Threads
 * Boost
-- The following features have been disabled:
 * BUILD_SHARED_LIBS, build libtorrent as a shared library
 * static_runtime, build libtorrent with static runtime
 * build_tests, build tests
 * build_examples, build examples
 * build_tools, build tools
 * python-bindings, build python bindings
 * python-egg-info, generate python egg info
 * python-install-system-dir, Install python bindings to the system installation directory rather than the CMake installation prefix
 * gnutls, build using GnuTLS instead of OpenSSL
-- Configuring done (53.7s)
CMake Error at CMakeLists.txt:547 (add_library):
  Cannot find source file:
    deps/try_signal/try_signal.cpp
  Tried extensions .c .C .c++ .cc .cpp .cxx .cu .mpp .m .M .mm .ixx .cppm
  .ccm .cxxm .c++m .h .hh .h++ .hm .hpp .hxx .in .txx .f .F .for .f77 .f90
  .f95 .f03 .hip .ispc
CMake Error at CMakeLists.txt:547 (add_library):
  No SOURCES given to target: torrent-rasterbar
CMake Generate step failed.  Build files cannot be regenerated correctly.
Error: Process completed with exit code 1.
