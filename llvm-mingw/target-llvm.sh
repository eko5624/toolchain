#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh

# worflows for clang compilation:
# llvm -> mingw's header+crt -> compiler-rt builtins -> libcxx -> openmp

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross
export M_TARGET=$M_ROOT/target

export MINGW_TRIPLE="x86_64-w64-mingw32"
export TOOLCHAIN_ARCHS="x86_64"
export TOOLCHAIN_TARGET_OSES="mingw32"
export PATH="$M_CROSS/bin:$PATH"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "getting source"
echo "======================="
cd $M_SOURCE

#llvm
#git clone https://github.com/llvm/llvm-project.git --branch release/18.x llvmorg-$VER_LLVM
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
fi

#llvm-mingw
#git clone https://github.com/mstorsjo/llvm-mingw.git --branch master

echo "building llvm"
echo "======================="
cd $M_BUILD
mkdir llvm-build
cmake -G Ninja -H$M_SOURCE/llvm-project/llvm -B$M_BUILD/llvm-build \
  -DCMAKE_INSTALL_PREFIX=$M_TARGET \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
  -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
  -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
  -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DLLVM_HOST_TRIPLE=$MINGW_TRIPLE \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="X86;NVPTX" \
  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_LTO=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DCLANG_DEFAULT_RTLIB=compiler-rt \
  -DCLANG_DEFAULT_UNWINDLIB=libunwind \
  -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
  -DCLANG_DEFAULT_LINKER=lld \
  -DLLD_DEFAULT_LD_LLD_IS_MINGW=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf;llvm-size;llvm-cxxfilt"
cmake --build llvm-build -j$MJOBS
cmake --install llvm-build --strip