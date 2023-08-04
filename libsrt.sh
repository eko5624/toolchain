#!/bin/bash

# basic param and command line mingwion to change it
set -e

TOP_DIR=$(pwd)
export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross
export RUSTUP_LOCATION=$M_ROOT/rustup_location

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export MINGW_TRIPLE="x86_64-w64-mingw32"

export PATH="$M_CROSS/bin:$RUSTUP_LOCATION/.cargo/bin:$PATH"
export PKG_CONFIG="pkgconf --static"
export PKG_CONFIG_LIBDIR="$TOP_DIR/opt/lib/pkgconfig"
export RUSTUP_HOME="$RUSTUP_LOCATION/.rustup"
export CARGO_HOME="$RUSTUP_LOCATION/.cargo"

export CFLAGS="-I$TOP_DIR/opt/include"
export CPPFLAGS="-I$TOP_DIR/opt/include"
export LDFLAGS="-L$TOP_DIR/opt/lib"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "building mbedtls"
echo "======================="
cd $M_SOURCE
git clone https://github.com/Mbed-TLS/mbedtls.git
cd $M_BUILD
mkdir mbedtls-build
cmake -H$M_SOURCE/mbedtls -B$M_BUILD/mbedtls-build \
  -DCMAKE_INSTALL_PREFIX=$TOP_DIR/opt \
  -DCMAKE_TOOLCHAIN_FILE=$TOP_DIR/toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_PROGRAMS=OFF \
  -DENABLE_TESTING=OFF \
  -DGEN_FILES=ON \
  -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
  -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
  -DINSTALL_MBEDTLS_HEADERS=ON
make -j$MJOBS -C $M_BUILD/mbedtls-build
make install -C $M_BUILD/mbedtls-build

echo "building libsrt"
echo "======================="
cd $M_SOURCE
git clone https://github.com/Haivision/srt.git
curl -OL https://raw.githubusercontent.com/shinchiro/mpv-winbuild-cmake/master/packages/libsrt-0001-avoid-name-collision.patch
patch -d $M_SOURCE/srt -p1 < $M_SOURCE/libsrt-0001-avoid-name-collision.patch
cd $M_BUILD
mkdir libsrt-build
cmake -G Ninja -H$M_SOURCE/srt -B$M_BUILD/libsrt-build \
  -DCMAKE_INSTALL_PREFIX=$TOP_DIR/opt \
  -DCMAKE_TOOLCHAIN_FILE=$TOP_DIR/toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_STDCXX_SYNC=ON \
  -DENABLE_APPS=OFF \
  -DENABLE_SHARED=OFF \
  -DUSE_ENCLIB=mbedtls
ninja -j$MJOBS -C $M_BUILD/libsrt-build
ninja install -C $M_BUILD/libsrt-build
