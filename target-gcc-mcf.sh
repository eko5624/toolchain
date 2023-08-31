#!/bin/bash
set -e

TOP_DIR=$(pwd)

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)


MINGW_TRIPLE="x86_64-w64-mingw32"
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
VER_GMP=${ver[gmp]}
VER_MPFR=${ver[mpfr]}
VER_MPC=${ver[mpc]}
VER_ISL=${ver[isl]}
VER_MAKE=${ver[make]}
VER_PKGCONF=${ver[pkgconf]}

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
  --with-gmp=$M_BUILD/for_target \
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
  --disable-nls \
  --disable-werror \
  --disable-shared \
  --enable-lto
make -j$MJOBS
make install

echo "building mingw-w64-headers"
echo "======================="
cd $M_BUILD
mkdir headers-build
cd headers-build
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
mkdir winpthreads-build
cd winpthreads-build
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
mkdir mcfgthread-build
cd mcfgthread-build
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
mkdir crt-build
cd crt-build
curl -OL https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-crt-git/0001-Allow-to-use-bessel-and-complex-functions-without-un.patch
#curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-crt-git/9001-crt-Mark-atexit-as-DATA-because-it-s-always-overridd.patch
#curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-crt-git/9002-crt-Provide-wrappers-for-exit-in-libmingwex.patch
#curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-crt-git/9003-crt-Implement-standard-conforming-termination-suppor.patch
#curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-crt-git/9004-crt-Copy-clock-and-nanosleep-from-winpthreads.patch
cd $M_SOURCE/mingw-w64
git reset --hard
git clean -fdx
#git apply $M_BUILD/crt-build/9001-crt-Mark-atexit-as-DATA-because-it-s-always-overridd.patch
#git apply $M_BUILD/crt-build/9002-crt-Provide-wrappers-for-exit-in-libmingwex.patch
#git apply $M_BUILD/crt-build/9003-crt-Implement-standard-conforming-termination-suppor.patch
#git apply $M_BUILD/crt-build/9004-crt-Copy-clock-and-nanosleep-from-winpthreads.patch
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
mkdir gendef-build
cd gendef-build
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
mkdir gcc-build
cd gcc-build
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
curl -OL https://raw.githubusercontent.com/lhmouse/MINGW-packages/master/mingw-w64-gcc/777aa930b106fea2dd6ed9fe22b42a2717f1472d.patch
curl -L -o 2f7e7bfa3c6327793cdcdcb5c770b93cecd49bd0.patch "https://gcc.gnu.org/git/?p=gcc.git;a=patch;h=2f7e7bfa3c6327793cdcdcb5c770b93cecd49bd0"
curl -L -o 3eeb4801d6f45f6250fc77a6d3ab4e0115f8cfdd.patch "https://gcc.gnu.org/git/?p=gcc.git;a=patch;h=3eeb4801d6f45f6250fc77a6d3ab4e0115f8cfdd"

#cd $M_SOURCE/gcc-$VER_GCC
cd $M_SOURCE/gcc
patch -Nbp1 -i $M_BUILD/gcc-build/0002-Relocate-libintl.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0003-Windows-Follow-Posix-dir-exists-semantics-more-close.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0005-Windows-Don-t-ignore-native-system-header-dir.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0006-Windows-New-feature-to-allow-overriding.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0007-Build-EXTRA_GNATTOOLS-for-Ada.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0008-Prettify-linking-no-undefined.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0011-Enable-shared-gnat-implib.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0012-Handle-spaces-in-path-for-default-manifest.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0014-gcc-9-branch-clone_function_name_1-Retain-any-stdcall-suffix.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0020-libgomp-Don-t-hard-code-MS-printf-attributes.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0021-PR14940-Allow-a-PCH-to-be-mapped-to-a-different-addr.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0140-gcc-diagnostic-color.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0200-add-m-no-align-vector-insn-option-for-i386.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0300-override-builtin-printf-format.patch
patch -Nbp1 -i $M_BUILD/gcc-build/0400-gcc-Make-stupid-AT-T-syntax-not-default.patch

# backport: https://github.com/msys2/MINGW-packages/issues/17599
# https://inbox.sourceware.org/gcc-patches/a22433f5-b4d2-19b7-86a2-31e2ee45fb61@martin.st/T/
patch -Nbp1 -i $M_BUILD/gcc-build/2f7e7bfa3c6327793cdcdcb5c770b93cecd49bd0.patch
patch -Nbp1 -i $M_BUILD/gcc-build/3eeb4801d6f45f6250fc77a6d3ab4e0115f8cfdd.patch

# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=110315#c7
patch -Nbp1 -i $M_BUILD/gcc-build/777aa930b106fea2dd6ed9fe22b42a2717f1472d.patch

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
mkdir make-build
cd make-build
$M_SOURCE/make-$VER_MAKE/configure \
  --host=$MINGW_TRIPLE \
  --target=$MINGW_TRIPLE \
  --prefix=$M_TARGET
make -j$MJOBS
make install
cp $M_TARGET/bin/make.exe $M_TARGET/bin/mingw32-make.exe

echo "building pkgconf"
echo "======================="
cd $M_BUILD
mkdir pkgconf-build
cd pkgconf-build
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
rm -rf share
rm -rf lib/pkgconfig
rm -f mingw
rm -rf $M_TARGET/share
echo "$VER" > $M_TARGET/version.txt
