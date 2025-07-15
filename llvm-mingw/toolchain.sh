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
CLANG_RESOURCE_DIR="$("$PREFIX/bin/clang" --print-resource-dir)"
INSTALL_PREFIX="$CLANG_RESOURCE_DIR"

if [ -h "$CLANG_RESOURCE_DIR/include" ]; then
    # Symlink to system headers; use a staging directory in case parts
    # of the resource dir are immutable
    WORKDIR="$(mktemp -d)"; trap "rm -rf $WORKDIR" 0
    INSTALL_PREFIX="$WORKDIR/install"
fi

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

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
echo "stripping llvm done"

if [ -n "$NATIVE" ]; then
    echo "building llvm-compiler-rt"
    echo "======================="
    cd $M_BUILD
    mkdir compiler-rt-build
    cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$CLANG_RESOURCE_DIR" \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DLLVM_CONFIG_PATH="" \
      -DCMAKE_FIND_ROOT_PATH=$PREFIX \
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
      -DCOMPILER_RT_USE_LIBCXX=OFF
    cmake --build compiler-rt-build -j$MJOBS
    cmake --install compiler-rt-build --prefix "$INSTALL_PREFIX"
    if [ "$INSTALL_PREFIX" != "$CLANG_RESOURCE_DIR" ]; then
        # symlink to system headers - skip copy
        rm -rf "$INSTALL_PREFIX/include"
        cp -r "$INSTALL_PREFIX/." $CLANG_RESOURCE_DIR
    fi
fi

if [ -n "$LLVM_ONLY" ]; then
    exit 0
fi

echo "installing wrappers"
echo "======================="
cp -f $M_SOURCE/llvm-mingw/wrappers/*-wrapper.sh $PREFIX/bin
cp -f $M_SOURCE/llvm-mingw/wrappers/mingw32-common.cfg $PREFIX/bin
cp -f $M_SOURCE/llvm-mingw/wrappers/$ARCH-w64-windows-gnu.cfg $PREFIX/bin
cd $PREFIX/bin
for exec in clang clang++ gcc g++ c++ as; do
    ln -sf clang-target-wrapper.sh $ARCH-w64-mingw32-$exec
done
ln -sf clang-scan-deps $ARCH-w64-mingw32-clang-scan-deps
for exec in addr2line ar ranlib nm objcopy readelf size strings strip; do
    ln -sf llvm-$exec $ARCH-w64-mingw32-$exec
done
ln -sf llvm-ar $ARCH-w64-mingw32-llvm-ar
ln -sf llvm-ranlib $ARCH-w64-mingw32-llvm-ranlib
# windres and dlltool can't use llvm-wrapper, as that loses the original
# target arch prefix.
ln -sf llvm-windres $ARCH-w64-mingw32-windres
ln -sf llvm-dlltool $ARCH-w64-mingw32-dlltool
for exec in ld objdump; do
    ln -sf $exec-wrapper.sh $ARCH-w64-mingw32-$exec
done
echo "installing wrappers done"

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
make -j$MJOBS
make install
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
make -j$MJOBS
make install 

echo "building llvm-compiler-rt-builtin"
echo "======================="
cd $M_BUILD
mkdir builtins-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$CLANG_RESOURCE_DIR" \
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
cmake --install builtins-build --prefix "$INSTALL_PREFIX"

echo "building llvm-libcxx"
echo "======================="
cd $M_BUILD
mkdir libcxx-build
cmake -G Ninja -H$M_SOURCE/llvm-project/runtimes -B$M_BUILD/libcxx-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX/$ARCH-w64-mingw32" \
  -DCMAKE_C_COMPILER=$ARCH-w64-mingw32-clang \
  -DCMAKE_CXX_COMPILER=$ARCH-w64-mingw32-clang++ \
  -DCMAKE_CXX_COMPILER_TARGET=$ARCH-w64-windows-gnu \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_C_COMPILER_WORKS=TRUE \
  -DCMAKE_CXX_COMPILER_WORKS=TRUE \
  -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
  -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
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
  -DLIBCXX_INSTALL_MODULES=ON \
  -DLIBCXX_INSTALL_MODULES_DIR="$PREFIX/share/libc++/v1" \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_LIBDIR_SUFFIX="" \
  -DCMAKE_C_FLAGS_INIT="-mguard=cf" \
  -DCMAKE_CXX_FLAGS_INIT="-mguard=cf"
cmake --build libcxx-build -j$MJOBS
cmake --install libcxx-build

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
rm -rf compiler-rt-build && mkdir compiler-rt-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$CLANG_RESOURCE_DIR" \
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
cmake --install compiler-rt-build --prefix "$INSTALL_PREFIX"
mkdir -p $PREFIX/$ARCH-w64-mingw32/bin
case $ARCH in
aarch64)
    # asan doesn't work on aarch64 or armv7; make this clear by omitting
    # the installed files altogether.
    rm -f "$INSTALL_PREFIX/lib/windows/libclang_rt.asan"*aarch64*
    ;;
armv7)
    rm -f "$INSTALL_PREFIX/lib/windows/libclang_rt.asan"*arm*
    ;;
*)
    mv "$INSTALL_PREFIX/lib/windows/"*.dll "$PREFIX/$arch-w64-mingw32/bin"
    ;;
esac

if [ "$INSTALL_PREFIX" != "$CLANG_RESOURCE_DIR" ]; then
    # symlink to system headers - skip copy
    rm -rf "$INSTALL_PREFIX/include"

    cp -r "$INSTALL_PREFIX/." $CLANG_RESOURCE_DIR
fi

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
