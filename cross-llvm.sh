#!/bin/bash
set -e

TOP_DIR=$(pwd)

# worflows for clang compilation:
# llvm -> mingw's header+crt -> compiler-rt builtins -> libcxx -> openmp

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "getting source"
echo "======================="
cd $M_SOURCE
git clone https://github.com/llvm/llvm-project.git --branch llvmorg-18.1.1
cd llvm-project
git sparse-checkout set --no-cone '/*' '!*/test'
cd ..

echo "building llvm"
echo "======================="
cd $M_BUILD
mkdir llvm-build
cmake -G Ninja -H$M_SOURCE/llvm-project/llvm -B$M_BUILD/llvm-build \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_USE_LINKER=lld \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="X86;NVPTX" \
  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_LTO=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_TOOLCHAIN_TOOLS="llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf;llvm-size;llvm-cxxfilt"
cmake --build llvm-build -j$MJOBS
cmake --install llvm-build