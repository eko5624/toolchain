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

CFGUARD_FLAGS="--enable-cfguard"
USE_CFLAGS="-g -O2 -mguard=cf"
while [ $# -gt 0 ]; do
    case "$1" in
    --armv7)
        ARCH="armv7"
        ;;
    --aarch64)
        ARCH="aarch64"
        ;;
    --x86_64)
        ARCH="x86_64"
        ;;
    *)
        if [ -n "$SRC" ]; then
            if [ -n "$DEST" ]; then
                echo Unrecognized parameter $1
                exit 1
            fi
            DEST="$1"
        else
            SRC="$1"
        fi
        ;;
    esac
    shift
done

export PATH="$SRC/bin:$PATH"
CLANG_RESOURCE_DIR="$("$SRC/bin/clang" --print-resource-dir)"
CLANG_VERSION=$(basename "$CLANG_RESOURCE_DIR")

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "getting source"
echo "======================="
cd $M_SOURCE

#llvm
#git clone https://github.com/llvm/llvm-project.git --branch release/18.x llvmorg-$VER_LLVM
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
fi

#lldb-mi
#git clone https://github.com/lldb-tools/lldb-mi.git

#llvm-mingw
git clone https://github.com/mstorsjo/llvm-mingw.git --branch master

#mingw-w64
git clone https://github.com/mingw-w64/mingw-w64.git --branch master

#cppwinrt
git clone https://github.com/microsoft/cppwinrt.git --branch master

#make
wget -c -O make-$VER_MAKE.tar.gz https://ftp.gnu.org/pub/gnu/make/make-$VER_MAKE.tar.gz
tar xzf make-$VER_MAKE.tar.gz 2>/dev/null >/dev/null

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

#echo "building lldb-mi"
#echo "======================="
#export LLVM_DIR=$M_BUILD/llvm-build
#cd $M_BUILD
#mkdir lldb-mi-build
#cmake -G Ninja -H$M_SOURCE/lldb-mi -B$M_BUILD/lldb-mi-build \
#  -DCMAKE_INSTALL_PREFIX=$DEST \
#  -DCMAKE_BUILD_TYPE=Release \
#  -DCMAKE_SYSTEM_NAME=Windows \
#  -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
#  -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
#  -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
#  -DCMAKE_FIND_ROOT_PATH=$LLVM_DIR \
#  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
#  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
#  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
#  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
#cmake --build lldb-mi-build -j$MJOBS
#cmake --install lldb-mi-build --strip

echo "stripping llvm"
echo "======================="
cd $M_SOURCE/llvm-mingw
./strip-llvm.sh $DEST --host=$ARCH-w64-mingw32
echo "... Done"

echo "installing wrappers"
echo "======================="
cp -f $M_SOURCE/llvm-mingw/wrappers/*-wrapper.sh $DEST/bin
cp -f $M_SOURCE/llvm-mingw/wrappers/mingw32-common.cfg $DEST/bin
cp -f $M_SOURCE/llvm-mingw/wrappers/$ARCH-w64-windows-gnu.cfg $DEST/bin
$ARCH-w64-mingw32-gcc $M_SOURCE/llvm-mingw/wrappers/clang-target-wrapper.c -o $DEST/bin/clang-target-wrapper.exe -O2 -Wl,-s -municode -DCLANG=\"clang-$CLANG_VERSION.exe\" -DCLANG_SCAN_DEPS=\"clang-scan-deps-real\" -D__USE_MINGW_ANSI_STDIO=0
$ARCH-w64-mingw32-gcc $M_SOURCE/llvm-mingw/wrappers/clang-scan-deps-wrapper.c -o $DEST/bin/clang-scan-deps-wrapper.exe -O2 -Wl,-s -municode -DCLANG=\"clang-$CLANG_VERSION.exe\" -DCLANG_SCAN_DEPS=\"clang-scan-deps-real\" -D__USE_MINGW_ANSI_STDIO=0
$ARCH-w64-mingw32-gcc $M_SOURCE/llvm-mingw/wrappers/llvm-wrapper.c -o $DEST/bin/llvm-wrapper.exe -O2 -Wl,-s -municode -DCLANG=\"clang-$CLANG_VERSION.exe\" -DCLANG_SCAN_DEPS=\"clang-scan-deps-real\" -D__USE_MINGW_ANSI_STDIO=0
cd $DEST/bin
for exec in clang clang++ gcc g++ c++ as; do
  ln -sf clang-target-wrapper.exe $ARCH-w64-mingw32-$exec.exe
done
ln -sf clang-scan-deps-wrapper.exe $ARCH-w64-mingw32-clang-scan-deps.exe
for exec in addr2line ar ranlib nm objcopy readelf size strings strip; do
  ln -sf llvm-$exec.exe $ARCH-w64-mingw32-$exec.exe
done
ln -sf llvm-ar.exe $ARCH-w64-mingw32-llvm-ar.exe
ln -sf llvm-ranlib.exe $ARCH-w64-mingw32-llvm-ranlib.exe

# windres and dlltool can't use llvm-wrapper, as that loses the original target arch prefix.
ln -sf llvm-windres.exe $ARCH-w64-mingw32-windres.exe
ln -sf llvm-dlltool.exe $ARCH-w64-mingw32-dlltool.exe
for exec in ld objdump; do
  ln -sf $exec-wrapper.sh $ARCH-w64-mingw32-$exec
done

mv clang-scan-deps.exe clang-scan-deps-real.exe
mv clang.exe clang-$CLANG_VERSION.exe

# Install unprefixed wrappers if $HOST is one of the architectures we are installing wrappers for.
for exec in clang clang++ gcc g++ c++ addr2line ar dlltool ranlib nm objcopy readelf size strings strip windres clang-scan-deps; do
  ln -sf $ARCH-w64-mingw32-$exec.exe $exec.exe
done
for exec in cc c99 c11; do
  ln -sf clang.exe $exec.exe
done
for exec in ld objdump; do
  ln -sf $ARCH-w64-mingw32-$exec $exec
done
echo "... Done"

echo "building cppwinrt"
echo "======================="
cd $M_BUILD
mkdir cppwinrt-build
cmake -G Ninja -H$M_SOURCE/cppwinrt -B$M_BUILD/cppwinrt-build \
  -DCMAKE_INSTALL_PREFIX=$DEST \
  -DCMAKE_TOOLCHAIN_FILE=$M_SOURCE/cppwinrt/cross-mingw-toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF
ninja -C cppwinrt-build
ninja -C cppwinrt-build install
curl -L https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd -o cppwinrt-build/Windows.winmd
cppwinrt -in cppwinrt-build/Windows.winmd -out $DEST/include

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$DEST --host=$ARCH-w64-mingw32
make -j$MJOBS
make install-strip

echo "prepare cross toolchain"
echo "======================="
cp $SRC/$ARCH-w64-mingw32/bin/*.dll $DEST/bin
rm -rf $DEST/lib/clang/$CLANG_VERSION
cp -a $CLANG_RESOURCE_DIR $DEST/lib/clang/$CLANG_VERSION
mkdir -p $DEST/include
cp -a $SRC/generic-w64-mingw32/include/. $DEST/include
mkdir -p $DEST/$ARCH-w64-mingw32
for subdir in bin lib; do
  cp -a $SRC/$ARCH-w64-mingw32/$subdir $DEST/$ARCH-w64-mingw32
done

# Copy the libc++ module sources
rm -rf $DEST/share/libc++
cp -a $SRC/share/libc++ $DEST/share
echo "... Done"

echo "building make"
echo "======================="
cd $M_BUILD
mkdir make-build && cd make-build
$M_SOURCE/make-$VER_MAKE/configure \
  --host=$ARCH-w64-mingw32 \
  --prefix=$DEST \
  --program-prefix=mingw32- \
  --enable-job-server
make -j$MJOBS
make install-binPROGRAMS
echo "... Done"

echo "building pkgconf"
echo "======================="
cd $M_BUILD
mkdir pkgconf-build
cd $M_SOURCE/pkgconf
meson setup $M_BUILD/pkgconf-build \
  --prefix=$DEST \
  --cross-file=$TOP_DIR/cross.meson \
  --buildtype=release \
  -Dtests=disabled
meson compile -C $M_BUILD/pkgconf-build
meson install -C $M_BUILD/pkgconf-build
cp $DEST/bin/pkgconf.exe $DEST/bin/pkg-config.exe
cp $DEST/bin/pkgconf.exe $DEST/bin/$ARCH-w64-mingw32-pkg-config.exe


echo "removing *.dll.a *.la"
echo "======================="
find $DEST/lib -maxdepth 1 -type f -name "*.dll.a" -print0 | xargs -0 -I {} rm {}
find $DEST/$ARCH-w64-mingw32/lib -maxdepth 1 -type f -name "*.dll.a" -print0 | xargs -0 -I {} rm {}
find $DEST/$ARCH-w64-mingw32/lib -maxdepth 1 -type f -name "*.la" -print0 | xargs -0 -I {} rm {}
rm -rf $DEST/lib/pkgconfig
rm -rf $DEST/include/pkgconf
echo "... Done"

echo "copy yasm nasm cmake ninja curl"
echo "======================="
cd $DEST
cp $M_SOURCE/nasm-$VER_NASM/*.exe bin
cp $M_SOURCE/yasm-$VER_YASM-win64.exe bin/yasm.exe
cp $M_SOURCE/cmake-$VER_CMAKE-windows-x86_64/bin/cmake.exe bin
cp -r $M_SOURCE/cmake-$VER_CMAKE-windows-x86_64/share/cmake* share
cp $M_SOURCE/ninja.exe bin
cp $M_SOURCE/curl*/bin/curl-ca-bundle.crt bin
cp $M_SOURCE/curl*/bin/curl.exe bin
echo "... Done"
