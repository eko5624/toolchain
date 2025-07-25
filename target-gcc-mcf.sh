#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh
export BRANCH_GCC=releases/gcc-${VER_GCC%%.*}

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

M_ROOT=$(pwd)
M_SOURCE=$M_ROOT/source
M_BUILD=$M_ROOT/build
M_CROSS=$M_ROOT/cross
M_TARGET=$M_ROOT/target
MINGW_TRIPLE="x86_64-w64-mingw32"
PATH="$M_CROSS/bin:$PATH"

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "gettiong source"
echo "======================="
cd $M_SOURCE

#binutils
wget -c -O binutils-$VER_BINUTILS.tar.bz2 http://ftp.gnu.org/gnu/binutils/binutils-$VER_BINUTILS.tar.bz2 2>/dev/null >/dev/null
tar xjf binutils-$VER_BINUTILS.tar.bz2 2>/dev/null >/dev/null
#mkdir binutils
#git clone https://sourceware.org/git/binutils-gdb.git --branch binutils-${VER_BINUTILS//./_}-branch binutils

#gmp
wget -c -O gmp-$VER_GMP.tar.bz2 https://ftp.gnu.org/gnu/gmp/gmp-$VER_GMP.tar.bz2 2>/dev/null >/dev/null
tar xjf gmp-$VER_GMP.tar.bz2 2>/dev/null >/dev/null

#mpfr
wget -c -O mpfr-$VER_MPFR.tar.bz2 https://ftp.gnu.org/gnu/mpfr/mpfr-$VER_MPFR.tar.bz2 2>/dev/null >/dev/null
tar xjf mpfr-$VER_MPFR.tar.bz2 2>/dev/null >/dev/null

#MPC
wget -c -O mpc-$VER_MPC.tar.gz https://ftp.gnu.org/gnu/mpc/mpc-$VER_MPC.tar.gz 2>/dev/null >/dev/null
tar xzf mpc-$VER_MPC.tar.gz 2>/dev/null >/dev/null

#isl
wget -c -O isl-$VER_ISL.tar.bz2 https://gcc.gnu.org/pub/gcc/infrastructure/isl-$VER_ISL.tar.bz2 2>/dev/null >/dev/null
tar xjf isl-$VER_ISL.tar.bz2 2>/dev/null >/dev/null

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master

#mcfgthread
git clone https://github.com/lhmouse/mcfgthread.git --branch master

#cppwinrt
git clone https://github.com/microsoft/cppwinrt.git --branch master

#make
wget -c -O make-$VER_MAKE.tar.gz https://ftp.gnu.org/pub/gnu/make/make-$VER_MAKE.tar.gz 2>/dev/null >/dev/null
tar xzf make-$VER_MAKE.tar.gz 2>/dev/null >/dev/null

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
tar xzf yasm-$VER_YASM.tar.gz 2>/dev/null >/dev/null

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
git clone https://github.com/pkgconf/pkgconf --branch pkgconf-2.3.0

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
  --disable-shared \
  CFLAGS="-std=gnu17"
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
  --with-{gmp,mpfr}=$M_BUILD/for_target \
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
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/3001-hack-libiberty-link-order.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/libiberty-unlink-handle-windows-nul.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-binutils/reproducible-import-libraries.patch

apply_patch_for_binutils() {
  for patch in "$@"; do
    echo "Applying $patch"
    patch -p1 -i "$M_BUILD/binutils-build/$patch"
  done
}

cd $M_SOURCE/binutils-$VER_BINUTILS
apply_patch_for_binutils \
  0002-check-for-unusual-file-harder.patch \
  0010-bfd-Increase-_bfd_coff_max_nscns-to-65279.patch \
  0110-binutils-mingw-gnu-print.patch

# Add an option to change default bases back below 4GB to ease transition
# https://github.com/msys2/MINGW-packages/issues/7027
# https://github.com/msys2/MINGW-packages/issues/7023
apply_patch_for_binutils 2001-ld-option-to-move-default-bases-under-4GB.patch

# https://github.com/msys2/MINGW-packages/pull/9233#issuecomment-889439433
patch -R -p1 -i $M_BUILD/binutils-build/2003-Restore-old-behaviour-of-windres-so-that-options-con.patch

# patches for reproducibility from Debian:
# https://salsa.debian.org/mingw-w64-team/binutils-mingw-w64/-/tree/master/debian/patches
patch -p2 -i $M_BUILD/binutils-build/reproducible-import-libraries.patch

# Handle Windows nul device
# https://github.com/msys2/MINGW-packages/issues/1840
# https://github.com/msys2/MINGW-packages/issues/10520
# https://github.com/msys2/MINGW-packages/issues/14725

# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=108276
# https://gcc.gnu.org/pipermail/gcc-patches/2023-January/609487.html
patch -p1 -i $M_BUILD/binutils-build/libiberty-unlink-handle-windows-nul.patch

# XXX: make sure we link against the just built libiberty, not the system one
# to avoid a linker error. All the ld deps contain system deps and system
# search paths, so imho if things link against the system lib or the just
# built one is just luck, and I don't know how that is supposed to work.
patch -p1 -i $M_BUILD/binutils-build/3001-hack-libiberty-link-order.patch

cd $M_BUILD/binutils-build
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
mkdir headers-build && cd headers-build
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
#curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-winpthreads-git/0001-Define-__-de-register_frame_info-in-fake-libgcc_s.patch

#cd $M_SOURCE/mingw-w64
#git apply $M_BUILD/winpthreads-build/0001-Define-__-de-register_frame_info-in-fake-libgcc_s.patch

cd $M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads

sed -i "s|fakelib_libgcc_s_a_SOURCES =|fakelib_libgcc_s_a_SOURCES = src/libgcc/dll_frame_info.c|" Makefile.am
cat <<EOF >src/libgcc/dll_frame_info.c
/* Because of:
   https://github.com/Alexpux/MINGW-packages/blob/master/mingw-w64-gcc/955-4.9.2-apply-hack-so-gcc_s-isnt-stripped.patch
   .. we need to define these functions.
*/

void __register_frame_info (__attribute__((unused)) const void *vp, __attribute__((unused)) void *op)
{
}

void *__deregister_frame_info (__attribute__((unused)) const void *vp)
{
    return (void *)0;
}
EOF

autoreconf -vfi

cd $M_BUILD/winpthreads-build
$M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --enable-static \
  --enable-shared
make -j$MJOBS
make install

echo "building mcfgthread"
echo "======================="
cd $M_SOURCE/mcfgthread
meson setup build \
  --prefix=$M_TARGET \
  --cross-file=$TOP_DIR/cross.meson \
  --buildtype=release
meson compile -C build
meson install -C build
rm -rf $M_TARGET/lib/pkgconfig

echo "building mingw-w64-crt"
echo "======================="
cd $M_BUILD
mkdir crt-build && cd crt-build
$M_SOURCE/mingw-w64/mingw-w64-crt/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --with-sysroot=$M_TARGET \
  --with-default-msvcrt=ucrt \
  --enable-wildcard \
  --disable-dependency-tracking \
  --enable-lib64 \
  --disable-lib32
make -j$MJOBS install-strip
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

echo "building cppwinrt"
echo "======================="
cd $M_BUILD
mkdir cppwinrt-build
cmake -G Ninja -H$M_SOURCE/cppwinrt -B$M_BUILD/cppwinrt-build \
  -DCMAKE_INSTALL_PREFIX=$M_TARGET \
  -DCMAKE_TOOLCHAIN_FILE=$M_SOURCE/cppwinrt/cross-mingw-toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF
ninja -C cppwinrt-build
ninja -C cppwinrt-build install
curl -L https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd -o cppwinrt-build/Windows.winmd
cppwinrt -in cppwinrt-build/Windows.winmd -out $M_TARGET/include


echo "building gcc"
echo "======================="
cd $M_SOURCE
#git clone https://github.com/gcc-mirror/gcc.git --branch releases/gcc-$BRANCH_GCC
git clone https://github.com/gcc-mirror/gcc.git --branch releases/gcc-$VER_GCC

cd $M_BUILD
mkdir gcc-build && cd gcc-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0003-Windows-Follow-Posix-dir-exists-semantics-more-close.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0005-Windows-Don-t-ignore-native-system-header-dir.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0007-Build-EXTRA_GNATTOOLS-for-Ada.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0008-Prettify-linking-no-undefined.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0011-Enable-shared-gnat-implib.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0012-Handle-spaces-in-path-for-default-manifest.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0014-gcc-9-branch-clone_function_name_1-Retain-any-stdcall-suffix.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0020-libgomp-Don-t-hard-code-MS-printf-attributes.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0140-gcc-diagnostic-color.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0200-add-m-no-align-vector-insn-option-for-i386.patch
curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-gcc/9000-gcc-Make-stupid-AT-T-syntax-not-default.patch
curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-gcc/9001-Always-quote-labels-in-Intel-syntax.patch
curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-gcc/9003-libstdc-Avoid-thread-local-states-for-MCF-thread-mod.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/2001-fix-building-rust-on-mingw-w64.patch
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/9002-native-tls.patch

apply_patch_for_gcc() {
  for patch in "$@"; do
    echo "Applying $patch"
    patch -Nbp1 -i "$M_BUILD/gcc-build/$patch"
  done
}

#cd $M_SOURCE/gcc-$VER_GCC
cd $M_SOURCE/gcc
apply_patch_for_gcc \
  0003-Windows-Follow-Posix-dir-exists-semantics-more-close.patch \
  0005-Windows-Don-t-ignore-native-system-header-dir.patch \
  0007-Build-EXTRA_GNATTOOLS-for-Ada.patch \
  0008-Prettify-linking-no-undefined.patch \
  0011-Enable-shared-gnat-implib.patch \
  0012-Handle-spaces-in-path-for-default-manifest.patch \
  0014-gcc-9-branch-clone_function_name_1-Retain-any-stdcall-suffix.patch \
  0020-libgomp-Don-t-hard-code-MS-printf-attributes.patch

# Enable diagnostic color under mintty
# based on https://github.com/BurntSushi/ripgrep/issues/94#issuecomment-261761687
apply_patch_for_gcc 0140-gcc-diagnostic-color.patch

# XXX: GAS segfaults on i686?!
apply_patch_for_gcc \
  9000-gcc-Make-stupid-AT-T-syntax-not-default.patch \
  9001-Always-quote-labels-in-Intel-syntax.patch \
  9002-native-tls.patch \
  9003-libstdc-Avoid-thread-local-states-for-MCF-thread-mod.patch


# workaround for AVX misalignment issue for pass-by-value arguments
#   cf. https://github.com/msys2/MSYS2-packages/issues/1209
#   cf. https://sourceforge.net/p/mingw-w64/discussion/723797/thread/bc936130/
#  Issue is longstanding upstream at https://gcc.gnu.org/bugzilla/show_bug.cgi?id=54412
#  Potential alternative: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=939559
# https://github.com/msys2/MINGW-packages/pull/8317#issuecomment-824548411
apply_patch_for_gcc \
  0200-add-m-no-align-vector-insn-option-for-i386.patch \
  2001-fix-building-rust-on-mingw-w64.patch

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
  --with-{gmp,mpfr,mpc}=$M_BUILD/for_target \
  --disable-rpath \
  --disable-multilib \
  --disable-dependency-tracking \
  --disable-bootstrap \
  --disable-nls \
  --disable-werror \
  --disable-symvers \
  --enable-libssp \
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
  --enable-__cxa_atexit \
  --enable-graphite \
  --enable-mingw-wildcard \
  --enable-threads=mcf \
  --enable-lto \
  --enable-checking=release \
  --enable-static \
  --enable-shared \
  --with-arch=nocona \
  --with-tune=generic \
  --without-included-gettext \
  --with-pkgversion="GCC with MCF thread model" \
  CFLAGS='-O2' \
  CXXFLAGS='-O2' \
  LDFLAGS='-Wl,--no-insert-timestamp -Wl,--dynamicbase -Wl,--high-entropy-va -Wl,--nxcompat -Wl,--tsaware'
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
$M_SOURCE/make-$VER_MAKE/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --program-prefix=mingw32- \
  --disable-nls \
  CFLAGS="-std=gnu17"
make -j$MJOBS
make install

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

echo "building yasm"
echo "======================="
cd $M_SOURCE/yasm-$VER_YASM
./configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  CFLAGS="-std=gnu17"
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
mkdir pkgconf-build
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

