set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(triple x86_64-w64-mingw32)

set(CMAKE_C_COMPILER $M_CROSS/bin/${triple}-gcc)
set(CMAKE_CXX_COMPILER $M_CROSS/bin/${triple}-g++)
set(CMAKE_RC_COMPILER $M_CROSS/bin/${triple}-windres)
set(CMAKE_RANLIB $M_CROSS/bin/${triple}-ranlib)
set(CMAKE_AR $M_CROSS/bin/${triple}-ar)
set(CMAKE_ASM_COMPILER $M_CROSS/bin/${triple}-as)

set(CMAKE_FIND_ROOT_PATH $M_CROSS/opt)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
