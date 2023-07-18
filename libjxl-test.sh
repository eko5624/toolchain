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

echo "building brotli"
echo "======================="
cd $M_SOURCE
git clone https://github.com/google/brotli.git
cd $M_BUILD
mkdir brotli-build
cmake -G Ninja -H$M_SOURCE/brotli -B$M_BUILD/brotli-build \
  -DCMAKE_INSTALL_PREFIX=$TOP_DIR/opt \
  -DCMAKE_TOOLCHAIN_FILE=$TOP_DIR/toolchain.cmake \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DBROTLI_EMSCRIPTEN=OFF
ninja -j$MJOBS -C $M_BUILD/brotli-build
ninja install -C $M_BUILD/brotli-build

echo "building highway"
echo "======================="
cd $M_SOURCE
git clone https://github.com/google/highway.git
cd $M_BUILD
mkdir highway-build
cmake -G Ninja -H$M_SOURCE/highway -B$M_BUILD/highway-build \
  -DCMAKE_INSTALL_PREFIX=$TOP_DIR/opt \
  -DCMAKE_TOOLCHAIN_FILE=$TOP_DIR/toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF \
  -DCMAKE_GNUtoMS=OFF \
  -DHWY_CMAKE_ARM7=OFF \
  -DHWY_ENABLE_CONTRIB=OFF \
  -DHWY_ENABLE_EXAMPLES=OFF \
  -DHWY_ENABLE_INSTALL=ON \
  -DHWY_WARNINGS_ARE_ERRORS=OFF
ninja -j$MJOBS -C $M_BUILD/highway-build
ninja install -C $M_BUILD/highway-build

echo "building zlib"
echo "======================="
cd $M_SOURCE
git clone https://github.com/madler/zlib.git
curl -OL https://raw.githubusercontent.com/shinchiro/mpv-winbuild-cmake/master/packages/zlib-1-win32-static.patch
patch -d $M_SOURCE/zlib -p1 < $M_SOURCE/zlib-1-win32-static.patch
cd $M_BUILD
mkdir zlib-build && cd zlib-build
CHOST=$MINGW_TRIPLE $M_SOURCE/zlib/configure --prefix=$TOP_DIR/opt --static
make -j$MJOBS
make install

echo "building libpng"
echo "======================="
cd $M_SOURCE
git clone https://github.com/glennrp/libpng.git
cd libpng
autoreconf -ivf
cd $M_BUILD
mkdir libpng-build && cd libpng-build
$M_SOURCE/libpng/configure \
  CFLAGS='-fno-asynchronous-unwind-tables' \
  --host=$MINGW_TRIPLE \
  --prefix=$TOP_DIR/opt \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install
ln -s $TOP_DIR/opt/bin/libpng-config $M_CROSS/bin/libpng-config
ln -s $TOP_DIR/opt/bin/libpng16-config $M_CROSS/bin/libpng16-config

echo "building libjpeg"
echo "======================="
cd $M_SOURCE
git clone https://github.com/libjpeg-turbo/libjpeg-turbo.git
cd $M_BUILD
mkdir libjpeg-turbo-build
cmake -G Ninja -H$M_SOURCE/libjpeg-turbo -B$M_BUILD/libjpeg-turbo-build \
  -DCMAKE_INSTALL_PREFIX=$TOP_DIR/opt \
  -DCMAKE_TOOLCHAIN_FILE=$TOP_DIR/toolchain.cmake \
  -DENABLE_SHARED=OFF \
  -DENABLE_STATIC=ON \
  -DCMAKE_BUILD_TYPE=Release
ninja -j$MJOBS -C $M_BUILD/libjpeg-turbo-build
ninja install -C $M_BUILD/libjpeg-turbo-build
cd $TOP_DIR

echo "building lcms2"
echo "======================="
cd $M_SOURCE
git clone https://github.com/mm2/Little-CMS.git
cd $M_BUILD
mkdir lcms2-build && cd lcms2-build
$M_SOURCE/Little-CMS/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$TOP_DIR/opt \
  --disable-shared
make -j$MJOBS
make install

echo "building libjxl"
echo "======================="
cd $M_SOURCE
git clone https://github.com/libjxl/libjxl.git
cd libjxl
rm -rf third_party/brotli
rm -rf third_party/libjpeg-turbo
cp -r $M_SOURCE/brotli third_party
cp -r $M_SOURCE/libjpeg-turbo third_party
cd $M_BUILD
mkdir libjxl-build
cmake -G Ninja -H$M_SOURCE/libjxl -B$M_BUILD/libjxl-build \
  -DCMAKE_INSTALL_PREFIX=$TOP_DIR/opt \
  -DCMAKE_TOOLCHAIN_FILE=$TOP_DIR/toolchain.cmake \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DJPEGXL_STATIC=ON \
  -DBUILD_TESTING=OFF \
  -DJPEGXL_EMSCRIPTEN=OFF \
  -DJPEGXL_BUNDLE_LIBPNG=OFF \
  -DJPEGXL_ENABLE_TOOLS=OFF \
  -DJPEGXL_ENABLE_VIEWERS=OFF \
  -DJPEGXL_ENABLE_DOXYGEN=OFF \
  -DJPEGXL_ENABLE_EXAMPLES=OFF \
  -DJPEGXL_ENABLE_MANPAGES=OFF \
  -DJPEGXL_ENABLE_JNI=OFF \
  -DJPEGXL_ENABLE_SKCMS=OFF \
  -DJPEGXL_ENABLE_PLUGINS=OFF \
  -DJPEGXL_ENABLE_DEVTOOLS=OFF \
  -DJPEGXL_ENABLE_BENCHMARK=OFF \
  -DJPEGXL_ENABLE_SJPEG=OFF \
  -DCMAKE_CXX_FLAGS='${CMAKE_CXX_FLAGS} -Wa,-muse-unaligned-vector-move' \
  -DCMAKE_C_FLAGS='${CMAKE_C_FLAGS} -Wa,-muse-unaligned-vector-move'
ninja -j$MJOBS -C $M_BUILD/libjxl-build
ninja install -C $M_BUILD/libjxl-build
