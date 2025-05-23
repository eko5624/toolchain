#!/bin/bash
set -e

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
MJOBS=$(grep -c processor /proc/cpuinfo)

export M_ROOT=$(pwd)
export RUSTUP_LOCATION=$M_ROOT/rust

export PATH="$M_CROSS/bin:$RUSTUP_LOCATION/.cargo/bin:$PATH"
export RUSTUP_HOME="$RUSTUP_LOCATION/.rustup"
export CARGO_HOME="$RUSTUP_LOCATION/.cargo"

while [ $# -gt 0 ]; do
    case "$1" in
    --build-x86_64)
        GCC_ARCH="x86-64"
        ;;
    --build-x86_64_v3)
        GCC_ARCH="x86-64-v3"
        ;;
    *)
        echo Unrecognized parameter $1
        exit 1
        ;;
    esac
    shift
done

echo "building rust toolchain"
echo "======================="
curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --target x86_64-pc-windows-gnullvm,x86_64-pc-windows-gnu --no-modify-path --profile minimal
rustup update
LD_PRELOAD= cargo install cargo-c --profile=release-strip --features=vendored-openssl

if [[ "${GCC_ARCH}" == "x86-64" ]]; then
	cat > $CARGO_HOME/config.toml <<EOF
[net]
git-fetch-with-cli = true

[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
ar = "x86_64-w64-mingw32-ar"
rustflags = ["-C", "target-cpu=x86-64"]

[target.x86_64-pc-windows-gnullvm]
linker = "x86_64-w64-mingw32-clang++"
ar = "x86_64-w64-mingw32-ar"
rustflags = ["-C", "target-cpu=x86-64"]

[profile.release]
panic = "abort"
strip = true
EOF
elif [[ "${GCC_ARCH}" == "x86-64-v3" ]]; then
	cat > $CARGO_HOME/config.toml <<EOF
[net]
git-fetch-with-cli = true

[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
ar = "x86_64-w64-mingw32-ar"
rustflags = ["-C", "target-cpu=x86-64-v3"]

[target.x86_64-pc-windows-gnullvm]
linker = "x86_64-w64-mingw32-clang++"
ar = "x86_64-w64-mingw32-ar"
rustflags = ["-C", "target-cpu=x86-64-v3"]

[profile.release]
panic = "abort"
strip = true
EOF
fi	