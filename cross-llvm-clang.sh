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
M_BUILD=$M_ROOT/build
M_CROSS=$M_ROOT/cross
M_HOST=$M_ROOT/host
O_PATH="$M_HOST/bin:/usr/local/fuchsia-clang/bin:$PATH"
PATH="$M_CROSS/bin:$PATH"
LLVM_ENABLE_PGO="OFF" #STRING "OFF, GEN, CSGEN, USE"
LLVM_PROFILE_FILE="/dev/null"

while [ $# -gt 0 ]; do
  case "$1" in
  --enable-pgo_gen)
    LLVM_ENABLE_PGO="GEN" #STRING "OFF, GEN, CSGEN, USE"
    ;;
  --x86_64)
    _TARGET_CPU=x86_64
    _TARGET_ARCH=x86_64-w64-mingw32
    _CRT_LIB="--disable-lib32 --enable-lib64"
    ;;
  --x86_64_v3)
    _TARGET_CPU=x86_64
    _TARGET_ARCH=x86_64-w64-mingw32
    _CRT_LIB="--disable-lib32 --enable-lib64"
    ;;
  --aarch64)
    _TARGET_CPU=aarch64
    _TARGET_ARCH=aarch64-w64-mingw32
    _CRT_LIB="--disable-lib32 --disable-lib64 --enable-libarm64"
    ;;
  *)
    echo Unrecognized parameter $1
    exit 1
    ;;
  esac
  shift
done

if [ "$LLVM_ENABLE_PGO" == "GEN" ] || [ "$LLVM_ENABLE_PGO" == "CSGEN" ]; then
  export LLVM_PROFILE_DATA_DIR="$M_CROSS/profiles" #PATH "Default profile generation directory"
fi

mkdir -p $M_SOURCE
mkdir -p $M_BUILD
mkdir -p $M_CROSS/${_TARGET_ARCH}

echo "getting source"
echo "======================="
cd $M_SOURCE

#llvm
#git clone https://github.com/llvm/llvm-project.git --branch release/19.x
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone --sparse --filter=tree:0 https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
  cd llvm-project
  git sparse-checkout set --no-cone '/*' '!*/test' '!/lldb' '!/mlir' '!/clang-tools-extra' '!/polly' '!/flang'
  cd ..
fi  

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master

echo "building cppwinrt"
echo "======================="
cd $M_SOURCE
git clone https://github.com/microsoft/cppwinrt.git --branch master
cd $M_BUILD
mkdir cppwinrt-build
NO_CONFLTO=1 PATH=$O_PATH cmake -G Ninja -H$M_SOURCE/cppwinrt -B$M_BUILD/cppwinrt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON
cmake --build cppwinrt-build
#ninja -C cppwinrt-build
#ninja -C cppwinrt-build install
cmake --install cppwinrt-build
curl -L https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd -o cppwinrt-build/Windows.winmd
cppwinrt -in cppwinrt-build/Windows.winmd -out $M_CROSS/${_TARGET_ARCH}/include

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
NO_CONFLTO=1 PATH=$O_PATH $M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$M_CROSS
make -j$MJOBS
make install

echo "building mingw-w64-headers"
echo "======================="
cd $M_BUILD
mkdir headers-build
cd headers-build
$M_SOURCE/mingw-w64/mingw-w64-headers/configure \
  --host=${TARGET_ARCH} \
  --prefix=$M_CROSS/${_TARGET_ARCH} \
  --enable-sdk=all \
  --enable-idl \
  --with-default-win32-winnt=0x601 \
  --with-default-msvcrt=ucrt
make -j$MJOBS
make install

echo "building mingw-w64-crt"
echo "======================="
cd $M_SOURCE/mingw-w64/mingw-w64-crt
autoreconf -ivf
cd $M_BUILD
mkdir crt-build
cd crt-build
NO_CONFLTO=1 $M_SOURCE/mingw-w64/mingw-w64-crt/configure \
  --host=${_TARGET_ARCH} \
  --prefix=$M_CROSS/${_TARGET_ARCH} \
  --with-sysroot=$M_CROSS \
  --with-default-msvcrt=ucrt \
  --enable-wildcard \
  ${_CRT_LIB} \
  --enable-cfguard \
  --disable-dependency-tracking
make -j$MJOBS LTO=0 GC=0
make install
# Create empty dummy archives, to avoid failing when the compiler driver
# adds -lssp -lssh_nonshared when linking.
llvm-ar rcs $M_CROSS/${_TARGET_ARCH}/lib/libssp.a
llvm-ar rcs $M_CROSS/${_TARGET_ARCH}/lib/libssp_nonshared.a

echo "building winpthreads"
echo "======================="
cd $M_BUILD
mkdir winpthreads-build
cd winpthreads-build
NO_CONFLTO=1 $M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=${_TARGET_ARCH} \
  --prefix=$M_CROSS/${_TARGET_ARCH} \
  --disable-shared \
  --enable-static
make -j$MJOBS LTO=0 GC=0
make install

echo "building llvm-compiler-rt-builtin"
echo "======================="
cd $M_BUILD
mkdir builtins-build
NO_CONFLTO=1 cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$(${_TARGET_ARCH}-clang --print-resource-dir)" \
  -DCMAKE_C_COMPILER=${_TARGET_ARCH}-clang \
  -DCMAKE_CXX_COMPILER=${_TARGET_ARCH}-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_C_COMPILER_TARGET=${_TARGET_CPU}-pc-windows-gnu \
  -DCMAKE_DISABLE_FIND_PACKAGE_LLVM=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
  -DCOMPILER_RT_INCLUDE_TESTS=OFF \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=OFF \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DCOMPILER_RT_HAS_FNO_LTO_FLAG=OFF \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
cmake --build builtins-build -j$MJOBS
LTO=0 cmake --install builtins-build

echo "building llvm-libcxx"
echo "======================="
cd $M_BUILD
mkdir libcxx-build
NO_CONFLTO=1 cmake -G Ninja -H$M_SOURCE/llvm-project/runtimes -B$M_BUILD/libcxx-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS/${_TARGET_ARCH} \
  -DCMAKE_C_COMPILER=${_TARGET_ARCH}-clang \
  -DCMAKE_CXX_COMPILER=${_TARGET_ARCH}-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_DISABLE_FIND_PACKAGE_LLVM=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_Clang=ON \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_C_COMPILER_TARGET=${_TARGET_CPU}-pc-windows-gnu \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLIBUNWIND_USE_COMPILER_RT=ON \
  -DLIBUNWIND_ENABLE_SHARED=OFF \
  -DLIBUNWIND_ENABLE_STATIC=ON \
  -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXX_ENABLE_SHARED=OFF \
  -DLIBCXX_ENABLE_STATIC=ON \
  -DLIBCXX_INSTALL_MODULES=OFF \
  -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
  -DLIBCXX_CXX_ABI=libcxxabi \
  -DLIBCXX_INCLUDE_TESTS=OFF \
  -DLIBCXXABI_INCLUDE_TESTS=OFF \
  -DLIBUNWIND_INCLUDE_TESTS=OFF \
  -DLIBCXX_INCLUDE_DOCS=OFF \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF \
  -DLIBCXX_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBUNWIND_INCLUDE_DOCS=OFF \
  -DLIBCXXABI_ENABLE_ASSERTIONS=OFF \
  -DLIBUNWIND_ENABLE_ASSERTIONS=OFF \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
cmake --build libcxx-build -j$MJOBS
cmake --install libcxx-build
cp $M_CROSS/${_TARGET_ARCH}/lib/libc++.a $M_CROSS/${_TARGET_ARCH}/lib/libstdc++.a 

# Remove profraw
rm -rf $M_CROSS/profiles/* || true

# echo "building llvm-compiler-rt"
# echo "======================="
# cd $M_BUILD
# mkdir compiler-rt-build
# NO_CONFLTO=1 cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
#   -DCMAKE_BUILD_TYPE=Release \
#   -DCMAKE_INSTALL_PREFIX="$(${_TARGET_ARCH}-clang --print-resource-dir)" \
#   -DCMAKE_C_COMPILER=${_TARGET_ARCH}-clang \
#   -DCMAKE_CXX_COMPILER=${_TARGET_ARCH}-clang++ \
#   -DCMAKE_SYSTEM_NAME=Windows \
#   -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
#   -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
#   -DCMAKE_C_COMPILER_WORKS=ON \
#   -DCMAKE_CXX_COMPILER_WORKS=ON \
#   -DCMAKE_C_COMPILER_TARGET=${_TARGET_CPU}-pc-windows-gnu \
#   -DCMAKE_DISABLE_FIND_PACKAGE_LLVM=ON \
#   -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
#   -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
#   -DCOMPILER_RT_BUILD_BUILTINS=OFF \
#   -DCOMPILER_RT_INCLUDE_TESTS=OFF \
#   -DSANITIZER_CXX_ABI=libc++ \
#   -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
#   -DCOMPILER_RT_TARGET_HAS_ATOMICS=ON \
#   -DCOMPILER_RT_TARGET_HAS_FLOCK=ON \
#   -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
#   -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
#   -DCOMPILER_RT_BUILD_ORC=OFF \
#   -DCOMPILER_RT_HAS_UBSAN=OFF \
#   -DCOMPILER_RT_HAS_VERSION_SCRIPT=OFF \
#   -DCOMPILER_RT_SANITIZERS_TO_BUILD='' \
#   -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
# LTO=0 cmake --build compiler-rt-build -j$MJOBS
# cmake --install compiler-rt-build



