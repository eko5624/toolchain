#!/bin/bash
set -e

TOP_DIR=$(pwd)

# worflows for clang compilation:
# llvm -> mingw's header+crt -> compiler-rt builtins -> libcxx -> openmp

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export M_ROOT=$(pwd)
export M_SOURCE=$M_ROOT/source
export M_BUILD=$M_ROOT/build
export M_CROSS=$M_ROOT/cross
export LLVM_ROOT=$M_ROOT/llvm_root
export ORIG_PATH="/usr/local/fuchsia-clang/bin:$PATH"
export PATH="$M_CROSS/bin:$ORIG_PATH"
export LLVM_PROFILE_FILE="/dev/null"

while [ $# -gt 0 ]; do
    case "$1" in
    --enable-pgo_gen)
        export LLVM_ENABLE_PGO="GEN" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    --enable-pgo_csgen)
        export LLVM_ENABLE_PGO="CSGEN" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    --enable-package-lto)
        export CLANG_PACKAGES_LTO="ON"
        export PACKAGES_LTO_DIR=$LLVM_ROOT/package-lto
        ;;
    --enable-package-ccache)
        export CCACHE_MAXSIZE="500M"
        export CCACHE_DIR=$LLVM_ROOT/package-ccache
        mkdir -p $CCACHE_DIR
        cat <<EOF >$CCACHE_DIR/ccache.conf
cache_dir = "$CCACHE_DIR"
max_size = "$CCACHE_MAXSIZE"
sloppiness = locale,time_macros
compiler_check = none
EOF
        ;;
    *)
        echo Unrecognized parameter $1
        exit 1
        ;;
    esac
    shift
done

if [ "$LLVM_ENABLE_PGO" == "GEN" ] || [ "$LLVM_ENABLE_PGO" == "CSGEN" ]; then
    export LLVM_PROFILE_DATA_DIR="$M_CROSS/profiles" #PATH "Default profile generation directory"
fi

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "pgo training with shaderc"
echo "======================="
cd $M_SOURCE
git clone https://github.com/google/shaderc.git
cp shaderc/DEPS ./
curl -OL https://github.com/KhronosGroup/glslang/archive/`cat DEPS | grep glslang | head -n1 | cut -d\' -f4`.tar.gz
curl -OL https://github.com/KhronosGroup/SPIRV-Headers/archive/`cat DEPS | grep spirv_headers | head -n1 | cut -d\' -f4`.tar.gz
curl -OL https://github.com/KhronosGroup/SPIRV-Tools/archive/`cat DEPS | grep spirv_tools | head -n1 | cut -d\' -f4`.tar.gz
for f in *.gz; do tar xvf "$f"; done 
mv glslang* glslang
mv SPIRV-Headers* spirv-headers
mv SPIRV-Tools* spirv-tools
cd shaderc
mv ../spirv-headers third_party
mv ../spirv-tools third_party
mv ../glslang third_party
cd $M_BUILD
mkdir shaderc-build
LTO_JOB=1 NO_CONFLTO=1 cmake -G Ninja -H$M_SOURCE/shaderc -B$M_BUILD/shaderc-build \
  -DCMAKE_INSTALL_PREFIX=$M_CROSS/shaderc \
  -DCMAKE_TOOLCHAIN_FILE=$M_SOURCE/shaderc/cmake/linux-mingw-toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DSHADERC_SKIP_TESTS=ON \
  -DSHADERC_SKIP_SPVC=ON \
  -DSHADERC_SKIP_INSTALL=ON \
  -DSHADERC_SKIP_EXAMPLES=ON \
  -DSPIRV_SKIP_EXECUTABLES=ON \
  -DSPIRV_SKIP_TESTS=ON \
  -DENABLE_SPIRV_TOOLS_INSTALL=ON \
  -DENABLE_GLSLANG_BINARIES=OFF \
  -DSPIRV_TOOLS_BUILD_STATIC=ON \
  -DSPIRV_TOOLS_LIBRARY_TYPE=STATIC \
  -DMINGW_COMPILER_PREFIX="x86_64-w64-mingw32"
LTO_JOB=1 cmake --build shaderc-build -j$MJOBS
rm -rf $M_CROSS/shaderc
unset LLVM_ENABLE_PGO

echo "merging profraw to profdata"
echo "======================="
PATH=$ORIG_PATH llvm-profdata merge $M_CROSS/profiles/*.profraw -o $M_ROOT/llvm.profdata
echo "... Done"
