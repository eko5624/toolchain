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

echo "building rust toolchain"
echo "======================="
curl -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --target x86_64-pc-windows-gnu --no-modify-path --profile minimal

# Rust 1.77.2 is the last version supporting Windows 7
rustup toolchain install 1.77.2-x86_64-unknown-linux-gnu
rustup default 1.77.2-x86_64-unknown-linux-gnu
LD_PRELOAD= cargo install --version "0.9.31+cargo-0.78" cargo-c --profile=release-strip --features=vendored-openssl --locked
rm -rf $RUSTUP_HOME/toolchains/stable-x86_64-unknown-linux-gnu
cat <<EOF >$CARGO_HOME/config.toml
[net]
git-fetch-with-cli = true

[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
ar = "x86_64-w64-mingw32-ar"
rustflags = ["-C", "target-cpu=x86-64"]

[profile.release]
panic = "abort"
strip = true
EOF