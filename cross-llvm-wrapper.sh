#!/bin/bash
set -e

TOP_DIR=$(pwd)
M_ROOT=$(pwd)
M_CROSS=$M_ROOT/cross

while [ $# -gt 0 ]; do
    case "$1" in
    --x86_64)
        _TARGET_CPU=x86_64
        _TARGET_ARCH=x86_64-w64-mingw32
        _GCC_ARCH="x86-64"
        _LD_M_FLAG="i386pep"
        ;;
    --x86_64_v3)
        _TARGET_CPU=x86_64
        _TARGET_ARCH=x86_64-w64-mingw32
        _GCC_ARCH="x86-64-v3"
        _LD_M_FLAG="i386pep"
        ;;
    --aarch64)
        _TARGET_CPU=aarch64
        _TARGET_ARCH=aarch64-w64-mingw32
        _GCC_ARCH="cortex-a76"
        _LD_M_FLAG="arm64pe"
        ;;
    *)
        echo Unrecognized parameter $1
        exit 1
        ;;
    esac
    shift
done

echo "installing llvm-wrappers"
echo "======================="
cd $M_CROSS/bin
ln -s llvm-ar ${_TARGET_ARCH}-ar
ln -s llvm-ar ${_TARGET_ARCH}-llvm-ar
ln -s llvm-ranlib ${_TARGET_ARCH}-ranlib
ln -s llvm-ranlib ${_TARGET_ARCH}-llvm-ranlib
ln -s llvm-dlltool ${_TARGET_ARCH}-dlltool
ln -s llvm-dlltool ${_TARGET_ARCH}-llvm-dlltool
ln -s llvm-objcopy ${_TARGET_ARCH}-objcopy
ln -s llvm-objcopy ${_TARGET_ARCH}-llvm-objcopy
ln -s llvm-strip ${_TARGET_ARCH}-strip
ln -s llvm-strip ${_TARGET_ARCH}-llvm-strip
ln -s llvm-size ${_TARGET_ARCH}-size
ln -s llvm-size ${_TARGET_ARCH}-llvm-size
ln -s llvm-nm ${_TARGET_ARCH}-nm
ln -s llvm-nm ${_TARGET_ARCH}-llvm-nm
ln -s llvm-readelf ${_TARGET_ARCH}-readelf
ln -s llvm-readelf ${_TARGET_ARCH}-llvm-readelf
ln -s llvm-windres ${_TARGET_ARCH}-windres
ln -s llvm-windres ${_TARGET_ARCH}-llvm-windres
ln -s llvm-addr2line ${_TARGET_ARCH}-addr2line
ln -s llvm-addr2line ${_TARGET_ARCH}-llvm-addr2line
ln -s $(which pkgconf) ${_TARGET_ARCH}-pkg-config
ln -s $(which pkgconf) ${_TARGET_ARCH}-pkgconf

replace_env() {
  sed -e "s|@clang_compiler@|${_CLANG_COMPILER}|g" \
      -e "s|@target_cpu@|${_TARGET_CPU}|g" \
      -e "s|@target_arch@|${_TARGET_ARCH}|g" \
      -e "s|@gcc_arch@|${_GCC_ARCH}|g" \
      -i "$1"
}

cd $TOP_DIR/llvm-static-wrappers
for i in clang++ g++ c++ cc clang gcc as; do
  BASENAME=${_TARGET_ARCH}-$i
  install -vm755 llvm-compiler.in $M_CROSS/bin/$BASENAME
  case $BASENAME in
  ${_TARGET_ARCH}-clang++|${_TARGET_ARCH}-g++|${_TARGET_ARCH}-c++)
      _CLANG_COMPILER="clang++"
      replace_env $M_CROSS/bin/$BASENAME
      ;;
  *)
      _CLANG_COMPILER="clang"
      replace_env $M_CROSS/bin/$BASENAME
      ;;
  esac
done

install -vm755 llvm-ld.in $M_CROSS/bin/${_TARGET_ARCH}-ld
sed -i "s|@target_arch@|${_TARGET_ARCH}|g" $M_CROSS/bin/${_TARGET_ARCH}-ld
sed -i "s|@ld_m_flag@|${_LD_M_FLAG}|g" $M_CROSS/bin/${_TARGET_ARCH}-ld

cat $M_CROSS/bin/${_TARGET_ARCH}-g++
