#!/bin/bash
set -e

TOP_DIR=$(pwd)

# worflows for clang compilation:
# llvm -> mingw's header+crt -> compiler-rt builtins -> libcxx -> openmp

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

#llvm-mingw
git clone https://github.com/mstorsjo/llvm-mingw.git --branch master

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
  -DLLVM_USE_LINKER=lld \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
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
cmake --install llvm-build --strip

echo "installing wrappers"
echo "======================="
cd $M_CROSS/bin
ln -s $(which pkgconf) $MINGW_TRIPLE-pkg-config
ln -s $(which pkgconf) $MINGW_TRIPLE-pkgconf

cd $M_SOURCE/llvm-mingw
export TOOLCHAIN_ARCHS="x86_64"
export TOOLCHAIN_TARGET_OSES="mingw32"
./install-wrappers.sh $M_CROSS
echo "... Done"

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$M_CROSS
make -j$MJOBS
make install

echo "building mingw-w64-headers"
echo "======================="
cd $M_BUILD
mkdir headers-build
cd headers-build
$M_SOURCE/mingw-w64/mingw-w64-headers/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
  --with-default-win32-winnt=0x601 \
  --enable-idl \
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
  -DCMAKE_INSTALL_PREFIX="$(x86_64-w64-mingw32-clang --print-resource-dir)" \
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
  -DSANITIZER_CXX_ABI=libc++ \
  -DCMAKE_C_FLAGS_INIT="-mguard=cf" \
  -DCMAKE_CXX_FLAGS_INIT="-mguard=cf"
cmake --build builtins-build -j$MJOBS
cp builtins-build/lib/windows/libclang_rt.builtins-x86_64.a $M_CROSS/$MINGW_TRIPLE/lib
cmake --install builtins-build
mkdir -p $M_CROSS/$MINGW_TRIPLE/bin

echo "building llvm-libcxx"
echo "======================="
cd $M_BUILD
mkdir libcxx-build
cmake -G Ninja -H$M_SOURCE/llvm-project/runtimes -B$M_BUILD/libcxx-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_C_COMPILER_TARGET=x86_64-w64-windows-gnu \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=TRUE \
  -DCMAKE_CXX_COMPILER_WORKS=TRUE \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLLVM_PATH=$M_SOURCE/llvm-project/llvm \
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
cp $M_CROSS/$MINGW_TRIPLE/lib/libc++.a $M_CROSS/$MINGW_TRIPLE/lib/libstdc++.a

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

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
mkdir compiler-rt-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$(x86_64-w64-mingw32-clang --print-resource-dir)" \
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
  -DSANITIZER_CXX_ABI=libc++
cmake --build compiler-rt-build -j$MJOBS
cmake --install compiler-rt-build
mv $(x86_64-w64-mingw32-clang --print-resource-dir)/lib/windows/*.dll $M_CROSS/$MINGW_TRIPLE/bin

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
cmake --build openmp-build -j$MJOBS
cmake --install openmp-build

#Copy libclang_rt.builtins-x86_64.a to runtime dir
cp $M_CROSS/$MINGW_TRIPLE/lib/libclang_rt.builtins-x86_64.a $(x86_64-w64-mingw32-gcc -print-runtime-dir)