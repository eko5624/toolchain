#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh

# worflows for clang compilation:
# llvm -> mingw's header+crt -> compiler-rt builtins -> libcxx -> openmp

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

M_ROOT=$(pwd)
M_SOURCE=$M_ROOT/source

unset HOST
BUILDDIR="build"
LINK_DYLIB=ON
CLANG_TOOLS_EXTRA=ON
INSTRUMENTED=OFF
M_HOST=$M_ROOT/host

while [ $# -gt 0 ]; do
    case "$1" in
    --with-clang)
        WITH_CLANG=1
        BUILDDIR="$BUILDDIR-withclang"
        ;;
    --use-linker=*)
        USE_LINKER="${1#*=}"
        ;;
    --llvm-only)
        LLVM_ONLY=1
        ;;
    --stage1)
        STAGE1=1
        unset CLANG_TOOLS_EXTRA
        ;;
    --profile)
        unset CLANG_TOOLS_EXTRA
        PROFILE=1
        WITH_CLANG=1
        LLVM_ONLY=1
        LINK_DYLIB=OFF
        INSTRUMENTED="Frontend"
        LLVM_PROFILE_DATA_DIR="/tmp/llvm-profile"
        # A fixed BUILDDIR is set at the end for this case.
        ;;
    --pgo)
        PGO=1        
        LLVM_PROFDATA_FILE="profile.profdata"
        if [ ! -e "$LLVM_PROFDATA_FILE" ]; then
            echo Profile \"$LLVM_PROFDATA_FILE\" not found
            exit 1
        fi
        LLVM_PROFDATA_FILE="$(cd "$(dirname "$LLVM_PROFDATA_FILE")" && pwd)/$(basename "$LLVM_PROFDATA_FILE")"
        BUILDDIR="$BUILDDIR-pgo"
        ;;
    --thinlto)
        LTO="thin"
        BUILDDIR="$BUILDDIR-thinlto"
        ;;
    --host=*)
        HOST="${1#*=}"
        ;;
    *)
        if [ -n "$PREFIX" ]; then
            if [ -n "$PREFIX_PGO" ]; then
                echo Unrecognized parameter $1
                exit 1
            fi
            PREFIX_PGO="$1"
        else
            PREFIX="$1"
        fi
        ;;
    esac
    shift
done

if [ -n "$PROFILE" ]; then
    export PATH=$PREFIX/bin:$PATH
    STAGE1_PREFIX=$PREFIX
    PREFIX=/tmp/dummy-prefix
elif [ -n "$PGO" ]; then
    if [ -z "$PREFIX_PGO" ]; then
        echo Must provide a second destination for a PGO build
        exit 1
    fi
    export PATH=$PREFIX/bin:$PATH
    STAGE1_PREFIX=$PREFIX
    PREFIX=$PREFIX_PGO

    if [ -n "$LLVM_ONLY" ] && [ "$PREFIX" != "$STAGE1_PREFIX" ] ; then
        # Only rebuilding LLVM, not any runtimes. Copy the stage1 toolchain
        # and rebuild LLVM on top of it.
        rm -rf $PREFIX
        mkdir -p "$(dirname "$PREFIX")"
        cp -a "$STAGE1_PREFIX" "$PREFIX"
        # Remove the native Linux/macOS runtimes which aren't needed in
        # the final distribution.
        rm -rf "$PREFIX"/lib/clang/*/lib/linux
    fi
fi

CMAKEFLAGS="$LLVM_CMAKEFLAGS"
if [ -n "$HOST" ]; then
    ARCH="${HOST%%-*}"

    if [ -n "$WITH_CLANG" ]; then
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=clang"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=clang++"
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=${USE_LINKER:-lld}"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER_TARGET=$HOST"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER_TARGET=$HOST"
    else
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=$HOST-gcc"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=$HOST-g++"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_PROCESSOR=$ARCH"
    fi
    case $HOST in
    *-mingw32)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Windows"
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_RC_COMPILER=$HOST-windres"
        ;;
    *-linux*)
        CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_SYSTEM_NAME=Linux"
        ;;
    *)
        echo "Unrecognized host $HOST"
        exit 1
        ;;
    esac

    CROSS_ROOT=$(cd $(dirname $(command -v $HOST-gcc))/../$HOST && pwd)
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH=$CROSS_ROOT"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"
    BUILDDIR=$BUILDDIR-$HOST
elif [ -n "$WITH_CLANG" ]; then
    # Build using clang and lld (from $PATH), rather than the system default
    # tools.
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_C_COMPILER=clang"
    CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_CXX_COMPILER=clang++"
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=${USE_LINKER:-lld}"
else
    # Native compilation with the system default compiler.

    # Use a faster linker, if available.
    if [ -n "$USE_LINKER" ]; then
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=$USE_LINKER"
    elif command -v ld.lld >/dev/null; then
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=lld"
    elif command -v ld.gold >/dev/null; then
        CMAKEFLAGS="$CMAKEFLAGS -DLLVM_USE_LINKER=gold"
    fi
fi   

if [ -n "$LTO" ]; then
    CMAKEFLAGS="$CMAKEFLAGS -DLLVM_ENABLE_LTO=$LTO"
fi

if [ "$INSTRUMENTED" != "OFF" ]; then
    # For instrumented build, use a hardcoded builddir that we can
    # locate, and don't install the built files.
    BUILDDIR="build-instrumented"
fi

TOOLCHAIN_ONLY=ON
if [ -n "$FULL_LLVM" ]; then
    TOOLCHAIN_ONLY=OFF
fi

PROJECTS="clang;lld"
if [ -n "$CLANG_TOOLS_EXTRA" ]; then
    PROJECTS="$PROJECTS;clang-tools-extra"
fi

mkdir -p $M_SOURCE

echo "getting source"
echo "======================="
cd $M_SOURCE
#git clone https://github.com/llvm/llvm-project.git --branch release/18.x llvmorg-$VER_LLVM
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
fi

echo "building llvm"
echo "======================="
cd llvm-project/llvm
rm -rf $BUILDDIR && mkdir -p $BUILDDIR
cd $BUILDDIR
cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_USE_LINKER=lld \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_PROJECTS=$PROJECTS \
  -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86;NVPTX" \
  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_LTO=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_LINK_LLVM_DYLIB=$LINK_DYLIB \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLDB_ENABLE_PYTHON=OFF \
  -DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf;llvm-size;llvm-cxxfilt;llvm-lib" \
  ${HOST+-DLLVM_HOST_TRIPLE=$HOST} \
  -DLLVM_BUILD_INSTRUMENTED=$INSTRUMENTED \
  ${LLVM_PROFILE_DATA_DIR+-DLLVM_PROFILE_DATA_DIR=$LLVM_PROFILE_DATA_DIR} \
  ${LLVM_PROFDATA_FILE+-DLLVM_PROFDATA_FILE=$LLVM_PROFDATA_FILE} \
  $CMAKEFLAGS \
  ..

if [ "$INSTRUMENTED" != "OFF" ]; then
    # For instrumented builds, don't install the built files (so $PREFIX
    # is entirely unused).
    cmake --build . -j$MJOBS --target clang --target lld
else
    cmake --build . -j$MJOBS
    cmake --install . --strip
    cp ../LICENSE.TXT $PREFIX
fi    
