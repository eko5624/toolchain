#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh
export BRANCH_GCC=releases/gcc-13

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export MINGW_TRIPLE="x86_64-w64-mingw32"

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

#binutils
wget -c -O binutils-$VER_BINUTILS.tar.bz2 http://ftp.gnu.org/gnu/binutils/binutils-$VER_BINUTILS.tar.bz2
tar xjf binutils-$VER_BINUTILS.tar.bz2

#gcc
git clone https://github.com/gcc-mirror/gcc.git --branch $BRANCH_GCC

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master

#mcfgthread
git clone https://github.com/lhmouse/mcfgthread.git --branch master

echo "building mcfgthread"
echo "======================="
cd $M_SOURCE/mcfgthread
meson setup build \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
  --cross-file=$TOP_DIR/cross.meson \
  --buildtype=release
meson compile -C build
meson install -C build
rm -rf $M_CROSS/$MINGW_TRIPLE/lib/pkgconfig

echo "building binutils"
echo "======================="
cd $M_BUILD
mkdir binutils-build
cd binutils-build
$M_SOURCE/binutils-$VER_BINUTILS/configure \
  --target=$MINGW_TRIPLE \
  --prefix=$M_CROSS \
  --with-sysroot=$M_CROSS \
  --program-prefix=cross- \
  --disable-multilib \
  --disable-nls \
  --disable-shared \
  --disable-win32-registry \
  --without-included-gettext \
  --enable-lto \
  --enable-plugins \
  --enable-threads
make -j$MJOBS
make install-strip

cd $M_CROSS/bin
ln -s cross-as $MINGW_TRIPLE-as
ln -s cross-ar $MINGW_TRIPLE-ar
ln -s cross-ranlib $MINGW_TRIPLE-ranlib
ln -s cross-dlltool $MINGW_TRIPLE-dlltool
ln -s cross-objcopy $MINGW_TRIPLE-objcopy
ln -s cross-strip $MINGW_TRIPLE-strip
ln -s cross-size $MINGW_TRIPLE-size
ln -s cross-strings $MINGW_TRIPLE-strings
ln -s cross-nm $MINGW_TRIPLE-nm
ln -s cross-readelf $MINGW_TRIPLE-readelf
ln -s cross-windres $MINGW_TRIPLE-windres
ln -s cross-addr2line $MINGW_TRIPLE-addr2line
ln -s $(which pkgconf) $MINGW_TRIPLE-pkg-config
ln -s $(which pkgconf) $MINGW_TRIPLE-pkgconf

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
  --with-default-msvcrt=ucrt
make -j$MJOBS
make install-strip
cd $M_CROSS
ln -s $MINGW_TRIPLE mingw

echo "building gcc-initial"
echo "======================="
cd $M_BUILD
mkdir gcc-build
cd gcc-build
$M_SOURCE/gcc/configure \
  --target=$MINGW_TRIPLE \
  --prefix=$M_CROSS \
  --libdir=$M_CROSS/lib \
  --with-sysroot=$M_CROSS \
  --program-prefix=cross- \
  --with-pkgversion="GCC with MCF thread model" \
  --disable-multilib \
  --enable-languages=c,c++ \
  --disable-nls \
  --disable-win32-registry \
  --with-arch=x86-64-v3 \
  --with-tune=generic \
  --enable-threads=mcf \
  --without-included-gettext \
  --enable-lto \
  --enable-checking=release \
  --disable-sjlj-exceptions
make -j$MJOBS all-gcc
make install-strip-gcc

echo "installing wrappers for x86_64_v3"
echo "======================="
cd $M_CROSS/bin
cp $TOP_DIR/gcc-wrapper-x86_64_v3/x86_64-w64-mingw32-c++ ./
cp $TOP_DIR/gcc-wrapper-x86_64_v3/x86_64-w64-mingw32-cpp ./
cp $TOP_DIR/gcc-wrapper-x86_64_v3/x86_64-w64-mingw32-g++ ./
cp $TOP_DIR/gcc-wrapper-x86_64_v3/x86_64-w64-mingw32-gcc ./
cp $TOP_DIR/gcc-wrapper-x86_64_v3/x86_64-w64-mingw32-ld ./
cp $TOP_DIR/gcc-wrapper-x86_64_v3/x86_64-w64-mingw32-ld.bfd ./

chmod 755 x86_64-w64-mingw32-c++
chmod 755 x86_64-w64-mingw32-cpp
chmod 755 x86_64-w64-mingw32-g++
chmod 755 x86_64-w64-mingw32-gcc
chmod 755 x86_64-w64-mingw32-ld
chmod 755 x86_64-w64-mingw32-ld.bfd

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$M_CROSS
make -j$MJOBS
make install-strip

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
  --disable-lib32
make -j$MJOBS
make install-strip

echo "building gcc-final"
echo "======================="
cd $M_BUILD/gcc-build
make -j$MJOBS
make install-strip
cd $M_CROSS
find $MINGW_TRIPLE/lib -type f -name "*.la" -print0 | xargs -0 -I {} rm {}
find $MINGW_TRIPLE/lib -type f -name "*.dll.a" -print0 | xargs -0 -I {} rm {}
mv $MINGW_TRIPLE/bin/libmcfgthread-1.dll bin
rm -f mingw
rm -rf share
rm -rf include
echo "$VER_GCC" > $M_CROSS/version.txt
