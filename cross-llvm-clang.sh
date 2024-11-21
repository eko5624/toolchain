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
ORIG_PATH="$M_HOST/bin:/usr/local/fuchsia-clang/bin:$PATH"
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
  git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
  cd llvm-project
  git sparse-checkout set --no-cone '/*' '!*/test' '!/lldb' '!/mlir' '!/clang-tools-extra' '!/polly' '!/libc' '!/flang'
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
NO_CONFLTO=1 PATH=$ORIG_PATH cmake -G Ninja -H$M_SOURCE/cppwinrt -B$M_BUILD/cppwinrt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++
ninja -C cppwinrt-build
ninja -C cppwinrt-build install
curl -L https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd -o cppwinrt-build/Windows.winmd
cppwinrt -in cppwinrt-build/Windows.winmd -out $M_CROSS/${_TARGET_ARCH}/include

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
NO_CONFLTO=1 $M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$M_CROSS
make -j$MJOBS
make install-strip

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
  --with-default-msvcrt=ucrt
make -j$MJOBS
make install-strip

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
make install-strip LTO=0 GC=0
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
make install-strip LTO=0 GC=0

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
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=${_TARGET_CPU}-pc-windows-gnu \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=TRUE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH='' \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/${_TARGET_ARCH} \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++
LTO=0 ninja -j$MJOBS -C builtins-build
cp builtins-build/lib/${_TARGET_CPU}-pc-windows-gnu/libclang* $M_CROSS/${_TARGET_ARCH}/lib
LTO=0 ninja install -C builtins-build

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
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=${_TARGET_CPU}-pc-windows-gnu \
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
  -DLIBCXX_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_LIBDIR_SUFFIX=''
LTO=0 ninja -j$MJOBS -C libcxx-build
LTO=0 ninja install -C libcxx-build
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
#   -DCMAKE_C_COMPILER_WORKS=1 \
#   -DCMAKE_CXX_COMPILER_WORKS=1 \
#   -DCMAKE_C_COMPILER_TARGET=${_TARGET_CPU}-pc-windows-gnu \
#   -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
#   -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
#   -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
#   -DCOMPILER_RT_BUILD_BUILTINS=FALSE \
#   -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
#   -DLLVM_CONFIG_PATH='' \
#   -DCMAKE_FIND_ROOT_PATH=$M_CROSS/${_TARGET_ARCH} \
#   -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
#   -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
#   -DSANITIZER_CXX_ABI=libc++ \
#   -DCMAKE_EXE_LINKER_FLAGS_INIT='-lc++abi'
# LTO=0 cmake --build compiler-rt-build -j$MJOBS
# LTO=0 cmake --install compiler-rt-build
# mkdir -p $M_CROSS/${_TARGET_ARCH}/bin
# mv $(${_TARGET_ARCH}-clang --print-resource-dir)/lib/${_TARGET_CPU}-pc-windows-gnu/*.dll $M_CROSS/${_TARGET_ARCH}/bin

# # Copy libclang_rt.builtins-x86_64.a to runtime dir
# cp $M_CROSS/${_TARGET_ARCH}/lib/libclang* $(${_TARGET_ARCH}-gcc -print-runtime-dir)


