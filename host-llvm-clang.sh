#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

M_ROOT=$(pwd)
M_SOURCE=$M_ROOT/source
M_BUILD=$M_ROOT/build
M_CROSS=$M_ROOT/cross

PATH="$M_CROSS/bin:$PATH"
HOST_ARCH="x86_64-unknown-linux-gnu"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "getting source"
echo "======================="
cd $M_SOURCE

#llvm
#git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
  cd llvm-project
  git sparse-checkout set --no-cone '/*' '!*/test' '!/lldb' '!/mlir' '!/clang-tools-extra' '!/polly' '!/libc' '!/flang'
  cd ..
fi

echo "building llvm-compiler-rt-builtin"
echo "======================="
cd $M_BUILD
rm -rf builtins-build && mkdir builtins-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$(clang --print-resource-dir)" \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_C_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_CXX_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_ASM_COMPILER_TARGET=${HOST_ARCH} \
  -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_ARCH} \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=TRUE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DLLVM_CONFIG_PATH='' \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS \
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
  -DCMAKE_INSTALL_PREFIX=$M_CROSS \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_CXX_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_ASM_COMPILER_TARGET=${HOST_ARCH} \
  -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_ARCH} \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLLVM_PATH=$M_SOURCE/llvm-project/llvm \
  -DLIBUNWIND_USE_COMPILER_RT=TRUE \
  -DLIBUNWIND_ENABLE_SHARED=OFF \
  -DLIBUNWIND_ENABLE_STATIC=ON \
  -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXX_ENABLE_SHARED=OFF \
  -DLIBCXX_ENABLE_STATIC=ON \
  -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
  -DLIBCXX_CXX_ABI=libcxxabi \
  -DLIBCXX_LIBDIR_SUFFIX='' \
  -DLIBCXX_INCLUDE_TESTS=FALSE \
  -DLIBCXXABI_INCLUDE_TESTS=FALSE \
  -DLIBUNWIND_INCLUDE_TESTS=FALSE \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_LIBDIR_SUFFIX='' \
  -DCMAKE_C_FLAGS="-pipe -ffp-contract=fast -ftls-model=local-exec -flto=thin -fsplit-lto-unit -fwhole-program-vtables -fdata-sections -ffunction-sections" \
  -DCMAKE_CXX_FLAGS="-pipe -ffp-contract=fast -ftls-model=local-exec -flto=thin -fsplit-lto-unit -fwhole-program-vtables -fdata-sections -ffunction-sections" \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld -Xlinker -s -Xlinker --icf=all -Xlinker --gc-sections"
cmake --build libcxx-build -j$MJOBS
cmake --install libcxx-build

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
rm -rf compiler-rt-build && mkdir compiler-rt-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$(clang --print-resource-dir)" \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_C_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_CXX_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_ASM_COMPILER_TARGET=${HOST_ARCH} \
  -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_ARCH} \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=FALSE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DLLVM_CONFIG_PATH='' \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++ \
  -DCMAKE_EXE_LINKER_FLAGS_INIT='-lc++abi' \
  -DCOMPILER_RT_BUILD_SANITIZERS=OFF
cmake --build compiler-rt-build -j$MJOBS
cmake --install compiler-rt-build
