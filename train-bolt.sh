#!/bin/bash
set -e

M_ROOT=$(pwd)
M_SOURCE=$M_ROOT/source
M_CROSS=$M_ROOT/cross
PATH="$M_CROSS/bin:$PATH"

mkdir -p $M_SOURCE

echo "training sqlite"
echo "======================="
cd $M_SOURCE
curl -OL "https://www.sqlite.org/2024/sqlite-autoconf-3450200.tar.gz"
tar -xvf sqlite-autoconf-3450200.tar.gz
rm sqlite*.tar.gz
cd sqlite-autoconf-3450200
llvm-bolt \
  --instrument \
  --instrumentation-file-append-pid \
  --instrumentation-file=$M_CROSS/llvm-bolt/llvm \
$M_CROSS/bin/llvm -o $M_CROSS/bin/llvm.instr
mkdir -p $M_CROSS/llvm-bolt
$M_CROSS/bin/llvm.instr clang \
  --target=x86_64-pc-windows-gnu \
  --sysroot=$M_CROSS/x86_64-w64-mingw32 \
  -O3 \
  -pipe \
  -fdata-sections \
  -ffunction-sections \
  -ffp-contract=fast \
  -funroll-loops \
  -gcodeview \
  -mguard=cf \
  -g3 \
  sqlite3.c shell.c -o sqlite3.exe
rm sqlite3.exe $M_CROSS/bin/llvm.instr
merge-fdata $M_CROSS/llvm-bolt/* -o $M_CROSS/llvm.fdata
rm -r $M_CROSS/llvm-bolt
llvm-bolt \
  --data $M_CROSS/llvm.fdata \
  $M_CROSS/bin/llvm -o $M_CROSS/bin/llvm.bolt \
  --dyno-stats \
  --eliminate-unreachable \
  --frame-opt=hot \
  --icf=1 \
  --plt=hot \
  --reorder-blocks=ext-tsp \
  --reorder-functions=cdsort \
  --split-all-cold \
  --split-eh \
  --split-functions \
  --use-gnu-stack
llvm-strip -s $M_CROSS/bin/llvm.bolt
rm -r $M_CROSS/llvm.fdata
mv $M_CROSS/bin/llvm.bolt $M_CROSS/bin/llvm