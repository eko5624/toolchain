#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh

# worflows for clang compilation:
# llvm -> mingw's header+crt -> compiler-rt builtins -> libcxx -> openmp

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export MINGW_TRIPLE="x86_64-w64-mingw32"

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross
export RUSTUP_LOCATION=$M_ROOT/rust

export PATH="$M_CROSS/bin:$RUSTUP_LOCATION/.cargo/bin:$PATH"
export RUSTUP_HOME="$RUSTUP_LOCATION/.rustup"
export CARGO_HOME="$RUSTUP_LOCATION/.cargo"
export LLVM_ENABLE_PGO="OFF" #STRING "OFF, GEN, CSGEN, USE"
export LLVM_PROFILE_FILE="/dev/null"

while [ $# -gt 0 ]; do
    case "$1" in
    --enable-pgo)
        export LLVM_ENABLE_PGO="GEN" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    --build-x86_64)
        export LLvm_WRAPPER_DIR="llvm-wrapper-x86_64"
        ;;
    --build-x86_64_v3)
        export LLvm_WRAPPER_DIR="llvm-wrapper-x86_64_v3"
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

echo "getting source"
echo "======================="
cd $M_SOURCE

#llvm
git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
#git clone https://github.com/llvm/llvm-project.git --branch release/18.x
cd llvm-project
git sparse-checkout set --no-cone '/*' '!*/test'
cd ..

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master

echo "installing llvm-wrappers"
echo "======================="
cd $M_CROSS/bin
ln -s llvm-ar $MINGW_TRIPLE-ar
ln -s llvm-ar $MINGW_TRIPLE-llvm-ar
ln -s llvm-ar $MINGW_TRIPLE-ranlib
ln -s llvm-ar $MINGW_TRIPLE-llvm-ranlib
ln -s llvm-ar $MINGW_TRIPLE-dlltool
ln -s llvm-objcopy $MINGW_TRIPLE-objcopy
ln -s llvm-objcopy $MINGW_TRIPLE-strip
ln -s llvm-size $MINGW_TRIPLE-size
ln -s llvm-strings $MINGW_TRIPLE-strings
ln -s llvm-nm $MINGW_TRIPLE-nm
ln -s llvm-readelf $MINGW_TRIPLE-readelf
ln -s llvm-rc $MINGW_TRIPLE-windres
ln -s llvm-addr2line $MINGW_TRIPLE-addr2line
ln -s $(which pkgconf) $MINGW_TRIPLE-pkg-config
ln -s $(which pkgconf) $MINGW_TRIPLE-pkgconf
cp $TOP_DIR/$LLvm_WRAPPER_DIR/x86_64-w64-mingw32-as ./
cp $TOP_DIR/$LLvm_WRAPPER_DIR/x86_64-w64-mingw32-clang ./
cp $TOP_DIR/$LLvm_WRAPPER_DIR/x86_64-w64-mingw32-clang++ ./
cp $TOP_DIR/$LLvm_WRAPPER_DIR/x86_64-w64-mingw32-ld ./
cp $TOP_DIR/$LLvm_WRAPPER_DIR/x86_64-w64-mingw32-gcc ./
cp $TOP_DIR/$LLvm_WRAPPER_DIR/x86_64-w64-mingw32-g++ ./
cp $TOP_DIR/$LLvm_WRAPPER_DIR/x86_64-w64-mingw32-c++ ./

chmod 755 x86_64-w64-mingw32-as
chmod 755 x86_64-w64-mingw32-clang
chmod 755 x86_64-w64-mingw32-clang++
chmod 755 x86_64-w64-mingw32-ld
chmod 755 x86_64-w64-mingw32-gcc
chmod 755 x86_64-w64-mingw32-g++
chmod 755 x86_64-w64-mingw32-c++

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
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
  --enable-sdk=all \
  --enable-idl \
  --with-default-win32-winnt=0x601 \
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
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
  --with-sysroot=$M_CROSS \
  --with-default-msvcrt=ucrt \
  --enable-lib64 \
  --disable-lib32 \
  --enable-cfguard \
  --disable-dependency-tracking
make -j$MJOBS LTO=0 GC=0
make install-strip LTO=0 GC=0
# Create empty dummy archives, to avoid failing when the compiler driver
# adds -lssp -lssh_nonshared when linking.
llvm-ar rcs $M_CROSS/lib/libssp.a
llvm-ar rcs $M_CROSS/lib/libssp_nonshared.a

echo "building winpthreads"
echo "======================="
cd $M_BUILD
mkdir winpthreads-build
cd winpthreads-build
NO_CONFLTO=1 $M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
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
  -DCMAKE_INSTALL_PREFIX="$(x86_64-w64-mingw32-clang --print-resource-dir)" \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-pc-windows-gnu \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=TRUE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++
LTO=0 ninja -j$MJOBS -C builtins-build
cp builtins-build/lib/x86_64-pc-windows-gnu/libclang* $M_CROSS/$MINGW_TRIPLE/lib
LTO=0 ninja install -C builtins-build

echo "building llvm-libcxx"
echo "======================="
cd $M_BUILD
mkdir libcxx-build
NO_CONFLTO=1 cmake -G Ninja -H$M_SOURCE/llvm-project/runtimes -B$M_BUILD/libcxx-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-pc-windows-gnu \
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
  -DLIBCXX_LIBDIR_SUFFIX="" \
  -DLIBCXX_INCLUDE_TESTS=FALSE \
  -DLIBCXXABI_INCLUDE_TESTS=FALSE \
  -DLIBUNWIND_INCLUDE_TESTS=FALSE \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
  -DLIBCXX_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_LIBDIR_SUFFIX=""
LTO=0 ninja -j$MJOBS -C libcxx-build
LTO=0 ninja install -C libcxx-build
cp $M_CROSS/$MINGW_TRIPLE/lib/libc++.a $M_CROSS/$MINGW_TRIPLE/lib/libstdc++.a

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
mkdir compiler-rt-build
NO_CONFLTO=1 cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$(x86_64-w64-mingw32-clang --print-resource-dir)" \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-pc-windows-gnu \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=FALSE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++ \
  -DCMAKE_CXX_FLAGS='-std=c++11' \
  -DCMAKE_EXE_LINKER_FLAGS_INIT='-lc++abi'
LTO=0 cmake --build compiler-rt-build -j$MJOBS
LTO=0 cmake --install compiler-rt-build
mkdir -p $M_CROSS/$MINGW_TRIPLE/bin
mv $(x86_64-w64-mingw32-clang --print-resource-dir)/lib/windows/*.dll $M_CROSS/$MINGW_TRIPLE/bin

#Copy libclang_rt.builtins-x86_64.a to runtime dir
cp $M_CROSS/$MINGW_TRIPLE/lib/libclang_rt.builtins-x86_64.a $(x86_64-w64-mingw32-gcc -print-runtime-dir)

#Remove profraw
rm -rf $M_CROSS/profiles/* || true

#echo "building llvm-openmp"
#echo "======================="
#cd $M_BUILD
#mkdir openmp-build
#cd openmp-build
#curl -OL https://raw.githubusercontent.com/shinchiro/mpv-winbuild-cmake/master/toolchain/llvm/llvm-openmp-0001-support-static-lib.patch
#cd $M_SOURCE/llvm-project
#patch -p1 -i $M_BUILD/openmp-build/llvm-openmp-0001-support-static-lib.patch
#cd $M_BUILD
#NO_CONFLTO=1 cmake -G Ninja -H$M_SOURCE/llvm-project/openmp -B$M_BUILD/openmp-build \
#  -DCMAKE_BUILD_TYPE=Release \
#  -DCMAKE_INSTALL_PREFIX=$M_CROSS/$MINGW_TRIPLE \
#  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
#  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
#  -DCMAKE_RC_COMPILER=$MINGW_TRIPLE-windres \
#  -DCMAKE_ASM_MASM_COMPILER=llvm-ml \
#  -DCMAKE_SYSTEM_NAME=Windows \
#  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
#  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
#  -DLIBOMP_ENABLE_SHARED=FALSE \
#  -DLIBOMP_ASMFLAGS=-m64
#ninja -j$MJOBS -C openmp-build
#ninja install -C openmp-build