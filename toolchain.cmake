SET(CMAKE_SYSTEM_NAME Windows)
SET(CMAKE_SYSTEM_PROCESSOR x86_64)

SET(CROSS $ENV{M_CROSS})
SET(TOP $ENV{TOP_DIR})

SET(CMAKE_C_COMPILER /__w/toolchain-test/toolchain-test/cross/bin/x86_64-w64-mingw32-gcc)
SET(CMAKE_CXX_COMPILER /__w/toolchain-test/toolchain-test/cross/bin/x86_64-w64-mingw32-g++)
SET(CMAKE_RC_COMPILER /__w/toolchain-test/toolchain-test/cross/bin/x86_64-w64-mingw32-windres)
SET(CMAKE_ASM_COMPILER /__w/toolchain-test/toolchain-test/cross/bin/x86_64-w64-mingw32-as)
SET(CMAKE_RANLIB /__w/toolchain-test/toolchain-test/cross/bin/x86_64-w64-mingw32-ranlib)

SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
