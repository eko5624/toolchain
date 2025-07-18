#!/bin/sh
#
# Copyright (c) 2025 Martin Storsjo
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -e

: ${SQLITE_VERSION:=3490200}
: ${SQLITE_YEAR:=2025}

: ${LLVM_PROFILE_DATA_DIR:=/tmp/llvm-profile}
: ${LLVM_PROFDATA_FILE:=profile.profdata}

while [ $# -gt 0 ]; do
    case "$1" in
    --x86_64)
        FLAGS="--disable-lib32 --enable-lib64"
        TOOLCHAIN_ARCHS="x86_64"
        ;;
    --aarch64)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm64"
        TOOLCHAIN_ARCHS="aarch64"
        ;;
    --armv7)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm32"
        TOOLCHAIN_ARCHS="armv7"
        ;;
    *)
        if [ -n "$PREFIX" ]; then
            if [ -n "$STAGE1" ]; then
                echo Unrecognized parameter $1
                exit 1
            fi
            STAGE1="$1"
        else
            PREFIX="$1"
        fi
        ;;
    esac
    shift
done

export PATH="$STAGE1/bin:$PATH"

MAKE=make
if command -v gmake >/dev/null; then
    MAKE=gmake
fi

: ${ARCHS:=${TOOLCHAIN_ARCHS-x86_64 armv7 aarch64}}

download() {
    if command -v curl >/dev/null; then
        curl -LO "$1"
    else
        wget "$1"
    fi
}

SQLITE=sqlite-amalgamation-$SQLITE_VERSION
if [ ! -d $SQLITE ]; then
    download https://sqlite.org/$SQLITE_YEAR/sqlite-amalgamation-$SQLITE_VERSION.zip
    unzip sqlite-amalgamation-$SQLITE_VERSION.zip
fi

rm -rf "$LLVM_PROFILE_DATA_DIR"
$MAKE -f pgo-training.make PREFIX=$PREFIX STAGE1=$STAGE1 SQLITE=$SQLITE clean
$MAKE -f pgo-training.make PREFIX=$PREFIX STAGE1=$STAGE1 SQLITE=$SQLITE -j$CORES

rm -f "$LLVM_PROFDATA_FILE"
$STAGE1/bin/llvm-profdata merge -output "$LLVM_PROFDATA_FILE" $LLVM_PROFILE_DATA_DIR/*.profraw
rm -rf "$LLVM_PROFILE_DATA_DIR"
