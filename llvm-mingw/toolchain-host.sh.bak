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
  git clone https://github.com/llvm/llvm-project.git --branch release/22.x
fi

echo "building llvm-compiler-rt-builtin"
echo "======================="
cd $M_BUILD
rm -rf builtins-build && mkdir builtins-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
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
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=TRUE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH="$PREFIX" \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++
cmake --build builtins-build -j$MJOBS
cmake --install builtins-build

echo "building llvm-libcxx"
echo "======================="
cd $M_BUILD
rm -rf libcxx-build && mkdir libcxx-build
cmake -G Ninja -H$M_SOURCE/llvm-project/runtimes -B$M_BUILD/libcxx-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
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
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLIBUNWIND_USE_COMPILER_RT=TRUE \
  -DLIBUNWIND_ENABLE_SHARED=ON \
  -DLIBUNWIND_ENABLE_STATIC=ON \
  -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXX_ENABLE_SHARED=ON \
  -DLIBCXX_ENABLE_STATIC=ON \
  -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
  -DLIBCXX_CXX_ABI=libcxxabi \
  -DLIBCXX_LIBDIR_SUFFIX="" \
  -DLIBCXX_INCLUDE_TESTS=FALSE \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_LIBDIR_SUFFIX=""
cmake --build libcxx-build -j$MJOBS
cmake --install libcxx-build

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
rm -rf compiler-rt-build && mkdir compiler-rt-build
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
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=FALSE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$PREFIX \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++
cmake --build compiler-rt-build
cmake --install compiler-rt-build

