#!/bin/bash
set -e

TOP_DIR=$(pwd)
source $TOP_DIR/ver.sh

# worflows for clang compilation:
# llvm -> mingw's header+crt -> compiler-rt builtins -> libcxx -> openmp

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
TOOLCHAIN_ARCHS="x86_64"
TOOLCHAIN_TARGET_OSES="mingw32"
CLANG_VER="${VER_LLVM%%.*}"

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
#  -DCMAKE_INSTALL_PREFIX=$M_TARGET \
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
./strip-llvm.sh $M_TARGET --host=x86_64-w64-mingw32
echo "... Done"

echo "installing wrappers"
echo "======================="
cp -f $M_SOURCE/llvm-mingw/wrappers/*-wrapper.sh $M_TARGET/bin
x86_64-w64-mingw32-gcc $M_SOURCE/llvm-mingw/wrappers/clang-target-wrapper.c -o $M_TARGET/bin/clang-target-wrapper.exe -O2 -Wl,-s -municode -DCLANG=\"clang-$CLANG_VER.exe\"

cd $M_TARGET/bin
for exec in clang clang++ gcc g++ c++ as; do
  ln -sf clang-target-wrapper.exe $MINGW_TRIPLE-$exec.exe
done

cp llvm-ar.exe $MINGW_TRIPLE-ar.exe
cp llvm-ar.exe $MINGW_TRIPLE-llvm-ar.exe
cp llvm-ar.exe $MINGW_TRIPLE-llvm-ranlib.exe
cp llvm-ar.exe $MINGW_TRIPLE-dlltool.exe
cp llvm-ar.exe $MINGW_TRIPLE-ranlib.exe
cp llvm-addr2line.exe $MINGW_TRIPLE-addr2line.exe
cp llvm-nm.exe $MINGW_TRIPLE-nm.exe
cp llvm-objcopy.exe $MINGW_TRIPLE-objcopy.exe
cp llvm-objcopy.exe $MINGW_TRIPLE-strip.exe
cp llvm-rc.exe $MINGW_TRIPLE-windres.exe
cp llvm-readelf.exe $MINGW_TRIPLE-readelf.exe
cp llvm-size.exe $MINGW_TRIPLE-size.exe
cp llvm-strings.exe $MINGW_TRIPLE-strings.exe

for exec in ld objdump; do
  ln -sf $exec-wrapper.sh $MINGW_TRIPLE-$exec
done

mv clang.exe clang-$CLANG_VER.exe

# Install unprefixed wrappers if $HOST is one of the architectures we are installing wrappers for.
for exec in clang clang++ gcc g++ c++ addr2line ar dlltool ranlib nm objcopy readelf strings strip windres; do
  ln -sf $MINGW_TRIPLE-$exec.exe $exec.exe
done
for exec in cc c99 c11; do
  ln -sf clang.exe $exec.exe
done
for exec in ld objdump; do
  ln -sf $MINGW_TRIPLE-$exec $exec
done
echo "... Done"

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

echo "building gendef"
echo "======================="
cd $M_BUILD
mkdir gendef-build
cd gendef-build
$M_SOURCE/mingw-w64/mingw-w64-tools/gendef/configure --prefix=$M_TARGET --host=x86_64-w64-mingw32
make -j$MJOBS
make install-strip

echo "building mingw-w64-headers"
echo "======================="
cd $M_BUILD
mkdir headers-build
cd headers-build
$M_SOURCE/mingw-w64/mingw-w64-headers/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET/$MINGW_TRIPLE \
  --enable-idl \
  --with-default-win32-winnt=0x601 \
  --with-default-msvcrt=ucrt
make -j$MJOBS
make install-strip

echo "building mingw-w64-crt"
echo "======================="
cd $M_SOURCE/mingw-w64/mingw-w64-crt
autoreconf -ivf
cd $M_BUILD 
mkdir crt-build
cd crt-build
$M_SOURCE/mingw-w64/mingw-w64-crt/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET/$MINGW_TRIPLE \
  --with-sysroot=$M_TARGET \
  --with-default-msvcrt=ucrt \
  --enable-lib64 \
  --disable-lib32 \
  --enable-cfguard \
  --disable-dependency-tracking
make -j$MJOBS GC=0
make install-strip GC=0
# Create empty dummy archives, to avoid failing when the compiler driver
# adds -lssp -lssh_nonshared when linking.
llvm-ar rcs $M_TARGET/lib/libssp.a
llvm-ar rcs $M_TARGET/lib/libssp_nonshared.a

echo "building winpthreads"
echo "======================="
cd $M_BUILD
mkdir winpthreads-build
cd winpthreads-build
$M_SOURCE/mingw-w64/mingw-w64-libraries/winpthreads/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET/$MINGW_TRIPLE \
  --disable-shared \
  --enable-static
make -j$MJOBS GC=0
make install-strip GC=0

echo "building llvm-compiler-rt-builtin"
echo "======================="
cd $M_BUILD
mkdir builtins-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt/lib/builtins -B$M_BUILD/builtins-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_TARGET/lib/clang/$CLANG_VER \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-w64-windows-gnu \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=TRUE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++ \
  -DCMAKE_C_FLAGS_INIT="-mguard=cf" \
  -DCMAKE_CXX_FLAGS_INIT="-mguard=cf"
cmake --build builtins-build -j$MJOBS
cp builtins-build/lib/windows/libclang_rt.builtins-x86_64.a $M_TARGET/$MINGW_TRIPLE/lib
cmake --install builtins-build

echo "building llvm-libcxx"
echo "======================="
cd $M_BUILD
mkdir libcxx-build
cmake -G Ninja -H$M_SOURCE/llvm-project/runtimes -B$M_BUILD/libcxx-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$M_TARGET/$MINGW_TRIPLE \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_C_COMPILER_TARGET=x86_64-w64-windows-gnu \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLLVM_PATH=$M_SOURCE/llvm-project/llvm \
  -DLIBUNWIND_USE_COMPILER_RT=TRUE \
  -DLIBUNWIND_ENABLE_SHARED=ON \
  -DLIBUNWIND_ENABLE_STATIC=ON \
  -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXX_ENABLE_SHARED=ON \
  -DLIBCXX_ENABLE_STATIC=ON \
  -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
  -DLIBCXX_CXX_ABI=libcxxabi \
  -DLIBCXX_LIBDIR_SUFFIX="" \
  -DLIBCXX_INCLUDE_TESTS=FALSE \
  -DLIBCXXABI_INCLUDE_TESTS=FALSE \
  -DLIBUNWIND_INCLUDE_TESTS=FALSE \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=FALSE \
  -DLIBCXX_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_HAS_WIN32_THREAD_API=ON \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_LIBDIR_SUFFIX=""
cmake --build libcxx-build -j$MJOBS
cmake --install libcxx-build

echo "building llvm-compiler-rt"
echo "======================="
cd $M_BUILD
mkdir compiler-rt-build
cmake -G Ninja -H$M_SOURCE/llvm-project/compiler-rt -B$M_BUILD/compiler-rt-build \
  -DCMAKE_INSTALL_PREFIX=$M_TARGET/lib/clang/$CLANG_VER \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=$MINGW_TRIPLE-clang \
  -DCMAKE_CXX_COMPILER=$MINGW_TRIPLE-clang++ \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_AR=$M_CROSS/bin/llvm-ar \
  -DCMAKE_RANLIB=$M_CROSS/bin/llvm-ranlib \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_C_COMPILER_TARGET=x86_64-w64-windows-gnu \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
  -DCOMPILER_RT_USE_BUILTINS_LIBRARY=TRUE \
  -DCOMPILER_RT_BUILD_BUILTINS=FALSE \
  -DCOMPILER_RT_INCLUDE_TESTS=FALSE \
  -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=FALSE \
  -DLLVM_CONFIG_PATH="" \
  -DCMAKE_FIND_ROOT_PATH=$M_CROSS/$MINGW_TRIPLE \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DSANITIZER_CXX_ABI=libc++ \
  -DCMAKE_C_FLAGS_INIT="-mguard=cf" \
  -DCMAKE_CXX_FLAGS_INIT="-mguard=cf"
cmake --build compiler-rt-build -j$MJOBS
cmake --install compiler-rt-build

mkdir -p $M_TARGET/$MINGW_TRIPLE/bin
mv $M_TARGET/lib/clang/$CLANG_VER/lib/windows/*.dll $M_TARGET/$MINGW_TRIPLE/bin
#Copy libclang_rt.builtins-x86_64.a to runtime dir
cp $M_TARGET/$MINGW_TRIPLE/lib/libclang_rt.builtins-x86_64.a $M_TARGET/lib/clang/$CLANG_VER/lib/windows

cp $M_TARGET/$MINGW_TRIPLE/bin/*.dll $M_TARGET/bin
rm -rf $M_TARGET/include
mv $M_TARGET/$MINGW_TRIPLE/include $M_TARGET

echo "building make"
echo "======================="
cd $M_BUILD
mkdir make-build && cd make-build
$M_SOURCE/make-$VER_MAKE/configure \
  --host=$MINGW_TRIPLE \
  --prefix=$M_TARGET \
  --program-prefix=mingw32- \
  --enable-job-server
make -j$MJOBS
make install-binPROGRAMS
echo "... Done"

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


echo "removing *.dll.a *.la"
echo "======================="
find $M_TARGET/lib -maxdepth 1 -type f -name "*.dll.a" -print0 | xargs -0 -I {} rm {}
find $M_TARGET/$MINGW_TRIPLE/lib -maxdepth 1 -type f -name "*.dll.a" -print0 | xargs -0 -I {} rm {}
find $M_TARGET/$MINGW_TRIPLE/lib -maxdepth 1 -type f -name "*.la" -print0 | xargs -0 -I {} rm {}
rm -rf $M_TARGET/lib/pkgconfig
rm -rf $M_TARGET/include/pkgconf
echo "... Done"

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