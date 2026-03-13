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

PREFIX="$1"
ORIG_PATH="$PATH"
export PATH="$PREFIX/bin:$PATH"
CLANG_RESOURCE_DIR="$(clang --print-resource-dir)"
INSTALL_PREFIX="$CLANG_RESOURCE_DIR"

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

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
mkdir compiler-rt-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$CLANG_RESOURCE_DIR" \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_AR=$PREFIX/bin/llvm-ar \
  -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-unknown-linux-gnu \
  -DCMAKE_CXX_COMPILER_TARGET=x86_64-unknown-linux-gnu \
  -DCMAKE_ASM_COMPILER_TARGET=x86_64-unknown-linux-gnu \
  -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-gnu \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$PREFIX \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DCOMPILER_RT_USE_LIBCXX=OFF
cmake --build compiler-rt-build -j$MJOBS
cmake --install compiler-rt-build --prefix "$INSTALL_PREFIX"
rm -rf compiler-rt-build