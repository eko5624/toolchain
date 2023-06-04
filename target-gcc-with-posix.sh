#!/bin/bash
set -e

TOP_DIR=$(pwd)

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

#CFLAGS="-pipe -O2"
MINGW_TRIPLE="x86_64-w64-mingw32"

#export CFLAGS
#export CXXFLAGS=$CFLAGS
export MINGW_TRIPLE

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross
export M_TARGET=$M_ROOT/target

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

export PATH="$M_CROSS/bin:$PATH"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "gettiong source"
echo "======================="
cd $M_SOURCE

#binutils
wget -c -O binutils-2.40.tar.bz2 http://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.bz2
tar xjf binutils-2.40.tar.bz2

#gcc
wget -c -O gcc-13.1.0.tar.xz https://ftp.gnu.org/gnu/gcc/gcc-13.1.0/gcc-13.1.0.tar.xz
xz -c -d gcc-13.1.0.tar.xz | tar xf -

#gmp
wget -c -O gmp-6.2.1.tar.bz2 https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.bz2
tar xjf gmp-6.2.1.tar.bz2

#mpfr
wget -c -O mpfr-4.2.0.tar.bz2 https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.0.tar.bz2
tar xjf mpfr-4.2.0.tar.bz2

#MPC
wget -c -O mpc-1.3.1.tar.gz https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz
tar xzf mpc-1.3.1.tar.gz

#isl
wget -c -O isl-0.24.tar.bz2 https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.24.tar.bz2
tar xjf isl-0.24.tar.bz2

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master --depth 1

#mcfgthread
git clone https://github.com/lhmouse/mcfgthread.git --branch master --depth 1

#libdl (dlfcn-win32)
git clone https://github.com/dlfcn-win32/dlfcn-win32 --branch master --depth 1

#make
wget -c -O make-4.4.1.tar.gz https://ftp.gnu.org/pub/gnu/make/make-4.4.1.tar.gz
tar xzf make-4.4.1.tar.gz

echo "building binutils"
echo "======================="
mkdir binutils-build
cd binutils-build
$M_SOURCE/binutils-2.40/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --with-sysroot=$M_TARGET \
  --disable-nls \
  --disable-werror \
  --disable-shared
make -j$MJOBS
make install
cd $M_BUILD

echo "building gmp"
echo "======================="
mkdir gmp-build
cd gmp-build
$M_SOURCE/gmp-6.2.1/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install
cd $M_BUILD

echo "building mpfr"
echo "======================="
mkdir mpfr-build
cd mpfr-build
$M_SOURCE/mpfr-4.2.0/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --with-gmp=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install
cd $M_BUILD

echo "building MPC"
echo "======================="
mkdir mpc-build
cd mpc-build
$M_SOURCE/mpc-1.3.1/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --with-gmp=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install
cd $M_BUILD

echo "building isl"
echo "======================="
mkdir isl-build
cd isl-build
$M_SOURCE/isl-0.24/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --with-gmp-prefix=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install
cd $M_BUILD

echo "building mingw-w64-headers"
echo "======================="
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
cd $M_BUILD

echo "building mingw-w64-crt"
echo "======================="
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
cd $M_BUILD

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
cd $M_BUILD

echo "building winpthreads"
echo "======================="
mkdir winpthreads-build
cd winpthreads-build
$M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET/$MINGW_TRIPLE \
  --with-sysroot=$M_TARGET \
  --enable-shared \
  --enable-static
make -j$MJOBS
make install
cd $M_BUILD

#echo "building dlfcn-win32"
#echo "======================="
mkdir libdl-build
#$M_SOURCE/dlfcn-win32/configure \
cmake -G Ninja -H$M_SOURCE/dlfcn-win32 -B$M_BUILD/libdl-build \
  -DCMAKE_INSTALL_PREFIX=$TOP_DIR/opt \
  -DCMAKE_TOOLCHAIN_FILE=$TOP_DIR/toolchain.cmake \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTS=OFF
ninja -j$MJOBS -C $M_BUILD/libdl-build
ninja install -C $M_BUILD/libdl-build

#echo "building zlib"
#echo "======================="
#mkdir zlib-build
#cd zlib-build
#curl -OL https://raw.githubusercontent.com/shinchiro/mpv-winbuild-cmake/master/packages/zlib-1-win32-static.patch
#patch -d $M_SOURCE/zlib-1.2.13 -p1 < $M_BUILD/zlib-build/zlib-1-win32-static.patch
#CHOST=$MINGW_TRIPLE $M_SOURCE/zlib-1.2.13/configure \
#  --prefix=$M_TARGET/zlib \
#  --static
#make -j$MJOBS
#make install
#cd $M_BUILD

#echo "building libiconv"
#echo "======================="
#mkdir libiconv-build
#cd libiconv-build
#$M_SOURCE/libiconv-1.17/configure \
#  --build=x86_64-pc-linux-gnu \
#  --host=$MINGW_TRIPLE \
#  --target=$MINGW_TRIPLE \
#  --prefix=$M_TARGET \
#  --host=$MINGW_TRIPLE \
#  --target=$MINGW_TRIPLE \
#  --enable-extra-encodings \
#  --enable-static \
#  --disable-shared \
#  --disable-nls \
#  --with-gnu-ld
#make -j$MJOBS
#make install

echo "building gcc"
echo "======================="
mkdir gcc-build
cd gcc-build
CFLAGS='-I$TOP_DIR/opt/include -Wno-int-conversion  -march=nocona -msahf -mtune=generic -O2' 
CXXFLAGS='-Wno-int-conversion  -march=nocona -msahf -mtune=generic -O2' 
LDFLAGS='-pthread  -Wl,--dynamicbase -Wl,--high-entropy-va -Wl,--nxcompat -Wl,--tsaware'
$M_SOURCE/gcc-13.1.0/configure \
  --build=x86_64-pc-linux-gnu \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --with-sysroot=$M_TARGET \
  --with-{gmp,mpfr,mpc,isl}=$M_BUILD/for_target \
  --enable-offload-targets=nvptx-none \
  --with-tune=generic \
  --enable-checking=release \
  --enable-threads=posix \
  --disable-sjlj-exceptions \
  --disable-libunwind-exceptions \
  --disable-serial-configure \
  --disable-bootstrap \
  --enable-host-shared \
  --enable-plugin \
  --disable-default-ssp \
  --disable-rpath \
  --disable-libstdcxx-debug \
  --disable-version-specific-runtime-libs \
  --with-stabs \
  --disable-symvers \
  --enable-languages=c,c++ \
  --disable-gold \
  --disable-nls \
  --disable-stage1-checking \
  --disable-win32-registry \
  --disable-multilib \
  --enable-ld \
  --enable-libquadmath \
  --enable-libada \
  --enable-libssp \
  --enable-libstdcxx \
  --enable-lto \
  --enable-fully-dynamic-string \
  --enable-libgomp \
  --enable-graphite \
  --enable-mingw-wildcard \
  --enable-libstdcxx-time \
  --enable-libstdcxx-pch \
  --disable-libstdcxx-backtrace \
  --enable-install-libiberty \
  --enable-__cxa_atexit \
  --without-included-gettext \
  --with-diagnostics-color=auto \
  --enable-clocale=generic \
  --with-libiconv \
  --with-pkgversion="GCC with posix thread model"
make -j$MJOBS
make install
#cp $M_TARGET/lib/libgcc_s_seh-1.dll $M_TARGET/bin/
#cp $M_TARGET/$MINGW_TRIPLE/bin/libwinpthread-1.dll $M_TARGET/bin/
cp $M_TARGET/bin/gcc.exe $M_TARGET/bin/cc.exe
cd $M_BUILD

echo "building make"
echo "======================="
mkdir make-build
cd make-build
$M_SOURCE/make-4.4.1/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET
make -j$MJOBS
make install
cp $M_TARGET/bin/make.exe $M_TARGET/bin/mingw32-make.exe
cd $M_TARGET
rm -f mingw
