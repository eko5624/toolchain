#!/bin/bash
set -e

TOP_DIR=$(pwd)

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

CFLAGS="-pipe -O2"
MINGW_TRIPLE="x86_64-w64-mingw32"
export MINGW_TRIPLE
export CFLAGS
export CXXFLAGS=$CFLAGS

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross

export PATH="$M_CROSS/bin:$PATH"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "gettiong json ver"
echo "======================="
json_ver=$(curl -s "https://raw.githubusercontent.com/eko5624/nginx-nosni/master/old.json")
declare -A ver_array
while IFS="=" read -r key value; do
    ver_array[$key]=$value
done < <(echo "$json_ver" | jq -r 'to_entries | map("\(.key)=\(.value|tostring)") | .[]')

echo "gettiong source"
echo "======================="
cd $M_SOURCE

VER_BINUTILS=${ver[binutils]}
VER_GCC=${ver[GCC]}

#binutils
wget -c -O binutils-$VER_BINUTILS.tar.bz2 http://ftp.gnu.org/gnu/binutils/binutils-$VER_BINUTILS.tar.bz2
tar xjf binutils-$VER_BINUTILS.tar.bz2

#gcc
wget -c -O gcc-$VER_GCC.tar.xz https://ftp.gnu.org/gnu/gcc/gcc-$VER_GCC/gcc-$VER_GCC.tar.xz
xz -c -d gcc-$VER_GCC.tar.xz | tar xf -

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master --depth 1

echo "building binutils"
echo "======================="
cd $M_BUILD
mkdir binutils-build
cd binutils-build
$M_SOURCE/binutils-$VER_BINUTILS/configure \
  --target=$MINGW_TRIPLE \
  --prefix=$M_CROSS \
  --with-sysroot=$M_CROSS \
  --disable-multilib \
  --disable-nls \
  --disable-shared \
  --disable-win32-registry \
  --without-included-gettext \
  --enable-lto \
  --enable-plugins \
  --enable-threads
make -j$MJOBS
make install
cd $M_CROSS/bin
ln -s $(which pkg-config) $MINGW_TRIPLE-pkg-config
ln -s $(which pkg-config) $MINGW_TRIPLE-pkgconf

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
make install
cd $M_CROSS
ln -s $MINGW_TRIPLE mingw

echo "building gcc-initial"
echo "======================="
cd $M_BUILD
mkdir gcc-build
cd gcc-build
$M_SOURCE/gcc-$VER_GCC/configure \
  --target=$MINGW_TRIPLE \
  --prefix=$M_CROSS \
  --libdir=$M_CROSS/lib \
  --with-sysroot=$M_CROSS \
  --with-pkgversion="GCC with posix thread model" \
  --disable-multilib \
  --enable-languages=c,c++ \
  --disable-nls \
  --disable-shared \
  --disable-win32-registry \
  --disable-libstdcxx-pch \
  --with-arch=x86-64 \
  --with-tune=generic \
  --enable-threads=posix \
  --without-included-gettext \
  --enable-lto \
  --enable-checking=release \
  --disable-sjlj-exceptions
make -j$MJOBS all-gcc
make install-strip-gcc

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
  --disable-lib32
make -j$MJOBS
make install

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

echo "building gcc-final"
echo "======================="
cd $M_BUILD/gcc-build
make -j$MJOBS
make install
cd $M_CROSS
find $MINGW_TRIPLE/lib -type f -name "*.la" -print0 | xargs -0 -I {} rm {}
find $MINGW_TRIPLE/lib -type f -name "*.dll.a" -print0 | xargs -0 -I {} rm {}
rm -f mingw
rm -rf share
echo "$VER_GCC" > $M_CROSS/version.txt
