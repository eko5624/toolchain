#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross
export M_TARGET=$M_ROOT/target
export MINGW_TRIPLE="x86_64-w64-mingw32"
export BRANCH_GCC=releases/gcc-${VER_GCC%%.*}

export PATH="$M_CROSS/bin:$PATH"
export CC=$M_CROSS/bin/$MINGW_TRIPLE-gcc
export CXX=$M_CROSS/bin/$MINGW_TRIPLE-g++
export AR=$M_CROSS/bin/$MINGW_TRIPLE-ar
export RANLIB=$M_CROSS/bin/$MINGW_TRIPLE-ranlib
export AS=$M_CROSS/bin/$MINGW_TRIPLE-as
export LD=$M_CROSS/bin/$MINGW_TRIPLE-ld
export STRIP=$M_CROSS/bin/$MINGW_TRIPLE-strip
export NM=$M_CROSS/bin/$MINGW_TRIPLE-nm
export DLLTOOL=$M_CROSS/bin/$MINGW_TRIPLE-dlltool
export WINDRES=$M_CROSS/bin/$MINGW_TRIPLE-windres

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "gettiong source"
echo "======================="
cd $M_SOURCE

#binutils
wget -c -O binutils-$VER_BINUTILS.tar.bz2 https://ftp.gnu.org/gnu/binutils/binutils-$VER_BINUTILS.tar.bz2
tar xjf binutils-$VER_BINUTILS.tar.bz2

#gcc
#wget -c -O gcc-$VER_GCC.tar.xz https://ftp.gnu.org/gnu/gcc/gcc-$VER_GCC/gcc-$VER_GCC.tar.xz
#xz -c -d gcc-$VER_GCC.tar.xz | tar xf -

#gmp
wget -c -O gmp-$VER_GMP.tar.bz2 https://ftp.gnu.org/gnu/gmp/gmp-$VER_GMP.tar.bz2
tar xjf gmp-$VER_GMP.tar.bz2

#mpfr
wget -c -O mpfr-$VER_MPFR.tar.bz2 https://ftp.gnu.org/gnu/mpfr/mpfr-$VER_MPFR.tar.bz2
tar xjf mpfr-$VER_MPFR.tar.bz2

#MPC
wget -c -O mpc-$VER_MPC.tar.gz https://ftp.gnu.org/gnu/mpc/mpc-$VER_MPC.tar.gz
tar xzf mpc-$VER_MPC.tar.gz

#isl
wget -c -O isl-$VER_ISL.tar.bz2 https://gcc.gnu.org/pub/gcc/infrastructure/isl-$VER_ISL.tar.bz2
tar xjf isl-$VER_ISL.tar.bz2

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master --depth 1

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
#curl -OL https://github.com/yasm/yasm/releases/download/v$VER_YASM/yasm-$VER_YASM-win64.exe
wget -c -O yasm-$VER_YASM.tar.gz http://www.tortall.net/projects/yasm/releases/yasm-$VER_YASM.tar.gz
tar xzf yasm-$VER_YASM.tar.gz

#nasm
#curl -OL https://www.nasm.us/pub/nasm/releasebuilds/$VER_NASM/win64/nasm-$VER_NASM-win64.zip
#7z x nasm*.zip
#wget -c -O nasm-$VER_NASM.tar.gz http://www.nasm.us/pub/nasm/releasebuilds/$VER_NASM/nasm-$VER_NASM.tar.gz
#tar xzf nasm-$VER_NASM.tar.gz
git clone https://github.com/netwide-assembler/nasm.git --branch nasm-$VER_NASM


#curl
curl -L -o curl-win64-mingw.zip 'https://curl.se/windows/latest.cgi?p=win64-mingw.zip'
7z x curl*.zip

#pkgconf
git clone https://github.com/pkgconf/pkgconf --branch pkgconf-$VER_PKGCONF

#windows-default-manifest
git clone https://sourceware.org/git/cygwin-apps/windows-default-manifest.git

echo "building gmp"
echo "======================="
cd $M_BUILD
mkdir gmp-build
cd gmp-build
$M_SOURCE/gmp-$VER_GMP/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install

echo "building mpfr"
echo "======================="
cd $M_BUILD
mkdir mpfr-build
cd mpfr-build
$M_SOURCE/mpfr-$VER_MPFR/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --with-gmp=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install

echo "building MPC"
echo "======================="
cd $M_BUILD
mkdir mpc-build
cd mpc-build
$M_SOURCE/mpc-$VER_MPC/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --with-{gmp,mpfr}=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install

echo "building isl"
echo "======================="
cd $M_BUILD
mkdir isl-build
cd isl-build
$M_SOURCE/isl-$VER_ISL/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --with-gmp-prefix=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install

echo "building binutils"
echo "======================="
cd $M_BUILD
mkdir binutils-build
cd binutils-build
$M_SOURCE/binutils-$VER_BINUTILS/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --with-sysroot=$M_TARGET \
  --disable-multilib \
  --disable-nls \
  --disable-werror \
  --disable-shared \
  --enable-lto \
  --enable-64-bit-bfd
make -j$MJOBS
make install

echo "building mingw-w64-headers"
echo "======================="
cd $M_BUILD
mkdir headers-build
cd headers-build
$M_SOURCE/mingw-w64/mingw-w64-headers/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET/$MINGW_TRIPLE \
  --enable-sdk=all \
  --with-default-msvcrt=ucrt \
  --enable-idl \
  --without-widl
make -j$MJOBS
make install
cd $M_TARGET
ln -s $MINGW_TRIPLE mingw

echo "building winpthreads"
echo "======================="
cd $M_BUILD
mkdir winpthreads-build
cd winpthreads-build
$M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET/$MINGW_TRIPLE \
  --enable-static \
  --enable-shared
make -j$MJOBS
make install
mv $M_TARGET/$MINGW_TRIPLE/bin/libwinpthread-1.dll $M_TARGET/bin/

echo "building mingw-w64-crt"
echo "======================="
cd $M_BUILD
mkdir crt-build
cd $M_SOURCE/mingw-w64/mingw-w64-crt
autoreconf -ivf
cd $M_BUILD/crt-build
$M_SOURCE/mingw-w64/mingw-w64-crt/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET/$MINGW_TRIPLE \
  --with-sysroot=$M_TARGET \
  --with-default-msvcrt=ucrt \
  --enable-wildcard \
  --disable-dependency-tracking \
  --enable-lib64 \
  --disable-lib32
make -j$MJOBS
make install

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET
make -j$MJOBS
make install

echo "building gcc"
echo "======================="
cd $M_SOURCE
#git clone https://github.com/gcc-mirror/gcc.git --branch releases/gcc-$BRANCH_GCC
git clone https://github.com/gcc-mirror/gcc.git --branch releases/gcc-$VER_GCC

cd gcc
_gcc_version=$(head -n 34 gcc/BASE-VER | sed -e 's/.* //' | tr -d '"\n')
_gcc_date=$(head -n 34 gcc/DATESTAMP | sed -e 's/.* //' | tr -d '"\n')
VER=$(printf "%s-%s" "$_gcc_version" "$_gcc_date")
cd $M_BUILD
mkdir gcc-build && cd gcc-build
$M_SOURCE/gcc/configure \
  --build=x86_64-pc-linux-gnu \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --libexecdir=$M_TARGET/lib \
  --with-sysroot=$M_TARGET \
  --with-{gmp,mpfr,mpc,isl}=$M_BUILD/for_target \
  --disable-rpath \
  --disable-multilib \
  --disable-dependency-tracking \
  --disable-bootstrap \
  --disable-nls \
  --disable-werror \
  --disable-symvers \
  --disable-libstdcxx-pch \
  --disable-libstdcxx-debug \
  --disable-libstdcxx-backtrace \
  --disable-win32-registry \
  --disable-version-specific-runtime-libs \
  --enable-languages=c,c++ \
  --enable-fully-dynamic-string \
  --enable-libstdcxx-filesystem-ts \
  --enable-libstdcxx-time \
  --enable-libatomic \
  --enable-libgomp \
  --enable-libssp \
  --enable-__cxa_atexit \
  --enable-graphite \
  --enable-mingw-wildcard \
  --enable-threads=win32 \
  --enable-libstdcxx-threads=yes \
  --enable-lto \
  --enable-checking=release \
  --enable-static \
  --enable-shared \
  --with-arch=nocona \
  --with-tune=generic \
  --without-included-gettext \
  --with-pkgversion="GCC with win32 thread model" \
  CFLAGS='-O2' \
  CXXFLAGS='-O2' \
  LDFLAGS='-Wl,--no-insert-timestamp -Wl,--dynamicbase -Wl,--high-entropy-va -Wl,--nxcompat -Wl,--tsaware'
make -j$MJOBS
make install

find $M_TARGET/lib -type f \( -name "*.dll.a" \) -print0 | xargs -0 -I {} rm {}
find $M_TARGET/lib -type f -name "*.la" -print0 | xargs -0 -I {} rm {}

cp $M_TARGET/lib/libgcc_s_seh-1.dll $M_TARGET/bin/
cp $M_TARGET/bin/gcc.exe $M_TARGET/bin/cc.exe
cp $M_TARGET/bin/$MINGW_TRIPLE-gcc.exe $M_TARGET/bin/$MINGW_TRIPLE-cc.exe
for f in $M_TARGET/bin/*.exe; do
  strip -s $f
done
for f in $M_TARGET/lib/gcc/x86_64-w64-mingw32/${VER%%-*}/*.exe; do
  strip -s $f
done

echo "building windows-default-manifest"
echo "======================="
cd $M_BUILD
mkdir windows-default-manifest-build
cd windows-default-manifest-build
$M_SOURCE/windows-default-manifest/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET
make -j$MJOBS
make install

echo "building make"
echo "======================="
cd $M_BUILD
mkdir make-build && cd make-build
$M_SOURCE/make-$VER_MAKE/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --program-prefix=mingw32- \
  --disable-nls
make -j$MJOBS
make install

echo "building yasm"
echo "======================="
cd $M_SOURCE/yasm-$VER_YASM
./configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET
make -j$MJOBS
make install
rm -rf $M_TARGET/include/libyasm
rm $M_TARGET/include/libyasm*
rm $M_TARGET/lib/libyasm.a

echo "building nasm"
echo "======================="
cd $M_SOURCE/nasm
# work around /usr/bin/install: cannot stat './nasm.1': No such file or directory
sed -i "/man1/d" Makefile.in
./autogen.sh
./configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET
make -j$MJOBS
make install

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
rm -rf $M_TARGET/lib/pkgconfig

cd $M_TARGET
rm -rf doc || true
rm -rf man || true
rm -f mingw
echo "$VER" > $M_TARGET/version.txt

cp $M_SOURCE/cmake-$VER_CMAKE-windows-x86_64/bin/cmake.exe bin
cp -r $M_SOURCE/cmake-$VER_CMAKE-windows-x86_64/share/cmake* share
cp $M_SOURCE/ninja.exe bin
cp $M_SOURCE/curl*/bin/curl-ca-bundle.crt bin
cp $M_SOURCE/curl*/bin/curl.exe bin
