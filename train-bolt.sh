#!/bin/bash
set -e

M_ROOT=$(pwd)
M_SOURCE=$M_ROOT/source
M_CROSS=$M_ROOT/cross
PATH="$M_CROSS/bin:$PATH"

mkdir -p $M_SOURCE

while [ $# -gt 0 ]; do
    case "$1" in
    --x86_64)
        _TARGET_CPU=x86_64
        _TARGET_ARCH=x86_64-w64-mingw32
        ;;
    --x86_64_v3)
        _TARGET_CPU=x86_64
        _TARGET_ARCH=x86_64-w64-mingw32
        ;;
    --aarch64)
        _TARGET_CPU=aarch64
        _TARGET_ARCH=aarch64-w64-mingw32
        ;;
    *)
        echo Unrecognized parameter $1
        exit 1
        ;;
    esac
    shift
done

echo "training sqlite"
echo "======================="
cd $M_SOURCE
curl -OL "https://www.sqlite.org/2024/sqlite-autoconf-3470200.tar.gz"
tar -xvf sqlite-autoconf-3470200.tar.gz
rm sqlite*.tar.gz
cd sqlite-autoconf-3470200
llvm-bolt $M_CROSS/bin/llvm \
  -o $M_CROSS/bin/llvm.instr \
  --instrument \
  --instrumentation-file-append-pid \
  --instrumentation-file=$M_CROSS/llvm-bolt/llvm \
  --lite=false
ln -s $M_CROSS/bin/llvm.instr ld.lld
mkdir -p $M_CROSS/llvm-bolt
$M_CROSS/bin/llvm.instr clang \
  --target=${_TARGET_CPU}-pc-windows-gnu \
  --sysroot=$M_CROSS/${_TARGET_ARCH} \
  -D_WIN32_WINNT=0x0A00 \
  -DWINVER=0x0A00 \
  -DNDEBUG \
  -D__CRT__NO_INLINE \
  -Xclang \
  -mlong-double-64 \
  -fno-temp-file \
  -flto=thin \
  -fwhole-program-vtables \
  -fno-split-lto-unit \
  -fuse-ld=lld \
  --ld-path=./ld.lld \
  -O3 \
  -fno-auto-import \
  -fdata-sections \
  -ffunction-sections \
  -funroll-loops \
  -fstrict-flex-arrays=3 \
  -falign-functions=32 \
  -fno-signed-zeros \
  -fno-trapping-math \
  -freciprocal-math \
  -fapprox-func \
  -mrecip=all \
  -ffp-contract=fast \
  -fno-math-errno \
  -fomit-frame-pointer \
  -fmerge-all-constants \
  -fno-unique-section-names \
  -gcodeview \
  -mguard=cf \
  -Wl,-mllvm,-slp-revec,-mllvm,-disable-auto-upgrade-debug-info \
  -g3 \
  -Wl,--gc-sections,--icf=all,-O3,--lto-O3,--lto-CGO3,--disable-runtime-pseudo-reloc,--pdb= \
  sqlite3.c shell.c -o sqlite3.exe
$M_CROSS/bin/llvm.instr clang \
  --target=${_TARGET_CPU}-pc-windows-gnu \
  --sysroot=$M_CROSS/${_TARGET_ARCH} \
  -D_WIN32_WINNT=0x0A00 \
  -DWINVER=0x0A00 \
  -DNDEBUG \
  -D__CRT__NO_INLINE \
  -Xclang -mlong-double-64 \
  -fno-temp-file \
  -fno-split-lto-unit \
  -fuse-ld=lld \
  --ld-path=./ld.lld \
  -O3 \
  -fno-auto-import \
  -fdata-sections \
  -ffunction-sections \
  -funroll-loops \
  -fstrict-flex-arrays=3 \
  -falign-functions=32 \
  -fno-signed-zeros \
  -fno-trapping-math \
  -freciprocal-math \
  -fapprox-func \
  -mrecip=all \
  -ffp-contract=fast \
  -fno-math-errno \
  -fomit-frame-pointer \
  -fmerge-all-constants \
  -fno-unique-section-names \
  -gcodeview \
  -mguard=cf \
  -mllvm \
  -slp-revec \
  -g3 \
  -Wl,--gc-sections,--icf=all,-O3,--lto-O3,--lto-CGO3,--disable-runtime-pseudo-reloc,--pdb= \
  sqlite3.c shell.c -o sqlite3.exe
rm sqlite3.exe ld.lld $M_CROSS/bin/llvm.instr
merge-fdata $M_CROSS/llvm-bolt/* -o $M_CROSS/llvm.fdata
rm -r $M_CROSS/llvm-bolt
llvm-bolt \
  --data $M_CROSS/llvm.fdata \
  $M_CROSS/bin/llvm -o $M_CROSS/bin/llvm.bolt \
  --align-blocks \
  --assume-abi \
  --cg-use-split-hot-size \
  --cmov-conversion \
  --dyno-stats \
  --fix-block-counts \
  --fix-func-counts \
  --frame-opt-rm-stores \
  --frame-opt=all \
  --hot-data \
  --hot-text \
  --icf=all \
  --icp-inline \
  --icp-jump-tables-targets \
  --icp=jump-tables \
  --infer-fall-throughs \
  --inline-ap \
  --inline-small-functions \
  --iterative-guess \
  --jump-tables=aggressive \
  --min-branch-clusters \
  --peepholes=all \
  --plt=all \
  --reg-reassign \
  --reorder-blocks=ext-tsp \
  --reorder-functions=cdsort \
  --sctc-mode=always \
  --simplify-rodata-loads \
  --split-all-cold \
  --split-eh \
  --split-functions \
  --split-strategy=cdsplit \
  --stoke \
  --tail-duplication=cache \
  --three-way-branch
llvm-strip -s $M_CROSS/bin/llvm.bolt
rm -r $M_CROSS/llvm.fdata
mv $M_CROSS/bin/llvm.bolt $M_CROSS/bin/llvm