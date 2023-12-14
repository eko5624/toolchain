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
export M_TARGET=$M_ROOT/target

export MINGW_TRIPLE="x86_64-w64-mingw32"
export TOOLCHAIN_ARCHS="x86_64"
export TOOLCHAIN_TARGET_OSES="mingw32"
export PATH="$M_CROSS/bin:$PATH"
export CLANG_VER="17"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "getting source"
echo "======================="
cd $M_SOURCE
#make
wget -c -O make-$VER_MAKE.tar.gz https://ftp.gnu.org/pub/gnu/make/make-$VER_MAKE.tar.gz
tar xzf make-$VER_MAKE.tar.gz

#cmake
#git clone https://github.com/Kitware/CMake.git --branch v$VER_CMAKE
curl -OL https://github.com/Kitware/CMake/releases/download/v$VER_CMAKE/cmake-$VER_CMAKE-windows-x86_64.zip
7z x cmake*.zip

#ninja
curl -OL https://github.com/ninja-build/ninja/releases/download/v$VER_NINJA/ninja-win.zip
7z x ninja*.zip

#yasm
#wget -c -O yasm-$VER_YASM.tar.gz http://www.tortall.net/projects/yasm/releases/yasm-$VER_YASM.tar.gz
#tar xzf yasm-$VER_YASM.tar.gz
curl -OL https://github.com/yasm/yasm/releases/download/v$VER_YASM/yasm-$VER_YASM-win64.exe

#nasm
# nasm 2.16.01 faild, fatal error: asm/warnings.c: No such file or directory. Stick to 2.15.05.
#wget -c -O nasm-$VER_NASM.tar.gz http://www.nasm.us/pub/nasm/releasebuilds/$VER_NASM/nasm-$VER_NASM.tar.gz
#tar xzf nasm-$VER_NASM.tar.gz
curl -OL https://www.nasm.us/pub/nasm/releasebuilds/$VER_NASM/win64/nasm-$VER_NASM-win64.zip
7z x nasm*.zip

#curl
curl -L -o curl-win64-mingw.zip 'https://curl.se/windows/latest.cgi?p=win64-mingw.zip'
7z x curl*.zip

#pkgconf
git clone https://github.com/pkgconf/pkgconf --branch pkgconf-$VER_PKGCONF

echo "building pkgconf"
echo "======================="
cd $M_BUILD
mkdir pkgconf-build && cd pkgconf-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-pkgconf/0002-size-t-format.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-pkgconf/0003-printf-format.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-pkgconf/0004-default-pure-static.patch

cd $M_SOURCE/pkgconf
# https://github.com/msys2/MINGW-packages/issues/8473
patch -R -p1 -i $M_BUILD/pkgconf-build/0004-default-pure-static.patch
patch -p1 -i $M_BUILD/pkgconf-build/0002-size-t-format.patch
patch -p1 -i $M_BUILD/pkgconf-build/0003-printf-format.patch

meson setup $M_BUILD/pkgconf-build \
  --prefix=$M_TARGET \
  --cross-file=$TOP_DIR/cross.meson \
  --buildtype=release \
  -Dtests=disabled
meson compile -C $M_BUILD/pkgconf-build
meson install -C $M_BUILD/pkgconf-build
cp $M_TARGET/bin/pkgconf.exe $M_TARGET/bin/pkg-config.exe
cp $M_TARGET/bin/pkgconf.exe $M_TARGET/bin/x86_64-w64-mingw32-pkg-config.exe

echo "copy yasm nasm cmake ninja curl"
echo "======================="
cd $M_TARGET
cp $M_SOURCE/nasm-$VER_NASM/*.exe bin
cp $M_SOURCE/yasm-$VER_YASM-win64.exe bin/yasm.exe
cp $M_SOURCE/cmake-$VER_CMAKE-windows-x86_64/bin/cmake.exe bin
cp -r $M_SOURCE/cmake-$VER_CMAKE-windows-x86_64/share/cmake* share
cp $M_SOURCE/ninja.exe bin
cp $M_SOURCE/curl*/bin/curl-ca-bundle.crt bin
cp $M_SOURCE/curl*/bin/curl.exe bin
echo "... Done"
