#!/bin/bash
set -e

TOP_DIR=$(pwd)

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

MINGW_TRIPLE="x86_64-w64-mingw32"
export MINGW_TRIPLE

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross

export PATH="$M_CROSS/bin:$PATH"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "gettiong source"
echo "======================="
cd $M_SOURCE

#llvm
git clone https://github.com/llvm/llvm-project.git --branch release/17.x
#git clone https://github.com/llvm/llvm-project.git --branch llvmorg-17.0.1

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master

echo "building llvm"
echo "======================="
cd $M_BUILD
mkdir llvm-build
cmake -G Ninja -H$M_SOURCE/llvm-project/llvm -B$M_BUILD/llvm-build \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_PROJECTS="clang;lld;polly" \
  -DLLVM_TARGETS_TO_BUILD="X86;NVPTX" \
  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
  -DLLVM_POLLY_LINK_INTO_TOOLS=ON \
  -DLLVM_ENABLE_LIBCXX=ON \
  -DLLVM_ENABLE_LLD=ON \
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
  -DLLVM_TOOLCHAIN_TOOLS="llvm-as;llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-pdbutil;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf;llvm-size;llvm-config"
ninja -j$MJOBS -C $M_BUILD/llvm-build
ninja install -C $M_BUILD/llvm-build

mkdir -p $M_CROSS/$MINGW_TRIPLE/lib
cd $M_CROSS/bin
ln -s llvm-as $MINGW_TRIPLE-as
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
cp $TOP_DIR/x86_64-w64-mingw32-clang ./
cp $TOP_DIR/x86_64-w64-mingw32-clang++ ./
cp $TOP_DIR/x86_64-w64-mingw32-ld ./
cp $TOP_DIR/x86_64-w64-mingw32-gcc ./
cp $TOP_DIR/x86_64-w64-mingw32-g++ ./
cp $TOP_DIR/x86_64-w64-mingw32-c++ ./
ln -s x86_64-w64-mingw32-ld ld.x86_64-w64-mingw32-lld

chmod 755 x86_64-w64-mingw32-clang
chmod 755 x86_64-w64-mingw32-clang++
chmod 755 x86_64-w64-mingw32-ld
chmod 755 x86_64-w64-mingw32-gcc
chmod 755 x86_64-w64-mingw32-g++
chmod 755 x86_64-w64-mingw32-c++

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
make install

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$M_CROSS
make -j$MJOBS
make install

echo "building mingw-w64-crt"
echo "======================="
cd $M_SOURCE/mingw-w64/mingw-w64-crt
autoreconf -ivf
cd $M_BUILD 
mkdir crt-build
cd crt-build
$M_SOURCE/mingw-w64/mingw-w64-crt/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
  --with-sysroot=$M_CROSS \
  --with-default-msvcrt=ucrt \
  --enable-lib64 \
  --disable-lib32 \
  --enable-cfguard \
  --disable-dependency-tracking
make -j$MJOBS
make install
# Create empty dummy archives, to avoid failing when the compiler driver
# adds -lssp -lssh_nonshared when linking.
llvm-ar rcs $M_CROSS/lib/libssp.a
llvm-ar rcs $M_CROSS/lib/libssp_nonshared.a

echo "building llvm-compiler-rt-builtin"
echo "======================="
cd $M_BUILD
mkdir builtins-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS/lib/clang/17 \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-w64-windows-gnu \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=TRUE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++
ninja -j$MJOBS -C $M_BUILD/builtins-build
ninja install -C $M_BUILD/builtins-build

echo "building winpthreads"
echo "======================="
cd $M_BUILD
mkdir winpthreads-build
cd winpthreads-build
$M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
  --disable-shared \
  --enable-static
make -j$MJOBS
make install

echo "building llvm-libcxx"
echo "======================="
cd $M_BUILD
mkdir libcxx-build
cmake -G Ninja -H$M_SOURCE/llvm-project/runtimes -B$M_BUILD/libcxx-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-w64-windows-gnu \
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
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_LIBDIR_SUFFIX=""
ninja -j$MJOBS -C $M_BUILD/libcxx-build
ninja install -C $M_BUILD/libcxx-build
cp $M_CROSS/$MINGW_TRIPLE/lib/libc++.a $M_CROSS/$MINGW_TRIPLE/lib/libstdc++.a

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
mkdir compiler-rt-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS/lib/clang/17 \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-w64-windows-gnu \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++ \
  -DCMAKE_CXX_FLAGS="-std=c++11" \
  -DCMAKE_EXE_LINKER_FLAGS_INIT="-lc++abi"
ninja -j$MJOBS -C $M_BUILD/compiler-rt-build
ninja install -C $M_BUILD/compiler-rt-build

echo "building llvm-openmp"
echo "======================="
cd $M_BUILD
mkdir openmp-build
cd openmp-build
curl -OL https://raw.githubusercontent.com/shinchiro/mpv-winbuild-cmake/master/toolchain/llvm/llvm-openmp-0001-support-static-lib.patch
cd $M_SOURCE/llvm-project
patch -p1 -i $M_BUILD/openmp-build/llvm-openmp-0001-support-static-lib.patch
cd $M_BUILD
cmake -G Ninja -H$M_SOURCE/llvm-project/openmp -B$M_BUILD/openmp-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_RC_COMPILER=$MINGW_TRIPLE-windres \
  -DCMAKE_ASM_MASM_COMPILER=llvm-ml \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DLIBOMP_ENABLE_SHARED=FALSE \
  -DLIBOMP_ASMFLAGS=-m64
ninja -j$MJOBS -C $M_BUILD/openmp-build
ninja install -C $M_BUILD/openmp-build
