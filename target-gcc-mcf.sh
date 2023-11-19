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
wget -c -O binutils-$VER_BINUTILS.tar.bz2 http://ftp.gnu.org/gnu/binutils/binutils-$VER_BINUTILS.tar.bz2
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
git clone https://github.com/mingw-w64/mingw-w64.git --branch master

#mcfgthread
git clone https://github.com/lhmouse/mcfgthread.git --branch master

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

#windows-default-manifest
git clone https://sourceware.org/git/cygwin-apps/windows-default-manifest.git

echo "building gmp"
echo "======================="
cd $M_BUILD
mkdir gmp-build && cd gmp-build
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
mkdir mpfr-build && cd mpfr-build
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
mkdir mpc-build && cd mpc-build
$M_SOURCE/mpc-$VER_MPC/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_BUILD/for_target \
  --with-gmp=$M_BUILD/for_target \
  --enable-static \
  --disable-shared
make -j$MJOBS
make install

echo "building isl"
echo "======================="
cd $M_BUILD
mkdir isl-build && cd isl-build
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
mkdir binutils-build && cd binutils-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/0002-check-for-unusual-file-harder.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/0010-bfd-Increase-_bfd_coff_max_nscns-to-65279.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/0110-binutils-mingw-gnu-print.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/0410-windres-handle-spaces.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/0500-fix-weak-undef-symbols-after-image-base-change.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/2001-ld-option-to-move-default-bases-under-4GB.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/2003-Restore-old-behaviour-of-windres-so-that-options-con.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/libiberty-unlink-handle-windows-nul.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/reproducible-import-libraries.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/specify-timestamp.patch
curl -L -o 6aadf8a04d162feb2afe3c41f5b36534d661d447.patch "https://sourceware.org/git/?p=binutils-gdb.git;a=commitdiff_plain;h=6aadf8a04d162feb2afe3c41f5b36534d661d447"
curl -L -o 398f1ddf5e89e066aeee242ea854dcbaa8eb9539.patch "https://sourceware.org/git/?p=binutils-gdb.git;a=commitdiff_plain;h=398f1ddf5e89e066aeee242ea854dcbaa8eb9539"
curl -L -o 26d0081b52dc482c59abba23ca495304e698ce4b.patch "https://sourceware.org/git/?p=binutils-gdb.git;a=commitdiff_plain;h=26d0081b52dc482c59abba23ca495304e698ce4b"
curl -L -o 8606b47e94078e77a53f3cd714272c853d2add22.patch "https://sourceware.org/git/?p=binutils-gdb.git;a=commitdiff_plain;h=8606b47e94078e77a53f3cd714272c853d2add22"
curl -L -o 54d57acf610e5db2e70afa234fd4018207606774.patch "https://sourceware.org/git/?p=binutils-gdb.git;a=commitdiff_plain;h=54d57acf610e5db2e70afa234fd4018207606774"

apply_patch_with_msg() {
  for patch in "$@"; do
    echo "Applying $patch"
    patch -p1 -i "$M_BUILD/binutils-build/$patch"
  done
}

cd $M_SOURCE/binutils-$VER_BINUTILS
apply_patch_with_msg \
  0002-check-for-unusual-file-harder.patch \
  0010-bfd-Increase-_bfd_coff_max_nscns-to-65279.patch \
  0110-binutils-mingw-gnu-print.patch

# Add an option to change default bases back below 4GB to ease transition
# https://github.com/msys2/MINGW-packages/issues/7027
# https://github.com/msys2/MINGW-packages/issues/7023
apply_patch_with_msg 2001-ld-option-to-move-default-bases-under-4GB.patch

# https://github.com/msys2/MINGW-packages/pull/9233#issuecomment-889439433
patch -R -p1 -i $M_BUILD/binutils-build/2003-Restore-old-behaviour-of-windres-so-that-options-con.patch

# patches for reproducibility from Debian:
# https://salsa.debian.org/mingw-w64-team/binutils-mingw-w64/-/tree/master/debian/patches
patch -p2 -i $M_BUILD/binutils-build/reproducible-import-libraries.patch
patch -p2 -i $M_BUILD/binutils-build/specify-timestamp.patch

# Handle Windows nul device
# https://github.com/msys2/MINGW-packages/issues/1840
# https://github.com/msys2/MINGW-packages/issues/10520
# https://github.com/msys2/MINGW-packages/issues/14725

# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=108276
# https://gcc.gnu.org/pipermail/gcc-patches/2023-January/609487.html
patch -p1 -i $M_BUILD/binutils-build/libiberty-unlink-handle-windows-nul.patch

apply_patch_with_msg \
  6aadf8a04d162feb2afe3c41f5b36534d661d447.patch \
  398f1ddf5e89e066aeee242ea854dcbaa8eb9539.patch \
  26d0081b52dc482c59abba23ca495304e698ce4b.patch \
  8606b47e94078e77a53f3cd714272c853d2add22.patch \
  54d57acf610e5db2e70afa234fd4018207606774.patch

cd $M_BUILD/binutils-build
$M_SOURCE/binutils-$VER_BINUTILS/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --with-sysroot=$M_TARGET \
  --disable-nls \
  --disable-werror \
  --disable-shared \
  --enable-lto
make -j$MJOBS
make install

echo "building mingw-w64-headers"
echo "======================="
cd $M_BUILD
mkdir headers-build && cd headers-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-headers-git/0001-Allow-to-use-bessel-and-complex-functions-without-un.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-headers-git/0002-heades-add-full-name-winrt.patch

cd $M_SOURCE/mingw-w64
git apply $M_BUILD/headers-build/0001-Allow-to-use-bessel-and-complex-functions-without-un.patch
git apply $M_BUILD/headers-build/0002-heades-add-full-name-winrt.patch

cd $M_SOURCE/mingw-w64/mingw-w64-headers
touch include/windows.*.h include/wincrypt.h include/prsht.h

cd $M_BUILD/headers-build
$M_SOURCE/mingw-w64/mingw-w64-headers/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --enable-sdk=all \
  --with-default-win32-winnt=0x601 \
  --with-default-msvcrt=ucrt \
  --enable-idl \
  --without-widl
make -j$MJOBS
make install
cd $M_TARGET
ln -s $MINGW_TRIPLE mingw
rm $M_TARGET/include/pthread_signal.h
rm $M_TARGET/include/pthread_time.h
rm $M_TARGET/include/pthread_unistd.h

echo "building winpthreads"
echo "======================="
cd $M_BUILD
mkdir winpthreads-build && cd winpthreads-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-winpthreads-git/0001-Define-__-de-register_frame_info-in-fake-libgcc_s.patch

cd $M_SOURCE/mingw-w64
git apply $M_BUILD/winpthreads-build/0001-Define-__-de-register_frame_info-in-fake-libgcc_s.patch

cd $M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads
autoreconf -vfi

cd $M_BUILD/winpthreads-build
$M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --enable-static \
  --enable-shared
make -j$MJOBS
make install
#cp $M_TARGET/$MINGW_TRIPLE/bin/libwinpthread-1.dll $M_TARGET/bin/

echo "building mcfgthread"
echo "======================="
cd $M_SOURCE/mcfgthread
git reset --hard
git clean -fdx
autoreconf -ivf

cd $M_BUILD
mkdir mcfgthread-build && cd mcfgthread-build
$M_SOURCE/mcfgthread/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --disable-pch
make -j$MJOBS
make install
#cp $M_TARGET/$MINGW_TRIPLE/bin/libmcfgthread-1.dll $M_TARGET/bin/

echo "building mingw-w64-crt"
echo "======================="
cd $M_BUILD
mkdir crt-build && cd crt-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-crt-git/0001-Allow-to-use-bessel-and-complex-functions-without-un.patch

cd $M_SOURCE/mingw-w64
git reset --hard
git clean -fdx
(cd mingw-w64-crt && automake)
git apply $M_BUILD/crt-build/0001-Allow-to-use-bessel-and-complex-functions-without-un.patch

cd $M_BUILD/crt-build
$M_SOURCE/mingw-w64/mingw-w64-crt/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --with-sysroot=$M_TARGET \
  --with-default-msvcrt=ucrt \
  --enable-wildcard \
  --disable-dependency-tracking \
  --enable-lib64 \
  --disable-lib32
make -j$MJOBS
make install
# Create empty dummy archives, to avoid failing when the compiler driver
# adds -lssp -lssh_nonshared when linking.
ar rcs $M_TARGET/lib/libssp.a
ar rcs $M_TARGET/lib/libssp_nonshared.a

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build && cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET
make -j$MJOBS
make install
rm -rf $M_SOURCE/mingw-w64

echo "building gcc"
echo "======================="
cd $M_SOURCE
git clone git://gcc.gnu.org/git/gcc.git --branch releases/gcc-13
cd $M_BUILD
mkdir gcc-build && cd gcc-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0002-Relocate-libintl.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0003-Windows-Follow-Posix-dir-exists-semantics-more-close.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0005-Windows-Don-t-ignore-native-system-header-dir.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0006-Windows-New-feature-to-allow-overriding.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0007-Build-EXTRA_GNATTOOLS-for-Ada.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0008-Prettify-linking-no-undefined.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0011-Enable-shared-gnat-implib.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0012-Handle-spaces-in-path-for-default-manifest.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0014-gcc-9-branch-clone_function_name_1-Retain-any-stdcall-suffix.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0020-libgomp-Don-t-hard-code-MS-printf-attributes.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0021-PR14940-Allow-a-PCH-to-be-mapped-to-a-different-addr.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0140-gcc-diagnostic-color.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0200-add-m-no-align-vector-insn-option-for-i386.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0300-override-builtin-printf-format.patch
curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-gcc/0400-gcc-Make-stupid-AT-T-syntax-not-default.patch
curl -L -o 2f7e7bfa3c6327793cdcdcb5c770b93cecd49bd0.patch "https://gcc.gnu.org/git/?p=gcc.git;a=patch;h=2f7e7bfa3c6327793cdcdcb5c770b93cecd49bd0"
curl -L -o 3eeb4801d6f45f6250fc77a6d3ab4e0115f8cfdd.patch "https://gcc.gnu.org/git/?p=gcc.git;a=patch;h=3eeb4801d6f45f6250fc77a6d3ab4e0115f8cfdd"

apply_patch_with_msg() {
  for patch in "$@"; do
    echo "Applying $patch"
    patch -Nbp1 -i "$M_BUILD/gcc-build/$patch"
  done
}

#cd $M_SOURCE/gcc-$VER_GCC
cd $M_SOURCE/gcc
apply_patch_with_msg \
  0002-Relocate-libintl.patch \
  0003-Windows-Follow-Posix-dir-exists-semantics-more-close.patch \
  0005-Windows-Don-t-ignore-native-system-header-dir.patch \
  0006-Windows-New-feature-to-allow-overriding.patch \
  0007-Build-EXTRA_GNATTOOLS-for-Ada.patch \
  0008-Prettify-linking-no-undefined.patch \
  0011-Enable-shared-gnat-implib.patch \
  0012-Handle-spaces-in-path-for-default-manifest.patch \
  0014-gcc-9-branch-clone_function_name_1-Retain-any-stdcall-suffix.patch \
  0020-libgomp-Don-t-hard-code-MS-printf-attributes.patch \
  0021-PR14940-Allow-a-PCH-to-be-mapped-to-a-different-addr.patch \
  0140-gcc-diagnostic-color.patch \
  0200-add-m-no-align-vector-insn-option-for-i386.patch \
  0300-override-builtin-printf-format.patch \
  0400-gcc-Make-stupid-AT-T-syntax-not-default.patch

# backport: https://github.com/msys2/MINGW-packages/issues/17599
# https://inbox.sourceware.org/gcc-patches/a22433f5-b4d2-19b7-86a2-31e2ee45fb61@martin.st/T/
apply_patch_with_msg \
  2f7e7bfa3c6327793cdcdcb5c770b93cecd49bd0.patch \
  3eeb4801d6f45f6250fc77a6d3ab4e0115f8cfdd.patch

# so libgomp DLL gets built despide static libdl
export lt_cv_deplibs_check_method='pass_all'

# In addition adaint.c does `#include <accctrl.h>` which pulls in msxml.h, hacky hack:
CPPFLAGS+=" -DCOM_NO_WINDOWS_H"

_gcc_version=$(head -n 34 gcc/BASE-VER | sed -e 's/.* //' | tr -d '"\n')
_gcc_date=$(head -n 34 gcc/DATESTAMP | sed -e 's/.* //' | tr -d '"\n')
VER=$(printf "%s-%s" "$_gcc_version" "$_gcc_date")

cd $M_BUILD/gcc-build
#$M_SOURCE/gcc-$VER_GCC/configure \
$M_SOURCE/gcc/configure \
  --build=x86_64-pc-linux-gnu \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --libexecdir=$M_TARGET/lib \
  --with-native-system-header-dir=$M_TARGET/include \
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
  --enable-twoprocess \
  --enable-libssp \
  --enable-threads=mcf \
  --enable-libstdcxx-threads=yes \
  --enable-lto \
  --enable-checking=release \
  --enable-static \
  --enable-shared \
  --with-tune=generic \
  --without-included-gettext \
  --with-pkgversion="GCC with MCF thread model" \
  --with-boot-ldflags="$LDFLAGS -Wl,--disable-dynamicbase -static-libstdc++ -static-libgcc" \
  CFLAGS='-Wno-int-conversion  -march=nocona -msahf -mtune=generic -O2' \
  CXXFLAGS='-Wno-int-conversion  -march=nocona -msahf -mtune=generic -O2'
make -j$MJOBS
make install
for f in $M_TARGET/bin/*.exe; do
  strip -s $f
done
for f in $M_TARGET/lib/gcc/x86_64-w64-mingw32/${VER%%-*}/*.exe; do
  strip -s $f
done
mv $M_TARGET/lib/libgcc_s_seh-1.dll $M_TARGET/bin/
cp $M_TARGET/bin/gcc.exe $M_TARGET/bin/cc.exe
cp $M_TARGET/bin/$MINGW_TRIPLE-gcc.exe $M_TARGET/bin/$MINGW_TRIPLE-cc.exe
find $M_TARGET/lib -maxdepth 1 -type f -name "*.dll.a" -print0 | xargs -0 -I {} rm {}
find $M_TARGET/lib -maxdepth 1 -type f -name "*.la" -print0 | xargs -0 -I {} rm {}

echo "building windows-default-manifest"
echo "======================="
cd $M_BUILD
mkdir windows-default-manifest-build && cd windows-default-manifest-build
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
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-make/make-4.2.1-Makefile.am-gcc-only-link-libgnumake-1.dll.a.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-make/make-4.3_undef-HAVE_STRUCT_DIRENT_D_TYPE.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-make/make-4.4-timestamps.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-make/make-check-load-feature.mak
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-make/make-getopt.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-make/make-linebuf-mingw.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-make/mk_temp.c

cd $M_SOURCE/make-$VER_MAKE
pushd src
patch -p1 -i $M_BUILD/make-build/make-getopt.patch
patch -p1 -i $M_BUILD/make-build/make-linebuf-mingw.patch
patch -p2 -i $M_BUILD/make-build/make-4.3_undef-HAVE_STRUCT_DIRENT_D_TYPE.patch
popd
# https://lists.gnu.org/archive/html/bug-make/2022-11/msg00017.html
patch -p1 -i $M_BUILD/make-build/make-4.4-timestamps.patch
patch -p1 -i $M_BUILD/make-build/make-4.2.1-Makefile.am-gcc-only-link-libgnumake-1.dll.a.patch

_prog_name=mingw32-make
_prog_name_am=${_prog_name//[^a-zA-Z0-9@]/_}
mv Makefile.am Makefile.am.orig
sed -e "/bin_PROGRAMS/ { s:\bmake\b:${_prog_name}:g };
        s:\bmake_\(SOURCES\|LDADD\|LDFLAGS\)\b:${_prog_name_am}_\1:g ;
        s:\bEXTRA_make_\([A-Z]\+\):EXTRA_${_prog_name_am}_\1:g ;" \
      Makefile.am.orig > Makefile.am
autoreconf -vfi

cd $M_BUILD/make-build
$M_SOURCE/make-$VER_MAKE/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --disable-nls \
  --prefix=$M_TARGET
make -j$MJOBS
make install
#mv $M_TARGET/bin/make.exe $M_TARGET/bin/mingw32-make.exe

#echo "building cmake"
#echo "======================="
#cd $M_BUILD
#mkdir cmake-build
#cmake -H$M_SOURCE/CMake -B$M_BUILD/cmake-build \
#  -DCMAKE_INSTALL_PREFIX=$M_TARGET \
#  -DCMAKE_TOOLCHAIN_FILE=$TOP_DIR/toolchain.cmake \
#  -DCMAKE_BUILD_TYPE=Release \
#  -DBUILD_SHARED_LIBS=OFF \
#  -DCMAKE_USE_SYSTEM_LIBRARIES=OFF
#make -j$MJOBS -C $M_BUILD/cmake-build
#make install -C $M_BUILD/cmake-build

#echo "building yasm"
#echo "======================="
#cd $M_BUILD
#mkdir yasm-build
#cd yasm-build
#$M_SOURCE/yasm-$VER_YASM/configure \
#  --host=$MINGW_TRIPLE \
#  --target=$MINGW_TRIPLE \
#  --prefix=$M_TARGET
#make -j$MJOBS
#make install

#echo "building nasm"
#echo "======================="
#cd $M_BUILD
#mkdir nasm-build
#cd nasm-build
#$M_SOURCE/nasm-$VER_NASM/configure \
#  --host=$MINGW_TRIPLE \
#  --target=$MINGW_TRIPLE \
#  --prefix=$M_TARGET
#make -j$MJOBS
#make install

echo "building pkgconf"
echo "======================="
cd $M_BUILD
mkdir pkgconf-build && cd pkgconf-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-pkgconf/0002-size-t-format.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-pkgconf/0003-printf-format.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-pkgconf/0004-default-pure-static.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-pkgconf/384ade5f316367f15da9dbf09853e06fe29bf2bf.patch

cd $M_SOURCE/pkgconf
# https://github.com/msys2/MINGW-packages/issues/8473
patch -R -p1 -i $M_BUILD/pkgconf-build/0004-default-pure-static.patch
patch -p1 -i $M_BUILD/pkgconf-build/0002-size-t-format.patch
patch -p1 -i $M_BUILD/pkgconf-build/0003-printf-format.patch

# https://github.com/pkgconf/pkgconf/issues/326
patch -R -p1 -i $M_BUILD/pkgconf-build/384ade5f316367f15da9dbf09853e06fe29bf2bf.patch

cd $M_BUILD/pkgconf-build
meson setup . $M_SOURCE/pkgconf \
  --prefix=$M_TARGET \
  --cross-file=$TOP_DIR/cross.meson \
  --buildtype=plain \
  -Dtests=disabled
ninja -j$MJOBS -C $M_BUILD/pkgconf-build
ninja install -C $M_BUILD/pkgconf-build
cp $M_TARGET/bin/pkgconf.exe $M_TARGET/bin/pkg-config.exe
cp $M_TARGET/bin/pkgconf.exe $M_TARGET/bin/x86_64-w64-mingw32-pkg-config.exe

cd $M_TARGET
rm -rf doc || true
rm -rf man || true
rm -rf lib/pkgconfig
rm -f mingw
echo "$VER" > $M_TARGET/version.txt

mkdir share
cp $M_SOURCE/nasm-$VER_NASM/*.exe bin
cp $M_SOURCE/yasm-$VER_YASM-win64.exe bin/yasm.exe
cp $M_SOURCE/cmake-$VER_CMAKE-windows-x86_64/bin/cmake.exe bin
cp -r $M_SOURCE/cmake-$VER_CMAKE-windows-x86_64/share/cmake* share
cp $M_SOURCE/ninja.exe bin
cp $M_SOURCE/curl*/bin/curl-ca-bundle.crt bin
cp $M_SOURCE/curl*/bin/curl.exe bin

