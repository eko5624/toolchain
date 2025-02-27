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
export M_CROSS=$M_ROOT/cross

export MINGW_TRIPLE="x86_64-w64-mingw32"
export PATH="$M_CROSS/bin:$PATH"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD
mkdir -p $M_CROSS/$MINGW_TRIPLE

echo "getting source"
echo "======================="
cd $M_SOURCE
#llvm
#git clone https://github.com/llvm/llvm-project.git --branch release/18.x llvmorg-$VER_LLVM
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
fi

#lldb-mi
#git clone https://github.com/lldb-tools/lldb-mi.git

#llvm-mingw
git clone https://github.com/mstorsjo/llvm-mingw.git --branch master

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master

#pkgconf
git clone https://github.com/pkgconf/pkgconf --branch pkgconf-$VER_PKGCONF

echo "stripping llvm"
echo "======================="
cd $M_SOURCE/llvm-mingw
./strip-llvm.sh $M_CROSS
echo "... Done"

echo "installing wrappers"
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
cp $TOP_DIR/cross-llvm-wrappers/x86_64-w64-mingw32-as ./
cp $TOP_DIR/cross-llvm-wrappers/x86_64-w64-mingw32-clang ./
cp $TOP_DIR/cross-llvm-wrappers/x86_64-w64-mingw32-clang++ ./
cp $TOP_DIR/cross-llvm-wrappers/x86_64-w64-mingw32-ld ./
cp $TOP_DIR/cross-llvm-wrappers/x86_64-w64-mingw32-gcc ./
cp $TOP_DIR/cross-llvm-wrappers/x86_64-w64-mingw32-g++ ./
cp $TOP_DIR/cross-llvm-wrappers/x86_64-w64-mingw32-c++ ./

chmod 755 x86_64-w64-mingw32-as
chmod 755 x86_64-w64-mingw32-clang
chmod 755 x86_64-w64-mingw32-clang++
chmod 755 x86_64-w64-mingw32-ld
chmod 755 x86_64-w64-mingw32-gcc
chmod 755 x86_64-w64-mingw32-g++
chmod 755 x86_64-w64-mingw32-c++

echo "building cppwinrt"
echo "======================="
cd $M_SOURCE
git clone https://github.com/microsoft/cppwinrt.git --branch master
cd $M_BUILD
mkdir cppwinrt-build
cmake -G Ninja -H$M_SOURCE/cppwinrt -B$M_BUILD/cppwinrt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++
ninja -C cppwinrt-build
ninja -C cppwinrt-build install
curl -L https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd -o cppwinrt-build/Windows.winmd
cppwinrt -in cppwinrt-build/Windows.winmd -out $M_CROSS/$MINGW_TRIPLE/include

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$M_CROSS
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
$M_SOURCE/mingw-w64/mingw-w64-crt/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
  --with-sysroot=$M_CROSS \
  --with-default-msvcrt=ucrt \
  --enable-lib64 \
  --disable-lib32 \
  --enable-cfguard \
  --disable-dependency-tracking
make -j$MJOBS GC=0
make install GC=0
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
make -j$MJOBS GC=0
make install GC=0

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
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++ \
  -DCMAKE_C_FLAGS_INIT="-mguard=cf" \
  -DCMAKE_CXX_FLAGS_INIT="-mguard=cf"
cmake --build builtins-build -j$MJOBS
cmake --install builtins-build

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
  -DLIBCXXABI_INCLUDE_TESTS=FALSE \
  -DLIBUNWIND_INCLUDE_TESTS=FALSE \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
  -DLIBCXX_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_LIBDIR_SUFFIX=""
cmake --build libcxx-build -j$MJOBS
cmake --install libcxx-build
cp $M_CROSS/$MINGW_TRIPLE/lib/libc++.a $M_CROSS/$MINGW_TRIPLE/lib/libstdc++.a

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
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++
cmake --build compiler-rt-build -j$MJOBS
cmake --install compiler-rt-build
mkdir -p $M_CROSS/$MINGW_TRIPLE/bin
mv $(x86_64-w64-mingw32-clang --print-resource-dir)/lib/windows/*.dll $M_CROSS/$MINGW_TRIPLE/bin

echo "building pkgconf"
echo "======================="
cd $M_BUILD
mkdir pkgconf-build
cd $M_SOURCE/pkgconf
meson setup $M_BUILD/pkgconf-build \
  --prefix=$M_CROSS \
  --buildtype=release \
  -Dtests=disabled
meson compile -C $M_BUILD/pkgconf-build
meson install -C $M_BUILD/pkgconf-build
cd $M_CROSS/bin
#ln -s pkgconf x86_64-w64-mingw32-pkgconf
#ln -s pkgconf x86_64-w64-mingw32-pkg-config
rm -rf $M_CROSS/lib/pkgconfig

echo "fix cross-llvm-wrappers"
echo "======================="
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $M_CROSS/bin/x86_64-w64-mingw32-as
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $M_CROSS/bin/x86_64-w64-mingw32-c++
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $M_CROSS/bin/x86_64-w64-mingw32-clang
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $M_CROSS/bin/x86_64-w64-mingw32-clang++
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $M_CROSS/bin/x86_64-w64-mingw32-g++
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $M_CROSS/bin/x86_64-w64-mingw32-gcc
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $M_CROSS/bin/x86_64-w64-mingw32-ld
