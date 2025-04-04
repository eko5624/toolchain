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

llvm_cflags="-march=native -fno-ident -fno-temp-file -fno-math-errno -ftls-model=local-exec"

PATH="$M_CROSS/bin:$PATH"
HOST_ARCH="x86_64-unknown-linux-gnu"

while [ $# -gt 0 ]; do
  case "$1" in
  --enable-pgo_gen)
      LLVM_ENABLE_PGO="GEN" #STRING "OFF, GEN, CSGEN, USE"
      ;;
  --enable-llvm-thin_lto)
      LLVM_ENABLE_LTO="Thin" #STRING "OFF, ON, Thin and Full"
      ;;
  --enable-llvm-full_lto)
      LLVM_ENABLE_LTO="Full" #STRING "OFF, ON, Thin and Full"
      ;;
  *)
    echo Unrecognized parameter $1
    exit 1
    ;;
  esac
  shift
done

if [ "$LLVM_ENABLE_LTO" == "Thin" ]; then
    llvm_lto=" -flto=thin -fwhole-program-vtables -fsplit-lto-unit"
elif [ "$LLVM_ENABLE_LTO" == "Full" ]; then
    llvm_lto=" -flto=full -fwhole-program-vtables -fsplit-lto-unit"
fi

if [ "$LLVM_ENABLE_PGO" == "GEN" ] || [ "$LLVM_ENABLE_PGO" == "CSGEN" ]; then
    LLVM_PROFILE_DATA_DIR="$PREFIX/profiles" #PATH "Default profile generation directory"
elif [ "$LLVM_ENABLE_PGO" == "USE" ]; then
    PREFIX=$M_ROOT/llvm_pgo
    LLVM_PROFDATA_FILE=$M_ROOT/llvm.profdata
fi

if [ "$LLVM_ENABLE_PGO" == "GEN" ]; then
   llvm_pgo=" -fprofile-generate=${LLVM_PROFILE_DATA_DIR} -fprofile-update=atomic -mllvm -vp-counters-per-site=8"
elif [ "$LLVM_ENABLE_PGO" == "CSGEN" ]; then
   llvm_pgo=" -fcs-profile-generate=${LLVM_PROFILE_DATA_DIR} -fprofile-update=atomic -mllvm -vp-counters-per-site=8 -fprofile-use=${LLVM_PROFDATA_FILE}"
elif [ "$LLVM_ENABLE_PGO" == "USE" ]; then
   llvm_pgo=" -fprofile-use=${LLVM_PROFDATA_FILE}"
fi

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "getting source"
echo "======================="
cd $M_SOURCE

#llvm
#git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone --sparse --filter=tree:0 https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
  cd llvm-project
  git sparse-checkout set --no-cone '/*' '!*/test' '!/lldb' '!/mlir' '!/clang-tools-extra' '!/polly' '!/flang'
  cd ..
fi

echo "building llvm-compiler-rt-builtin"
echo "======================="
cd $M_BUILD
rm -rf builtins-build && mkdir builtins-build
NO_CONFLTO=1 cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$(clang --print-resource-dir)" \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_C_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_CXX_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_ASM_COMPILER_TARGET=${HOST_ARCH} \
  -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_ARCH} \
  -DCMAKE_DISABLE_FIND_PACKAGE_LLVM=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
  -DCOMPILER_RT_INCLUDE_TESTS=OFF \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=OFF \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DCOMPILER_RT_HAS_FNO_LTO_FLAG=OFF \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
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
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_LLVM=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_Clang=ON \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_C_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_CXX_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_ASM_COMPILER_TARGET=${HOST_ARCH} \
  -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_ARCH} \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLIBUNWIND_USE_COMPILER_RT=ON \
  -DLIBUNWIND_ENABLE_SHARED=OFF \
  -DLIBUNWIND_ENABLE_STATIC=ON \
  -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXX_ENABLE_SHARED=OFF \
  -DLIBCXX_ENABLE_STATIC=ON \
  -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
  -DLIBCXX_INSTALL_MODULES=OFF \
  -DLIBCXX_CXX_ABI=libcxxabi \
  -DLIBCXX_INCLUDE_TESTS=OFF \
  -DLIBCXXABI_INCLUDE_TESTS=OFF \
  -DLIBUNWIND_INCLUDE_TESTS=OFF \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBUNWIND_INCLUDE_DOCS=OFF \
  -DLIBCXX_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DLIBCXXABI_ENABLE_ASSERTIONS=OFF \
  -DLIBUNWIND_ENABLE_ASSERTIONS=OFF \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_C_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_CXX_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_ASM_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}"
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
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_C_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_CXX_COMPILER_TARGET=${HOST_ARCH} \
  -DCMAKE_ASM_COMPILER_TARGET=${HOST_ARCH} \
  -DLLVM_DEFAULT_TARGET_TRIPLE=${HOST_ARCH} \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
  -DCOMPILER_RT_BUILD_BUILTINS=OFF \
  -DCOMPILER_RT_INCLUDE_TESTS=OFF \
  -DSANITIZER_CXX_ABI=libc++ \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
  -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF \
  -DCOMPILER_RT_BUILD_XRAY=OFF \
  -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
  -DCOMPILER_RT_BUILD_MEMPROF=OFF \
  -DCOMPILER_RT_BUILD_ORC=OFF \
  -DCOMPILER_RT_HAS_UBSAN=OFF \
  -DCOMPILER_RT_HAS_VERSION_SCRIPT=OFF \
  -DCOMPILER_RT_TARGET_HAS_ATOMICS=ON \
  -DCOMPILER_RT_TARGET_HAS_FCNTL_LCK=ON \
  -DCOMPILER_RT_TARGET_HAS_FLOCK=ON \
  -DCOMPILER_RT_TARGET_HAS_UNAME=ON \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_C_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_CXX_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_ASM_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}"
cmake --build compiler-rt-build -j$MJOBS
cmake --install compiler-rt-build
