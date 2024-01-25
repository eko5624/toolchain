#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh
export BRANCH_GCC=releases/gcc-13

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export CFLAGS="-pipe -O2"
export CXXFLAGS=$CFLAGS
export MINGW_TRIPLE="x86_64-w64-mingw32"

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross
export RUSTUP_LOCATION=$M_ROOT/rust

export PATH="$M_CROSS/bin:$RUSTUP_LOCATION/.cargo/bin:$PATH"
export RUSTUP_HOME="$RUSTUP_LOCATION/.rustup"
export CARGO_HOME="$RUSTUP_LOCATION/.cargo"

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

#pkgconf
#git clone https://github.com/pkgconf/pkgconf --branch pkgconf-1.9.5

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
make install
cd $M_CROSS
ln -s $MINGW_TRIPLE mingw

echo "building mcfgthread"
echo "======================="
cd $M_SOURCE/mcfgthread
autoreconf -ivf
cd $M_BUILD
mkdir mcfgthread-build
cd mcfgthread-build
$M_SOURCE/mcfgthread/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE \
  --disable-pch
make -j$MJOBS
make install

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
  --with-pkgversion="GCC with MCF thread model" \
  --disable-multilib \
  --enable-languages=c,c++ \
  --disable-nls \
  --disable-win32-registry \
  --disable-libstdcxx-pch \
  --with-arch=x86-64 \
  --with-tune=generic \
  --enable-threads=mcf \
  --enable-libstdcxx-threads=yes \
  --without-included-gettext \
  --enable-lto \
  --enable-checking=release
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

echo "building gcc-final"
echo "======================="
cd $M_BUILD/gcc-build
make -j$MJOBS
make install
cd $M_CROSS
find $MINGW_TRIPLE/lib -type f -name "*.la" -print0 | xargs -0 -I {} rm {}
find $MINGW_TRIPLE/lib -type f -name "*.dll.a" -print0 | xargs -0 -I {} rm {}
mv $MINGW_TRIPLE/bin/libmcfgthread-1.dll bin
rm -f mingw
rm -rf share
echo "$VER_GCC" > $M_CROSS/version.txt

echo "building rustup"
echo "======================="
curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --target x86_64-pc-windows-gnu --no-modify-path --profile minimal
rustup update
cargo install cargo-c --profile=release-strip --features=vendored-openssl
cat <<EOF >$CARGO_HOME/config
[net]
git-fetch-with-cli = true

[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
ar = "x86_64-w64-mingw32-ar"
rustflags = ["-C", "target-cpu=x86-64"]

[profile.release]
panic = "abort"
strip = true
EOF
