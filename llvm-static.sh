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
M_INSTALL=$M_ROOT/install
M_HOST=$M_ROOT/host
PREFIX=$M_CROSS

llvm_cflags="-march=native -fno-ident -fno-temp-file -fno-math-errno -ftls-model=local-exec"
#llvm_cflags=""
PATH="$M_HOST/bin:/usr/local/fuchsia-clang/bin:$PATH"
LLVM_PROFILE_FILE="/dev/null"
LLVM_ENABLE_LTO="OFF" #STRING "OFF, ON, Thin and Full"
LLVM_ENABLE_PGO="OFF" #STRING "OFF, GEN, CSGEN, USE"
LLVM_ENABLE_BOLT="OFF" #STRING "OFF, GEN, USE"
LLVM_CCACHE_BUILD="OFF"

while [ $# -gt 0 ]; do
    case "$1" in
    --enable-pgo_gen)
        LLVM_ENABLE_PGO="GEN" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    --enable-pgo_use)
        LLVM_ENABLE_PGO="USE" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    --enable-bolt_use)
        LLVM_ENABLE_BOLT="USE" #STRING "OFF, GEN, USE"
        ;;
    --enable-llvm-thin_lto)
        LLVM_ENABLE_LTO="Thin" #STRING "OFF, ON, Thin and Full"
        ;;
    --enable-llvm-full_lto)
        LLVM_ENABLE_LTO="Full" #STRING "OFF, ON, Thin and Full"
        ;;
    --enable-llvm-ccache)
        LLVM_CCACHE_BUILD="ON" #STRING "OFF, GEN, CSGEN, USE"
        ;;
    *)
        echo Unrecognized parameter $1
        exit 1
        ;;
    esac
    shift
done

if [ "$LLVM_ENABLE_LTO" == "Thin" ]; then
    llvm_lto=" -flto=thin -fwhole-program-vtables -fsplit-lto-unit"
elif [ "$LLVM_ENABLE_LTO" == "Full" ]; then
    llvm_lto=" -flto=full -fwhole-program-vtables -fsplit-lto-unit"
fi

if [ "$LLVM_ENABLE_PGO" == "GEN" ] || [ "$LLVM_ENABLE_PGO" == "CSGEN" ]; then
    LLVM_PROFILE_DATA_DIR="$PREFIX/profiles" #PATH "Default profile generation directory"
elif [ "$LLVM_ENABLE_PGO" == "USE" ]; then
    PREFIX=$M_ROOT/llvm_pgo
    LLVM_PROFDATA_FILE=$M_ROOT/llvm.profdata
fi

if [ "$LLVM_ENABLE_PGO" == "GEN" ]; then
   llvm_pgo=" -fprofile-generate=${LLVM_PROFILE_DATA_DIR} -fprofile-update=atomic -mllvm -vp-counters-per-site=8"
elif [ "$LLVM_ENABLE_PGO" == "CSGEN" ]; then
   llvm_pgo=" -fcs-profile-generate=${LLVM_PROFILE_DATA_DIR} -fprofile-update=atomic -mllvm -vp-counters-per-site=8 -fprofile-use=${LLVM_PROFDATA_FILE}"
elif [ "$LLVM_ENABLE_PGO" == "USE" ]; then
   llvm_pgo=" -fprofile-use=${LLVM_PROFDATA_FILE}"
fi

if [ "$LLVM_ENABLE_BOLT" == "USE" ]; then
    llvm_bolt=";bolt"
fi

if [ "$LLVM_CCACHE_BUILD" == "ON" ]; then
    LLVM_CCACHE_MAXSIZE="500M"
    LLVM_CCACHE_DIR=$PREFIX/llvm-ccache
    llvm_ccache="-DLLVM_CCACHE_BUILD=ON -DLLVM_CCACHE_DIR=${LLVM_CCACHE_DIR} -DLLVM_CCACHE_MAXSIZE=${LLVM_CCACHE_MAXSIZE}"
fi  

mkdir -p $M_SOURCE
mkdir -p $M_BUILD

echo "getting source"
echo "======================="
cd $M_SOURCE

#llvm
#git clone https://github.com/llvm/llvm-project.git --branch release/18.x llvmorg-$VER_LLVM
if [ ! -d "$M_SOURCE/llvm-project" ]; then
  git clone --sparse --filter=tree:0 https://github.com/llvm/llvm-project.git --branch llvmorg-$VER_LLVM
  cd llvm-project
  git sparse-checkout set --no-cone '/*' '!*/test' '!/lldb' '!/mlir' '!/clang-tools-extra' '!/polly' '!/flang'
  cd ..
fi

echo "building zlib-ng"
echo "======================="
cd $M_SOURCE
git clone https://github.com/zlib-ng/zlib-ng.git
cd $M_BUILD
mkdir zlib-build
NO_CONFLTO=1 PKG_CONFIG_LIBDIR= cmake -G Ninja -H$M_SOURCE/zlib-ng -B$M_BUILD/zlib-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_FIND_NO_INSTALL_PREFIX=ON \
  -DCMAKE_INSTALL_PREFIX=$M_INSTALL \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON \
  -DSKIP_INSTALL_LIBRARIES=OFF \
  -DZLIB_COMPAT=ON \
  -DZLIB_ENABLE_TESTS=OFF \
  -DZLIBNG_ENABLE_TESTS=OFF \
  -DWITH_GTEST=OFF \
  -DWITH_SANITIZER=OFF \
  -DFNO_LTO_AVAILABLE=OFF \
  -DCMAKE_C_FLAGS="${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_CXX_FLAGS="${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_ASM_FLAGS="${llvm_cflags}${llvm_lto}${llvm_pgo}"
cmake --build zlib-build -j$MJOBS
cmake --install zlib-build

echo "building libxml2"
echo "======================="
cd $M_SOURCE
git clone https://github.com/GNOME/libxml2.git
cd libxml2
git reset --hard 66fdf94c5518547c12311db1e4dc0485acf2a2f8
cd $M_BUILD
mkdir libxml2-build
NO_CONFLTO=1 PKG_CONFIG_LIBDIR= cmake -G Ninja -H$M_SOURCE/libxml2 -B$M_BUILD/libxml2-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_FIND_NO_INSTALL_PREFIX=ON \
  -DCMAKE_INSTALL_PREFIX=$M_INSTALL \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON \
  -DLIBXML2_WITH_ZLIB=ON \
  -DLIBXML2_WITH_TREE=ON \
  -DLIBXML2_WITH_THREADS=ON \
  -DLIBXML2_WITH_THREAD_ALLOC=ON \
  -DLIBXML2_WITH_TLS=ON \
  -DLIBXML2_WITH_ICONV=OFF \
  -DLIBXML2_WITH_ICU=OFF \
  -DLIBXML2_WITH_LZMA=OFF \
  -DLIBXML2_WITH_HTTP=OFF \
  -DLIBXML2_WITH_TESTS=OFF \
  -DLIBXML2_WITH_DEBUG=OFF \
  -DLIBXML2_WITH_PYTHON=OFF \
  -DLIBXML2_WITH_MODULES=OFF \
  -DLIBXML2_WITH_PROGRAMS=OFF \
  -DZLIB_LIBRARY=$M_INSTALL/lib/libz.a \
  -DZLIB_INCLUDE_DIR=$M_INSTALL/include \
  -DCMAKE_C_FLAGS="${llvm_cflags} ${llvm_lto}${llvm_pgo}" \
  -DCMAKE_CXX_FLAGS="${llvm_cflags} ${llvm_lto}${llvm_pgo}" \
  -DCMAKE_ASM_FLAGS="${llvm_cflags} ${llvm_lto}${llvm_pgo}"
cmake --build libxml2-build -j$MJOBS
cmake --install libxml2-build --component development


echo "building zstd"
echo "======================="
cd $M_SOURCE
git clone https://github.com/facebook/zstd.git
cd $M_BUILD
mkdir zstd-build
NO_CONFLTO=1 PKG_CONFIG_LIBDIR= cmake -G Ninja -H$M_SOURCE/zstd/build/cmake -B$M_BUILD/zstd-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_FIND_NO_INSTALL_PREFIX=ON \
  -DCMAKE_INSTALL_PREFIX=$M_INSTALL \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON \
  -DZSTD_BUILD_CONTRIB=OFF \
  -DZSTD_BUILD_TESTS=OFF \
  -DZSTD_LEGACY_SUPPORT=OFF \
  -DZSTD_BUILD_PROGRAMS=OFF \
  -DZSTD_BUILD_SHARED=OFF \
  -DZSTD_BUILD_STATIC=ON \
  -DZSTD_MULTITHREAD_SUPPORT=ON \
  -DCMAKE_C_FLAGS="${llvm_cflags} ${llvm_lto}${llvm_pgo}" \
  -DCMAKE_CXX_FLAGS="${llvm_cflags} ${llvm_lto}${llvm_pgo}" \
  -DCMAKE_ASM_FLAGS="${llvm_cflags} ${llvm_lto}${llvm_pgo}"
cmake --build zstd-build -j$MJOBS
cmake --install zstd-build

echo "building mimalloc"
echo "======================="
cd $M_SOURCE
git clone https://github.com/microsoft/mimalloc.git --branch dev2
cd $M_BUILD
mkdir -p mimalloc-build/shared
NO_CONFLTO=1 PKG_CONFIG_LIBDIR= cmake -G Ninja -H$M_SOURCE/mimalloc -B$M_BUILD/mimalloc-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_FIND_NO_INSTALL_PREFIX=ON \
  -DCMAKE_INSTALL_PREFIX=$M_INSTALL \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON \
  -DMI_USE_CXX=OFF \
  -DMI_OVERRIDE=ON \
  -DMI_INSTALL_TOPLEVEL=ON \
  -DMI_BUILD_TESTS=OFF \
  -DMI_BUILD_SHARED=OFF \
  -DMI_BUILD_STATIC=OFF \
  -DMI_SKIP_COLLECT_ON_EXIT=ON \
  -DCMAKE_C_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_CXX_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_ASM_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo}"
NO_CONFLTO=1 PKG_CONFIG_LIBDIR= cmake -G Ninja -H$M_SOURCE/mimalloc -B$M_BUILD/mimalloc-build/shared \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_FIND_NO_INSTALL_PREFIX=ON \
  -DCMAKE_INSTALL_PREFIX=$M_INSTALL \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON \
  -DMI_USE_CXX=OFF \
  -DMI_OVERRIDE=ON \
  -DMI_INSTALL_TOPLEVEL=ON \
  -DMI_BUILD_TESTS=OFF \
  -DMI_BUILD_SHARED=ON \
  -DMI_BUILD_STATIC=OFF \
  -DMI_BUILD_OBJECT=OFF \
  -DMI_SKIP_COLLECT_ON_EXIT=ON \
  -DMI_USE_LIBATOMIC=OFF \
  -DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON \
  -DCMAKE_C_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo} -ftls-model=initial-exec --unwindlib=none" \
  -DCMAKE_CXX_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo} -ftls-model=initial-exec --unwindlib=none" \
  -DCMAKE_ASM_FLAGS="-DMI_DEFAULT_ALLOW_LARGE_OS_PAGES=1 -DMI_DEFAULT_ARENA_EAGER_COMMIT=1 -DMI_DEBUG=0 ${llvm_cflags}${llvm_lto}${llvm_pgo} -ftls-model=initial-exec --unwindlib=none" \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-s -fuse-ld=lld -flto-jobs=$MJOBS -Wl,--lto-whole-program-visibility,-Bsymbolic,--build-id=fast,-O3,--lto-O3,--lto-CGO3,--icf=all,--gc-sections,-s,-znow,-zrodynamic,-zpack-relative-relocs,-zcommon-page-size=2097152,-zmax-page-size=2097152,-zseparate-loadable-segments,-zkeep-text-section-prefix,-zstart-stop-visibility=hidden"
cmake --build mimalloc-build -j$MJOBS
cmake --build mimalloc-build/shared -j$MJOBS
cmake --install mimalloc-build
cp mimalloc-build/shared/libmimalloc.so $M_INSTALL/bin/libmimalloc.so

echo "building llvm"
echo "======================="  
cd $M_BUILD
mkdir llvm-build
NO_CONFLTO=1 PKG_CONFIG_LIBDIR= cmake -G Ninja -H$M_SOURCE/llvm-project/llvm -B$M_BUILD/llvm-build \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER=clang \
  -DCMAKE_C_COMPILER_WORKS=ON \
  -DCMAKE_CXX_COMPILER_WORKS=ON \
  -DCMAKE_ASM_COMPILER_WORKS=ON \
  -DCMAKE_C_COMPILER_TARGET=x86_64-unknown-linux-gnu \
  -DCMAKE_CXX_COMPILER_TARGET=x86_64-unknown-linux-gnu \
  -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-gnu \
  ${llvm_ccache} \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=OFF \
  -DCMAKE_INSTALL_RPATH=OFF \
  -DCMAKE_SKIP_RPATH=ON \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_PROJECTS="clang;lld${llvm_bolt}" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;X86;NVPTX" \
  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
  -DLLVM_ENABLE_LIBCXX=ON \
  -DLLVM_ENABLE_LLD=ON \
  -DLLVM_ENABLE_PIC=OFF \
  -DLLVM_ENABLE_UNWIND_TABLES=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_LTO=${LLVM_ENABLE_LTO} \
  -DCLANG_ENABLE_ARCMT=OFF \
  -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DCLANG_INCLUDE_DOCS=OFF \
  -DLLVM_INCLUDE_UTILS=OFF \
  -DLLVM_INCLUDE_RUNTIMES=OFF \
  -DLLVM_BUILD_RUNTIME=OFF \
  -DLLVM_BUILD_RUNTIMES=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DCLANG_DEFAULT_RTLIB=compiler-rt \
  -DCLANG_DEFAULT_UNWINDLIB=libunwind \
  -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
  -DCLANG_DEFAULT_LINKER=lld \
  -DCLANG_DEFAULT_OBJCOPY=llvm-objcopy \
  -DCLANG_CONFIG_FILE_SYSTEM_DIR="$PREFIX/etc" \
  -DLLD_DEFAULT_LD_LLD_IS_MINGW=ON \
  -DLLVM_LINK_LLVM_DYLIB=OFF \
  -DLLVM_BUILD_LLVM_DYLIB=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DCLANG_BUILD_TOOLS=OFF \
  -DCLANG_ENABLE_OBJC_REWRITER=OFF \
  -DCLANG_TOOL_AMDGPU_ARCH_BUILD=OFF \
  -DCLANG_TOOL_APINOTES_TEST_BUILD=OFF \
  -DCLANG_TOOL_ARCMT_TEST_BUILD=OFF \
  -DCLANG_TOOL_C_ARCMT_TEST_BUILD=OFF \
  -DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF \
  -DCLANG_TOOL_CIR_OPT_BUILD=OFF \
  -DCLANG_TOOL_CLANG_CHECK_BUILD=OFF \
  -DCLANG_TOOL_CLANG_DIFF_BUILD=OFF \
  -DCLANG_TOOL_CLANG_EXTDEF_MAPPING_BUILD=OFF \
  -DCLANG_TOOL_CLANG_FORMAT_BUILD=OFF \
  -DCLANG_TOOL_CLANG_FORMAT_VS_BUILD=OFF \
  -DCLANG_TOOL_CLANG_FUZZER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_IMPORT_TEST_BUILD=OFF \
  -DCLANG_TOOL_CLANG_INSTALLAPI_BUILD=OFF \
  -DCLANG_TOOL_CLANG_LINKER_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_NVLINK_WRAPPER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_OFFLOAD_BUNDLER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_OFFLOAD_PACKAGER_BUILD=OFF \
  -DCLANG_TOOL_CLANG_REFACTOR_BUILD=OFF \
  -DCLANG_TOOL_CLANG_RENAME_BUILD=OFF \
  -DCLANG_TOOL_CLANG_REPL_BUILD=OFF \
  -DCLANG_TOOL_CLANG_SCAN_DEPS_BUILD=OFF \
  -DCLANG_TOOL_CLANG_SHLIB_BUILD=OFF \
  -DCLANG_TOOL_CLANG_SYCL_LINKER_BUILD=OFF \
  -DCLANG_TOOL_DIAGTOOL_BUILD=OFF \
  -DCLANG_TOOL_LIBCLANG_BUILD=OFF \
  -DCLANG_TOOL_NVPTX_ARCH_BUILD=OFF \
  -DCLANG_TOOL_SCAN_BUILD_BUILD=OFF \
  -DCLANG_TOOL_SCAN_BUILD_PY_BUILD=OFF \
  -DCLANG_TOOL_SCAN_VIEW_BUILD=OFF \
  -DLLVM_BUILD_UTILS=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LIBPFM=OFF \
  -DLLVM_ENABLE_OCAMLDOC=OFF \
  -DLLVM_ENABLE_TELEMETRY=OFF \
  -DLLVM_TOOL_BUGPOINT_BUILD=OFF \
  -DLLVM_TOOL_BUGPOINT_PASSES_BUILD=OFF \
  -DLLVM_TOOL_DSYMUTIL_BUILD=OFF \
  -DLLVM_TOOL_DXIL_DIS_BUILD=OFF \
  -DLLVM_TOOL_GOLD_BUILD=OFF \
  -DLLVM_TOOL_LLC_BUILD=OFF \
  -DLLVM_TOOL_LLI_BUILD=OFF \
  -DLLVM_TOOL_LLVM_AS_BUILD=OFF \
  -DLLVM_TOOL_LLVM_AS_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_BCANALYZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_C_TEST_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CAT_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CFI_VERIFY_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CGDATA_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CONFIG_BUILD=OFF \
  -DLLVM_TOOL_LLVM_COV_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CTXPROF_UTIL_BUILD=OFF \
  -DLLVM_TOOL_LLVM_CVTRES_BUILD=OFF \
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
  -DLLVM_TOOL_LLVM_DRIVER_BUILD=ON \
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
  -DLLVM_TOOL_LLVM_MT_BUILD=ON \
  -DLLVM_TOOL_LLVM_OPT_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_LLVM_OPT_REPORT_BUILD=OFF \
  -DLLVM_TOOL_LLVM_PDBUTIL_BUILD=OFF \
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
  -DLLVM_TOOL_LTO_BUILD=OFF \
  -DLLVM_TOOL_OBJ2YAML_BUILD=OFF \
  -DLLVM_TOOL_OPT_BUILD=OFF \
  -DLLVM_TOOL_OPT_VIEWER_BUILD=OFF \
  -DLLVM_TOOL_REDUCE_CHUNK_LIST_BUILD=OFF \
  -DLLVM_TOOL_REMARKS_SHLIB_BUILD=OFF \
  -DLLVM_TOOL_SANCOV_BUILD=OFF \
  -DLLVM_TOOL_SANSTATS_BUILD=OFF \
  -DLLVM_TOOL_SPIRV_TOOLS_BUILD=OFF \
  -DLLVM_TOOL_VERIFY_USELISTORDER_BUILD=OFF \
  -DLLVM_TOOL_VFABI_DEMANGLE_FUZZER_BUILD=OFF \
  -DLLVM_TOOL_XCODE_TOOLCHAIN_BUILD=OFF \
  -DLLVM_TOOL_YAML2OBJ_BUILD=OFF \
  -DLLVM_ENABLE_ZLIB=FORCE_ON \
  -DZLIB_LIBRARY=$M_INSTALL/lib/libz.a \
  -DZLIB_INCLUDE_DIR=$M_INSTALL/include \
  -DLLVM_ENABLE_ZSTD=FORCE_ON \
  -DLLVM_USE_STATIC_ZSTD=ON \
  -Dzstd_LIBRARY=$M_INSTALL/lib/libzstd.a \
  -Dzstd_INCLUDE_DIR=$M_INSTALL/include \
  -DLLVM_ENABLE_LIBXML2=FORCE_ON \
  -DLIBXML2_LIBRARIES=$M_INSTALL/lib/libxml2.a \
  -DLIBXML2_INCLUDE_DIRS=$M_INSTALL/include/libxml2 \
  -DHAVE_LIBXML2=ON \
  -DLLVM_THINLTO_CACHE_PATH=$PREFIX/llvm-lto \
  -DCMAKE_C_FLAGS="-DBLAKE3_NO_SSE2 -DBLAKE3_NO_SSE41 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_CXX_FLAGS="-DBLAKE3_NO_SSE2 -DBLAKE3_NO_SSE41 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_ASM_FLAGS="-DBLAKE3_NO_SSE2 -DBLAKE3_NO_SSE41 ${llvm_cflags}${llvm_lto}${llvm_pgo}" \
  -DCMAKE_EXE_LINKER_FLAGS="$M_INSTALL/lib/mimalloc.o -fuse-ld=lld -flto-jobs=${MJOBS} -Wl,--lto-whole-program-visibility,-Bsymbolic,--build-id=fast,-O3,--lto-O3,--lto-CGO3,--icf=all,--gc-sections,-s,-znow,-zrodynamic,-zpack-relative-relocs,-zcommon-page-size=2097152,-zmax-page-size=2097152,-zseparate-loadable-segments,-zkeep-text-section-prefix,-zstart-stop-visibility=hidden" \
  -DLLVM_TOOLCHAIN_TOOLS="llvm-driver;llvm-ar;llvm-ranlib;llvm-objdump;llvm-rc;llvm-nm;llvm-strings;llvm-readobj;llvm-dlltool;llvm-objcopy;llvm-strip;llvm-profdata;llvm-addr2line;llvm-symbolizer;llvm-windres;llvm-ml;llvm-mt;llvm-readelf;llvm-size"
#cmake --build llvm-build -j$MJOBS
#cmake --install llvm-build
ninja -C llvm-build llvm-driver
ninja -C llvm-build install-llvm-driver install-clang-resource-headers

