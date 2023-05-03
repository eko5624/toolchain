SET(CMAKE_SYSTEM_NAME Windows)
SET(CMAKE_SYSTEM_PROCESSOR x86_64)

SET(CROSS $ENV{M_CROSS})
SET(TOP $ENV{TOP_DIR})

SET(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
SET(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
SET(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
SET(CMAKE_ASM_COMPILER x86_64-w64-mingw32-as)
SET(CMAKE_RANLIB x86_64-w64-mingw32-ranlib)

LIST(APPEND CMAKE_PROGRAM_PATH ${CROSS}/bin ...)
SET(CMAKE_FIND_ROOT_PATH ${CROSS}/mingw)
SET(CMAKE_INSTALL_PREFIX ${TOP}/opt)

SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
