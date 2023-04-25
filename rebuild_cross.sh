#!/bin/bash

# basic param and command line option to change it

TOP_DIR=$(pwd)

source $TOP_DIR/pkg_ver.sh


MACHINE_TYPE=x86_64
# CFLAGS="-pipe -g"
CFLAGS="-pipe -O0"
MINGW_LIB="--enable-lib64 --disable-lib32"
MINGW_TRIPLE="x86_64-w64-mingw32"

if [ "$1" == "-h" ] || [ "$1" == "--help" ] ; then
	echo "$0 [ 64d | 64r | 32d | 32r ]"
	exit 0
fi

if [ "$1" == "64r" ] || [ "$1" == "32r" ] ; then
	CFLAGS="-pipe -O2"
	# CFLAGS="-pipe -O2 -fno-strict-aliasing"
fi

if [ "$1" == "32r" ] || [ "$1" == "32d" ] ; then
	MACHINE_TYPE=i686
	MINGW_LIB="--enable-lib32 --disable-lib64"
	MINGW_TRIPLE="i686-w64-mingw32"
fi

export CFLAGS
export MINGW_LIB
export MINGW_TRIPLE

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross

# export BHT="--build=x86_64-redhat-linux --host=x86_64-redhat-linux --target=$MACHINE_TYPE-w64-mingw32"
export BHT="--target=$MINGW_TRIPLE"

export CXXFLAGS=$CFLAGS

export PATH=$M_CROSS/bin:$PATH

# export MAKE_OPT="-j 2"

set -x

# <1> clean
date

rm -rf $M_CROSS

mkdir -p $M_BUILD
cd $M_BUILD
rm -rf bc_bin bc_gcc bc_m64 bc_m64_head bc_winpth

# <2> build
date
mkdir bc_m64_head
cd bc_m64_head
$M_SOURCE/mingw-w64-v$VER_MINGW64/mingw-w64-headers/configure \
	--host=$MINGW_TRIPLE --prefix=$M_CROSS/$MINGW_TRIPLE
   	# --with-sysroot=$M_CROSS --enable-sdk=directx
	# --enable-sdk=all   (ddk, directx)
make $MAKE_OPT || echo "(-) Build Error!"
make install
cd ..

( cd $M_CROSS ; ln -s $MINGW_TRIPLE mingw ; cd $M_BUILD )


date
mkdir bc_bin
cd bc_bin
$M_SOURCE/binutils-$VER_BINUTILS/configure $BHT --disable-nls \
  --disable-multilib \
  --prefix=$M_CROSS --with-sysroot=$M_CROSS
#  --enable-plugins
# --disable-multilib 
make $MAKE_OPT || echo "(-) Build Error!"
make install
cd ..


# disable begin
if [ "1" == "1" ] ; then

rm -rf bc_gmp bc_mpfr bc_mpc bc_isl $M_BUILD/for_cross

MYABI=32
if [ "$(uname -m)" == "x86_64" ] ; then
MYABI=64
fi

date
mkdir bc_gmp
cd bc_gmp
ABI=$MYABI $M_SOURCE/gmp-$VER_GMP/configure --prefix=$M_BUILD/for_cross --enable-static --disable-shared
make $MAKE_OPT || echo "(-) Build Error!"
make install
cd ..


date
mkdir bc_mpfr
cd bc_mpfr
$M_SOURCE/mpfr-$VER_MPFR/configure --prefix=$M_BUILD/for_cross  --with-gmp=$M_BUILD/for_cross --enable-static --disable-shared
make $MAKE_OPT || echo "(-) Build Error!"
make install
cd ..

date
mkdir bc_mpc
cd bc_mpc
$M_SOURCE/mpc-$VER_MPC/configure --prefix=$M_BUILD/for_cross  --with-gmp=$M_BUILD/for_cross --enable-static --disable-shared
make $MAKE_OPT || echo "(-) Build Error!"
make install
cd ..

date
mkdir bc_isl
cd bc_isl
$M_SOURCE/isl-$VER_ISL/configure --prefix=$M_BUILD/for_cross --with-gmp-prefix=$M_BUILD/for_cross --enable-static --disable-shared
make $MAKE_OPT || echo "(-) Build Error!"
make install
cd ..

#date
#mkdir bc_cloog
#cd bc_cloog
#$M_SOURCE/cloog-$VER_CLOOG/configure --prefix=$M_BUILD/for_cross --with-isl=system --with-isl-prefix=$M_BUILD/for_cross --with-gmp-prefix=$M_BUILD/for_cross --enable-static --disable-shared
#make $MAKE_OPT || echo "(-) Build Error!"
#make install
#cd ..

fi
# disable end


date
mkdir bc_gcc
cd bc_gcc
patch -d $M_SOURCE/gcc-$VER_GCC/gcc/config/i386 -p1 < $M_ROOT/patch/gcc-intrin.patch
# patch -d $M_SOURCE/gcc-$VER_GCC -p1 < $M_ROOT/patch/gcc-pch.patch
$M_SOURCE/gcc-$VER_GCC/configure $BHT --disable-nls \
  --disable-multilib \
  --with-gmp=$M_BUILD/for_cross \
  --with-mpfr=$M_BUILD/for_cross \
  --with-mpc=$M_BUILD/for_cross \
  --with-isl=$M_BUILD/for_cross \
  --enable-languages=c,c++,objc,obj-c++ \
  --disable-libstdcxx-pch \
  --enable-threads=posix --enable-libssp \
  --prefix=$M_CROSS --with-sysroot=$M_CROSS

#  --with-cloog=$M_BUILD/for_cross 
#  BOOT_CFLAGS="-g -O0" CFLAGS="-g -O0" CXXFLAGS="-g -O0" CFLAGS_FOR_BUILD="-g -O0" CFLAGS_FOR_TARGET="-O0" CXXFLAGS_FOR_TARGET="-O0"
#  --disable-multilib --disable-libstdcxx-pch 
make $MAKE_OPT all-gcc || echo "(-) Build Error!"
make install-gcc
cd ..

date
mkdir bc_m64
cd bc_m64
$M_SOURCE/mingw-w64-v$VER_MINGW64/mingw-w64-crt/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE $MINGW_LIB
# # parallel compile may cause error
# make $MAKE_OPT || echo "(-) Build Error!"
make || echo "(-) Build Error!"
make install
cd ..

date
mkdir bc_winpth
cd bc_winpth
$M_SOURCE/mingw-w64-v$VER_MINGW64/mingw-w64-libraries/winpthreads/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_CROSS/$MINGW_TRIPLE $MINGW_LIB
make $MAKE_OPT || echo "(-) Build Error!"
make install
cd ..

date
cd bc_gcc
# make $MAKE_OPT configure-target-libobjc
# patch -d ./$MINGW_TRIPLE/libobjc/ -p0 < $M_ROOT/patch/gcc-libobjc.patch
make $MAKE_OPT || echo "(-) Build Error!"
make install
patch -d $M_SOURCE/gcc-$VER_GCC/gcc/config/i386 -p1 -R < $M_ROOT/patch/gcc-intrin.patch
# patch -d $M_SOURCE/gcc-$VER_GCC -p1 -R < $M_ROOT/patch/gcc-pch.patch
cd ..

# date 
# mkdir bc_gdb
# cd bc_gdb
# $M_SOURCE/gdb/configure $BHT --disable-nls \
# 	--disable-werror \
# 	--prefix=$M_CROSS
# make $MAKE_OPT || echo "(-) Build Error!"
# make install
# cd ..

# <3> finish
cd $M_ROOT
date

