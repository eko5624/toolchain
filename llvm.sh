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
export M_INSTALL=$M_ROOT/install

export PATH="/usr/local/fuchsia-clang/bin:$PATH"
export PKG_CONFIG_LIBDIR="$M_INSTALL/lib/pkgconfig"
export PKG_CONFIG="pkgconf --static"
export CFLAGS="-I$M_INSTALL/include"
export CPPFLAGS="-I$M_INSTALL/include"
export LDFLAGS="-L$M_INSTALL/lib"

export LLVM_PROFILE_FILE="/dev/null"
export LLVM_ENABLE_LTO="OFF" #STRING "OFF, ON, Thin and Full"
export LLVM_ENABLE_PGO="OFF" #STRING "OFF, GEN, CSGEN, USE"
export LLVM_CCACHE_BUILD="OFF"
export PREFIX=$M_CROSS

while [ $# -gt 0 ]; do
    case "$1" in
    --enable-pgo_gen)
        export LLVM_ENABLE_PGO="GEN" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    --enable-pgo_use)
        export LLVM_ENABLE_PGO="USE" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    --enable-llvm-thin_lto)
        export LLVM_ENABLE_LTO="Thin" #STRING "OFF, ON, Thin and Full"
        ;;
    --enable-llvm-full_lto)
        export LLVM_ENABLE_LTO="Full" #STRING "OFF, ON, Thin and Full"
        ;;
    --enable-llvm-ccache)
        export LLVM_CCACHE_BUILD="ON" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    *)
        echo Unrecognized parameter $1
        exit 1
        ;;
    esac
    shift
done

if [ "$LLVM_ENABLE_LTO" == "Thin" ]; then
    export llvm_lto="-flto=thin -fwhole-program-vtables -fsplit-lto-unit"
elif [ "$LLVM_ENABLE_LTO" == "Full" ]; then
    export llvm_lto="-flto=full -fwhole-program-vtables -fsplit-lto-unit"
fi

if [ "$LLVM_ENABLE_PGO" == "GEN" ]; then
    export PREFIX=$M_ROOT/cross
    export LLVM_PROFILE_DATA_DIR="$PREFIX/profiles" #PATH "Default profile generation directory"
elif [ "$LLVM_ENABLE_PGO" == "CSGEN" ]; then
    export PREFIX=$M_ROOT/llvm_root
    export LLVM_PROFILE_DATA_DIR="$PREFIX/profiles" #PATH "Default profile generation directory"
elif [ "$LLVM_ENABLE_PGO" == "USE" ]; then
    export PREFIX=$M_ROOT/llvm_root
    export LLVM_PROFDATA_FILE=$M_ROOT/llvm.profdata
fi

if [ "$LLVM_ENABLE_PGO" == "GEN" ]; then
    export llvm_pgo="-fprofile-generate=${LLVM_PROFILE_DATA_DIR} -fprofile-update=atomic"
elif [ "$LLVM_ENABLE_PGO" == "CSGEN" ]; then
    export llvm_pgo="-fcs-profile-generate=${LLVM_PROFILE_DATA_DIR} -fprofile-update=atomic -fprofile-use=${LLVM_PROFDATA_FILE}"
elif [ "$LLVM_ENABLE_PGO" == "USE" ]; then
    export llvm_pgo="-fprofile-use=${LLVM_PROFDATA_FILE}"
fi

if [ "$LLVM_CCACHE_BUILD" == "ON" ]; then
    export LLVM_CCACHE_MAXSIZE="500M"
    export LLVM_CCACHE_DIR=$PREFIX/llvm-ccache
    export llvm_ccache="-DLLVM_CCACHE_BUILD=ON -DLLVM_CCACHE_DIR=${LLVM_CCACHE_DIR} -DLLVM_CCACHE_MAXSIZE=${LLVM_CCACHE_MAXSIZE}"
fi  

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "getting source"
echo "======================="
cd $M_SOURCE

#llvm
#git clone https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone https://github.com/llvm/llvm-project.git --branch release/18.x
  cd llvm-project
  git sparse-checkout set --no-cone '/*' '!*/test' '!/lldb' '!/mlir' '!/clang-tools-extra' '!/polly' '!/libc' '!/flang'
  cd ..
fi

echo "building zlib-ng"
echo "======================="
git clone https://github.com/zlib-ng/zlib-ng.git
cd $M_BUILD
mkdir zlib-build
cmake -G Ninja -H$M_SOURCE/zlib-ng -B$M_BUILD/zlib-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=$M_INSTALL \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DSKIP_INSTALL_LIBRARIES=OFF \
  -DZLIB_COMPAT=ON \
  -DZLIB_ENABLE_TESTS=OFF \
  -DZLIBNG_ENABLE_TESTS=OFF \
  -DFNO_LTO_AVAILABLE=OFF \
  -DCMAKE_C_FLAGS="-march=native -pipe -ffp-contract=fast -ftls-model=local-exec -fdata-sections -ffunction-sections ${llvm_lto}" \
  -DCMAKE_CXX_FLAGS="-march=native -pipe -ffp-contract=fast -ftls-model=local-exec -fdata-sections -ffunction-sections ${llvm_lto}" \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld -Xlinker -s -Xlinker --icf=all -Xlinker --gc-sections"
cmake --build zlib-build -j$MJOBS
cmake --install zlib-build

echo "building zstd"
echo "======================="
cd $M_SOURCE
git clone https://github.com/facebook/zstd.git
cd $M_BUILD
mkdir zstd-build
cmake -G Ninja -H$M_SOURCE/zstd/build/cmake -B$M_BUILD/zstd-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=$M_INSTALL \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DZSTD_BUILD_CONTRIB=OFF \
  -DZSTD_BUILD_TESTS=OFF \
  -DZSTD_LEGACY_SUPPORT=OFF \
  -DZSTD_BUILD_PROGRAMS=OFF \
  -DZSTD_BUILD_SHARED=OFF \
  -DZSTD_BUILD_STATIC=ON \
  -DZSTD_MULTITHREAD_SUPPORT=ON \
  -DCMAKE_C_FLAGS="-march=native -pipe -ffp-contract=fast -ftls-model=local-exec -fdata-sections -ffunction-sections ${llvm_lto}" \
  -DCMAKE_CXX_FLAGS="-march=native -pipe -ffp-contract=fast -ftls-model=local-exec -fdata-sections -ffunction-sections ${llvm_lto}" \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld -Xlinker -s -Xlinker --icf=all -Xlinker --gc-sections"
cmake --build zstd-build -j$MJOBS
cmake --install zstd-build

echo "building mimalloc"
echo "======================="
cd $M_SOURCE
git clone https://github.com/microsoft/mimalloc.git --branch dev-slice
cd $M_BUILD
mkdir mimalloc-build
cmake -G Ninja -H$M_SOURCE/mimalloc -B$M_BUILD/mimalloc-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=$M_INSTALL \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DMI_USE_CXX=OFF \
  -DMI_OVERRIDE=ON \
  -DMI_INSTALL_TOPLEVEL=ON \
  -DMI_BUILD_TESTS=OFF \
  -DMI_BUILD_SHARED=OFF \
  -DMI_BUILD_STATIC=OFF \
  -DCMAKE_C_FLAGS="-march=native -pipe -ffp-contract=fast -ftls-model=local-exec -fdata-sections -ffunction-sections -DMI_DEBUG=0 ${llvm_lto}" \
  -DCMAKE_CXX_FLAGS="-march=native -pipe -ffp-contract=fast -ftls-model=local-exec -flto=thin -fsplit-lto-unit -fwhole-program-vtables -fdata-sections -ffunction-sections -DMI_DEBUG=0 ${llvm_lto}" \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld -Xlinker -s -Xlinker --icf=all -Xlinker --gc-sections"
cmake --build mimalloc-build -j$MJOBS
cmake --install mimalloc-build

echo "building llvm"
echo "======================="  
cd $M_BUILD
mkdir llvm-build
cmake -G Ninja -H$M_SOURCE/llvm-project/llvm -B$M_BUILD/llvm-build \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-pc-windows-gnu \
  ${llvm_ccache} \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="X86;NVPTX" \
  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
  -DLLVM_ENABLE_LIBCXX=ON \
  -DLLVM_ENABLE_LLD=ON \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_LTO=${LLVM_ENABLE_LTO} \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DCLANG_DEFAULT_RTLIB=compiler-rt \
  -DCLANG_DEFAULT_UNWINDLIB=libunwind \
  -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
  -DCLANG_DEFAULT_LINKER=lld \
  -DLLD_DEFAULT_LD_LLD_IS_MINGW=ON \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_LINK_LLVM_DYLIB=OFF \
  -DLLVM_BUILD_LLVM_DYLIB=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DCLANG_ENABLE_ARCMT=OFF \
  -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
  -DCLANG_TOOL_AMDGPU_ARCH_BUILD=OFF \
  -DCLANG_TOOL_APINOTES_TEST_BUILD=OFF \
  -DCLANG_TOOL_ARCMT_TEST_BUILD=OFF \
  -DCLANG_TOOL_C_ARCMT_TEST_BUILD=OFF \
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF \
  -DCLANG_TOOL_CLANG_CHECK_BUILD=OFF \
  -DCLANG_TOOL_CLANG_DIFF_BUILD=OFF \
  -DCLANG_TOOL_CLANG_EXTDEF_MAPPING_BUILD=OFF \
  -DCLANG_TOOL_CLANG_FORMAT_BUILD=OFF \
  -DCLANG_TOOL_CLANG_FORMAT_VS_BUILD=OFF \
  -DCLANG_TOOL_CLANG_FUZZER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_INSTALLAPI_BUILD=OFF \
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF \
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_OFFLOAD_BUNDLER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_OFFLOAD_PACKAGER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_REFACTOR_BUILD=OFF \
  -DCLANG_TOOL_CLANG_RENAME_BUILD=OFF \
  -DCLANG_TOOL_CLANG_REPL_BUILD=OFF \
  -DCLANG_TOOL_CLANG_SCAN_DEPS_BUILD=OFF \
  -DCLANG_TOOL_CLANG_SHLIB_BUILD=OFF \
  -DCLANG_TOOL_DIAGTOOL_BUILD=OFF \
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF \
  -DCLANG_TOOL_NVPTX_ARCH_BUILD=OFF \
  -DCLANG_TOOL_SCAN_BUILD_BUILD=OFF \
  -DCLANG_TOOL_SCAN_BUILD_PY_BUILD=OFF \
  -DCLANG_TOOL_SCAN_VIEW_BUILD=OFF \
  -DCLANG_BUILD_TOOLS=OFF \
  -DLLVM_BUILD_UTILS=OFF \
  -DLLVM_ENABLE_PIC=OFF \
  -DLLVM_ENABLE_UNWIND_TABLES=OFF \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_TOOL_BUGPOINT_BUILD=OFF \
  -DLLVM_TOOL_BUGPOINT_PASSES_BUILD=OFF \
  -DLLVM_TOOL_DSYMUTIL_BUILD=OFF \
  -DLLVM_TOOL_DXIL_DIS_BUILD=OFF \
  -DLLVM_TOOL_GOLD_BUILD=OFF \
  -DLLVM_TOOL_LLC_BUILD=OFF \
  -DLLVM_TOOL_LLI_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DRIVER_BUILD=ON \
  -DLLVM_TOOL_LLVM_AS_BUILD=OFF \
  -DLLVM_TOOL_LLVM_AS_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_BCANALYZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_C_TEST_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CAT_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CFI_VERIFY_BUILD=OFF \
  -DLLVM_TOOL_LLVM_COV_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CXXDUMP_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CXXFILT_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CXXMAP_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DEBUGINFO_ANALYZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DEBUGINFOD_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DEBUGINFOD_FIND_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DIFF_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DIS_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DIS_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DLANG_DEMANGLE_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DWARFDUMP_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DWARFUTIL_BUILD=OFF \
  -DLLVM_TOOL_LLVM_DWP_BUILD=OFF \
  -DLLVM_TOOL_LLVM_EXEGESIS_BUILD=OFF \
  -DLLVM_TOOL_LLVM_EXTRACT_BUILD=OFF \
  -DLLVM_TOOL_LLVM_GSYMUTIL_BUILD=OFF \
  -DLLVM_TOOL_LLVM_IFS_BUILD=OFF \
  -DLLVM_TOOL_LLVM_ISEL_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_ITANIUM_DEMANGLE_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_JITLINK_BUILD=OFF \
  -DLLVM_TOOL_LLVM_JITLISTENER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LIBTOOL_DARWIN_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LINK_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LIPO_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LTO_BUILD=OFF \
  -DLLVM_TOOL_LLVM_LTO2_BUILD=OFF \
  -DLLVM_TOOL_LLVM_MC_ASSEMBLE_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_MC_BUILD=OFF \
  -DLLVM_TOOL_LLVM_MC_DISASSEMBLE_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_MCA_BUILD=OFF \
  -DLLVM_TOOL_LLVM_MICROSOFT_DEMANGLE_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_MODEXTRACT_BUILD=OFF \
  -DLLVM_TOOL_LLVM_MT_BUILD=OFF \
  -DLLVM_TOOL_LLVM_OPT_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_PROFGEN_BUILD=OFF \
  -DLLVM_TOOL_LLVM_READTAPI_BUILD=OFF \
  -DLLVM_TOOL_LLVM_REDUCE_BUILD=OFF \
  -DLLVM_TOOL_LLVM_REMARKUTIL_BUILD=OFF \
  -DLLVM_TOOL_LLVM_RTDYLD_BUILD=OFF \
  -DLLVM_TOOL_LLVM_RUST_DEMANGLE_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_SHLIB_BUILD=OFF \
  -DLLVM_TOOL_LLVM_SIM_BUILD=OFF \
  -DLLVM_TOOL_LLVM_SPECIAL_CASE_LIST_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_SPLIT_BUILD=OFF \
  -DLLVM_TOOL_LLVM_STRESS_BUILD=OFF \
  -DLLVM_TOOL_LLVM_TLI_CHECKER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_UNDNAME_BUILD=OFF \
  -DLLVM_TOOL_LLVM_XRAY_BUILD=OFF \
  -DLLVM_TOOL_LLVM_YAML_NUMERIC_PARSER_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_YAML_PARSER_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_OBJ2YAML_BUILD=OFF \
  -DLLVM_TOOL_OPT_VIEWER_BUILD=OFF \
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
  -DLLVM_TOOL_SANCOV_BUILD=OFF \
  -DLLVM_TOOL_SANSTATS_BUILD=OFF \
  -DLLVM_TOOL_SPIRV_TOOLS_BUILD=OFF \
  -DLLVM_TOOL_VERIFY_USELISTORDER_BUILD=OFF \
  -DLLVM_TOOL_VFABI_DEMANGLE_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_XCODE_TOOLCHAIN_BUILD=OFF \
  -DLLVM_ENABLE_ZLIB=ON \
  -DZLIB_LIBRARY=$M_INSTALL/lib/libz.a \
  -DZLIB_INCLUDE_DIR=$M_INSTALL/include \
  -DLLVM_ENABLE_ZSTD=ON \
  -DLLVM_USE_STATIC_ZSTD=ON \
  -Dzstd_LIBRARY=$M_INSTALL/lib/libzstd.a \
  -Dzstd_INCLUDE_DIR=$M_INSTALL/include \
  -DLLVM_THINLTO_CACHE_PATH="$M_CROSS/llvm-lto" \
  -DCMAKE_C_FLAGS="-g0 -ftls-model=local-exec ${llvm_lto} ${llvm_pgo}" \
  -DCMAKE_CXX_FLAGS="-g0 -ftls-model=local-exec ${llvm_lto} ${llvm_pgo}" \
  -DCMAKE_EXE_LINKER_FLAGS="$M_INSTALL/lib/mimalloc.o -fuse-ld=lld -Xlinker -s -Xlinker --icf=all -Xlinker -zpack-relative-relocs -Xlinker --thinlto-cache-policy=cache_size_bytes=1g:prune_interval=1m -Xlinker -zcommon-page-size=2097152 -Xlinker -zmax-page-size=2097152 -Xlinker -zseparate-loadable-segments" \
  -DLLVM_TOOLCHAIN_TOOLS="llvm-driver;llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-cvtres;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-objcopy;llvm-strip;llvm-cov;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-readelf;llvm-size"
cmake --build llvm-build -j$MJOBS
cmake --install llvm-build
