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

-- Could NOT find LibGcrypt (missing: LibGcrypt_INCLUDE_DIRS LibGcrypt_LIBRARIES) 
-- Warning: Property DESCRIPTION for package LibGcrypt already set to "General purpose crypto library based on the code used in GnuPG.", overriding it with "A general purpose cryptographic library"
CMake Warning (dev) at cmake/Modules/LibtorrentMacros.cmake:43 (find_package):
  Policy CMP0167 is not set: The FindBoost module is removed.  Run "cmake
  --help-policy CMP0167" for policy details.  Use the cmake_policy command to
  set the policy and suppress this warning.

Call Stack (most recent call first):
  CMakeLists.txt:811 (find_public_dependency)
This warning is for project developers.  Use -Wno-dev to suppress it.

-- Warning: Property URL already set to "http://directory.fsf.org/wiki/Libgcrypt", overriding it with "https://www.gnupg.org/software/libgcrypt/index.html"
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

-- The following RECOMMENDED packages have not been found:

 * LibGcrypt, A general purpose cryptographic library, <https://www.gnupg.org/software/libgcrypt/index.html>
   Use GCrypt instead of the built-in functions for RC4 and SHA1

-- Configuring done (18.4s)
CMake Warning:
-- Generating done (0.0s)
  Manually-specified variables were not used by the project:
-- Build files have been written to: /Users/runner/work/dixploreswift1/dixploreswift1/DirXploreNative/libtorrent-build

    CMAKE_DISABLE_FIND_PACKAGE_Python3
    CMAKE_DISABLE_FIND_PACKAGE_TryDecode


Command line invocation:
    /Applications/Xcode_16.app/Contents/Developer/usr/bin/xcodebuild -project libtorrent-build/libtorrent.xcodeproj -scheme libtorrent -sdk iphoneos -configuration Release build CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CLANG_CXX_LANGUAGE_STANDARD=c++14 "HEADER_SEARCH_PATHS=/Users/runner/work/dixploreswift1/dixploreswift1/DirXploreNative/Thirdparty/libtorrent/include /opt/homebrew/opt/boost/include"

User defaults from command line:
    IDEPackageSupportUseBuiltinSCM = YES

Build settings from command line:
    CLANG_CXX_LANGUAGE_STANDARD = c++14
    CODE_SIGN_IDENTITY = 
    CODE_SIGNING_REQUIRED = NO
    HEADER_SEARCH_PATHS = /Users/runner/work/dixploreswift1/dixploreswift1/DirXploreNative/Thirdparty/libtorrent/include /opt/homebrew/opt/boost/include
    SDKROOT = iphoneos18.0

2026-07-07 10:41:00.990 xcodebuild[3825:13494] Writing error result bundle to /var/folders/k8/j7r3p6cx43xdqhzy2rmp6tqr0000gn/T/ResultBundle_2026-07-07_10-41-0000.xcresult
xcodebuild: error: The project named "libtorrent" does not contain a scheme named "libtorrent". The "-list" option can be used to find the names of the schemes in the project.
Error: Process completed with exit code 65.