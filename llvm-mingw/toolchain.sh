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

CFGUARD_FLAGS="--enable-cfguard"
USE_CFLAGS="-g -O2 -mguard=cf"
while [ $# -gt 0 ]; do
    case "$1" in
    --armv7)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm32"
        ARCH="armv7"
        ;;
    --aarch64)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm64"
        ARCH="aarch64"
        ;;
    --x86_64)
        FLAGS="--disable-lib32 --enable-lib64"
        ARCH="x86_64"
        ;;
    --all-tools)
        CPPWINRT=1
        PKGCONF=1
        ;;
    --llvm-only)
        LLVM_ONLY=1
        ;;
    --enable-cfguard)
        CFGUARD_FLAGS="--enable-cfguard"
        USE_CFLAGS="-g -O2 -mguard=cf"
        ;;
    --disable-cfguard)
        CFGUARD_FLAGS=
        USE_CFLAGS="-g -O2"
        ;;
    --native)
        NATIVE=1
        ;;
    *)
        PREFIX="$1"
        ;;
    esac
    shift
done

export PATH="$PREFIX/bin:$PATH"
mkdir -p $M_SOURCE
mkdir -p $M_BUILD
mkdir -p $PREFIX/$MINGW_TRIPLE

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
./strip-llvm.sh $PREFIX
echo "... Done"

if [ -n "$LLVM_ONLY" ]; then
    exit 0
fi

echo "installing wrappers"
echo "======================="
cd $PREFIX/bin
ln -s llvm-ar $ARCH-w64-mingw32-ar
ln -s llvm-ar $ARCH-w64-mingw32-llvm-ar
ln -s llvm-ranlib $ARCH-w64-mingw32-ranlib
ln -s llvm-ranlib $ARCH-w64-mingw32-llvm-ranlib
ln -s llvm-dlltool $ARCH-w64-mingw32-dlltool
ln -s llvm-dlltool $ARCH-w64-mingw32-llvm-dlltool
ln -s llvm-objcopy $ARCH-w64-mingw32-objcopy
ln -s llvm-objcopy $ARCH-w64-mingw32-llvm-objcopy
ln -s llvm-strip $ARCH-w64-mingw32-strip
ln -s llvm-strip $ARCH-w64-mingw32-llvm-strip
ln -s llvm-size $ARCH-w64-mingw32-size
ln -s llvm-size $ARCH-w64-mingw32-llvm-size
ln -s llvm-strings $ARCH-w64-mingw32-strings
ln -s llvm-strings $ARCH-w64-mingw32-llvm-strings
ln -s llvm-nm $ARCH-w64-mingw32-nm
ln -s llvm-nm $ARCH-w64-mingw32-llvm-nm
ln -s llvm-readelf $ARCH-w64-mingw32-readelf
ln -s llvm-readelf $ARCH-w64-mingw32-llvm-readelf
ln -s llvm-windres $ARCH-w64-mingw32-windres
ln -s llvm-windres $ARCH-w64-mingw32-llvm-windres
ln -s llvm-addr2line $ARCH-w64-mingw32-addr2line
ln -s llvm-addr2line $ARCH-w64-mingw32-llvm-addr2line
ln -s $(which pkgconf) $ARCH-w64-mingw32-pkg-config
ln -s $(which pkgconf) $ARCH-w64-mingw32-pkgconf

cd $TOP_DIR/llvm-mingw/wrappers

for i in as c++ clang clang++ g++ gcc; do
  BASENAME=$ARCH-w64-mingw32-$i
  sed -i "s|@target_arch@|$ARCH|g" $BASENAME
done
sed -i "s|@target_arch@|$ARCH|g" $ARCH-w64-mingw32-ld
 
install -vm755 $ARCH-w64-mingw32-as $PREFIX/bin/$ARCH-w64-mingw32-as
install -vm755 $ARCH-w64-mingw32-clang $PREFIX/bin/$ARCH-w64-mingw32-clang
install -vm755 $ARCH-w64-mingw32-clang++ $PREFIX/bin/$ARCH-w64-mingw32-clang++
install -vm755 $ARCH-w64-mingw32-ld $PREFIX/bin/$ARCH-w64-mingw32-ld
install -vm755 $ARCH-w64-mingw32-gcc $PREFIX/bin/$ARCH-w64-mingw32-gcc
install -vm755 $ARCH-w64-mingw32-g++ $PREFIX/bin/$ARCH-w64-mingw32-g++
install -vm755 $ARCH-w64-mingw32-c++ $PREFIX/bin/$ARCH-w64-mingw32-c++
cat $PREFIX/bin/$ARCH-w64-mingw32-clang

if [ -n "$CPPWINRT" ]; then
    echo "building cppwinrt"
    echo "======================="
    cd $M_SOURCE
    git clone https://github.com/microsoft/cppwinrt.git --branch master
    cd $M_BUILD
    mkdir cppwinrt-build
    cmake -G Ninja -H$M_SOURCE/cppwinrt -B$M_BUILD/cppwinrt-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_INSTALL_PREFIX=$PREFIX \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++
    ninja -C cppwinrt-build
    ninja -C cppwinrt-build install
    curl -L https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd -o cppwinrt-build/Windows.winmd
    cppwinrt -in cppwinrt-build/Windows.winmd -out $PREFIX/$ARCH-w64-mingw32/include
fi    

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$PREFIX
make -j$MJOBS
make install-strip

echo "building mingw-w64-headers"
echo "======================="
cd $M_BUILD
mkdir headers-build
cd headers-build
$M_SOURCE/mingw-w64/mingw-w64-headers/configure \
  --prefix=$PREFIX/$ARCH-w64-mingw32 \
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
$M_SOURCE/mingw-w64/mingw-w64-crt/configure $FLAGS $CFGUARD_FLAGS \
  --host=$ARCH-w64-mingw32 \
  --prefix="$PREFIX/$ARCH-w64-mingw32" \
  --with-sysroot=$PREFIX \
  --with-default-msvcrt=ucrt \
  --disable-dependency-tracking
make -j$MJOBS GC=0
make install GC=0
# Create empty dummy archives, to avoid failing when the compiler driver
# adds -lssp -lssh_nonshared when linking.
llvm-ar rcs $PREFIX/lib/libssp.a
llvm-ar rcs $PREFIX/lib/libssp_nonshared.a

echo "building winpthreads"
echo "======================="
cd $M_BUILD
mkdir winpthreads-build
cd winpthreads-build
NO_CONFLTO=1 $M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=$ARCH-w64-mingw32 \
  --prefix="$PREFIX/$ARCH-w64-mingw32" \
  --disable-shared \
  --enable-static
make -j$MJOBS GC=0
make install GC=0

echo "building llvm-compiler-rt-builtin"
echo "======================="
cd $M_BUILD
if [ -n "$NATIVE" ]; then
    mkdir builtins-build
    cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$(clang --print-resource-dir)" \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DLLVM_CONFIG_PATH="" \
      -DCMAKE_FIND_ROOT_PATH=$PREFIX \
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
      -DCOMPILER_RT_USE_LIBCXX=OFF
    cmake --build builtins-build -j$MJOBS
    cmake --install builtins-build
fi    

rm -rf builtins-build && mkdir builtins-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$($ARCH-w64-mingw32-clang --print-resource-dir)" \
  -DCMAKE_C_COMPILER=$ARCH-w64-mingw32-clang \
  -DCMAKE_CXX_COMPILER=$ARCH-w64-mingw32-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$PREFIX/bin/llvm-ar \
  -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=$ARCH-w64-windows-gnu \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=TRUE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$PREFIX/$ARCH-w64-mingw32 \
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
  -DCMAKE_INSTALL_PREFIX=$PREFIX/$ARCH-w64-mingw32 \
  -DCMAKE_C_COMPILER=$ARCH-w64-mingw32-clang \
  -DCMAKE_CXX_COMPILER=$ARCH-w64-mingw32-clang++ \
  -DCMAKE_C_COMPILER_TARGET=$ARCH-w64-windows-gnu \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$PREFIX/bin/llvm-ar \
  -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
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
cp $PREFIX/$ARCH-w64-mingw32/lib/libc++.a $PREFIX/$ARCH-w64-mingw32/lib/libstdc++.a

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
if [ -n "$NATIVE" ]; then
    mkdir compiler-rt-build
    cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$(clang --print-resource-dir)" \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DLLVM_CONFIG_PATH="" \
      -DCMAKE_FIND_ROOT_PATH=$PREFIX \
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
      -DCOMPILER_RT_USE_LIBCXX=OFF
    cmake --build compiler-rt-build -j$MJOBS
    cmake --install compiler-rt-build
fi

rm -rf compiler-rt-build && mkdir compiler-rt-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$($ARCH-w64-mingw32-clang --print-resource-dir)" \
  -DCMAKE_C_COMPILER=$ARCH-w64-mingw32-clang \
  -DCMAKE_CXX_COMPILER=$ARCH-w64-mingw32-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$PREFIX/bin/llvm-ar \
  -DCMAKE_RANLIB=$PREFIX/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=$ARCH-w64-windows-gnu \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=FALSE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$PREFIX/$ARCH-w64-mingw32 \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++
cmake --build compiler-rt-build -j$MJOBS
cmake --install compiler-rt-build
mkdir -p $PREFIX/$ARCH-w64-mingw32/bin
mv $($ARCH-w64-mingw32-clang --print-resource-dir)/lib/windows/*.dll $PREFIX/$ARCH-w64-mingw32/bin

if [ -n "$PKGCONF" ]; then
    echo "building pkgconf"
    echo "======================="
    cd $M_BUILD
    mkdir pkgconf-build
    cd $M_SOURCE/pkgconf
    meson setup $M_BUILD/pkgconf-build \
      --prefix=$PREFIX \
      --buildtype=release \
      -Dtests=disabled
    meson compile -C $M_BUILD/pkgconf-build
    meson install -C $M_BUILD/pkgconf-build
    cd $PREFIX/bin
    #ln -s pkgconf x86_64-w64-mingw32-pkgconf
    #ln -s pkgconf x86_64-w64-mingw32-pkg-config
    rm -rf $PREFIX/lib/pkgconfig
fi    

echo "fix cross-llvm-wrappers"
echo "======================="
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $PREFIX/bin/x86_64-w64-mingw32-as
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $PREFIX/bin/x86_64-w64-mingw32-c++
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $PREFIX/bin/x86_64-w64-mingw32-clang
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $PREFIX/bin/x86_64-w64-mingw32-clang++
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $PREFIX/bin/x86_64-w64-mingw32-g++
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $PREFIX/bin/x86_64-w64-mingw32-gcc
sed -i 's/$FLAGS "$@"/"$@" $FLAGS/' $PREFIX/bin/x86_64-w64-mingw32-ld
