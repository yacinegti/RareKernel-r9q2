#!/bin/bash

## DEVICE STUFF
DEVICE_HARDWARE="sm8350"
DEVICE_MODEL="$1"
ARGS="$*"
ZIP_DIR="$(pwd)/AnyKernel3"
MOD_DIR="$ZIP_DIR/modules/vendor/lib/modules"
K_MOD_DIR="$(pwd)/out/modules"

# ── Environment ────────────────────────────────────────────────────────────────
SRC_DIR="$(pwd)"

# Snapdragon LLVM 10.0.9
TC_ROOT="$HOME/toolchains/llvm-arm-toolchain-ship"
TC_DIR="$TC_ROOT/r498229b"                    # LLVM tool binaries live here

# GNU ARM toolchain
GCC_DIR="$HOME/toolchains/gcc-arm-gnu"         # GCC tool binaries live here

JOBS="$(nproc --all)"

export KCFLAGS="-Wno-error=strict-prototypes -Wno-error=vla-extension"

MAKE_PARAMS="-j$JOBS -C $SRC_DIR O=$SRC_DIR/out \
             ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 \
            CLANG_TRIPLE=aarch64-linux-gnu- \
             CROSS_COMPILE=$GCC_DIR/bin/aarch64-linux-android-"

export PATH="$TC_DIR/bin:$GCC_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$TC_DIR/lib:$LD_LIBRARY_PATH"

# ── Functions ─────────────────────────────────────────────────────────────────
devicecheck() {
    case "$DEVICE_MODEL" in
        SM-G990B)  DEVICE_NAME="r9q";  DEFCONFIG=vendor/r9q_eur_openx_defconfig ;;
        SM-G990B2) DEVICE_NAME="r9q2"; DEFCONFIG=vendor/r9q_eur_openx2_defconfig ;;
        *) echo "- Config not found  – first argument must be DEVICE_MODEL"; exit ;;
    esac
}

ksu() {
    [[ "$ARGS" == *"--ksu"* ]] && KSU=true || KSU=false

    if $KSU; then
        ZIP_NAME="RareKernel_KSU-Next_${DEVICE_NAME}_${DEVICE_MODEL}_$(date +%d%m%y-%H%M)"
        [[ -d KernelSU ]] || {
            echo "KernelSU not found – fetching…"
            curl -LSs https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh | bash -
        }
    else
        ZIP_NAME="RareKernel_${DEVICE_NAME}_${DEVICE_MODEL}_$(date +%d%m%y-%H%M)"
        [[ ! -d KernelSU ]] || { rm -rf drivers/kernelsu KernelSU; git reset --hard; }
    fi
}

toolchaincheck() {
    if [[ -d "$TC_DIR" ]]; then
        echo "Snapdragon LLVM already present."
    else
        echo "Fetching Snapdragon LLVM 10.0.9…"
        mkdir -p "$HOME/toolchains"
        cd "$HOME/toolchains"
        curl -LO "https://github.com/ravindu644/Android-Kernel-Tutorials/releases/download/toolchains/llvm-arm-toolchain-ship-10.0.9.tar.gz"
        tar -xf llvm-arm-toolchain-ship-10.0.9.tar.gz
        rm  llvm-arm-toolchain-ship-10.0.9.tar.gz
        cd "$SRC_DIR"
    fi
}

help() {
    cat <<EOF

Usage:
  bash ./build_script.sh {DEVICE_MODEL} [options]

Options:
  --ksu        Pull and integrate the latest KernelSU driver.
  --help       Show this message.

EOF
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "$ARGS" in
    *--help*)
        help
        ;;
    *)
        echo "- Starting build…"
        echo "- devicecheck"
        devicecheck
        echo "- ksu"
        ksu
        echo "- toolchaincheck"
        toolchaincheck
        make $MAKE_PARAMS "$DEFCONFIG"
        make $MAKE_PARAMS
        make $MAKE_PARAMS INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install
        
        echo "Build arguments: $ARGS"
        ;;
esac

# This part uses the samsung packer / signer from the samsung kernel building tutorial
# see here: https://github.com/ravindu644/Android-Kernel-Tutorials?tab=readme-ov-file#-building-a-signed-boot-image-from-the-compiled-kernel

# if [ $? -eq 0 ]; then
#     if [ -f ~/ss/retro/android_kernel_samsung_sm8350/out/arch/arm64/boot/Image ]; then
#         mv ~/ss/retro/android_kernel_samsung_sm8350/out/arch/arm64/boot/Image ~/ss/lz4/build/unzip_boot
#     elif [ -f ~/ss/retro/android_kernel_samsung_sm8350/build/Image ]; then
#         mv ~/ss/retro/android_kernel_samsung_sm8350/build/Image ~/ss/lz4/build/unzip_boot
#     else
#         echo "Error: No Image file found."
#         exit 1
#     fi

#     cd ~/ss/lz4/build/unzip_boot
#     mv Image kernel
#     cd ~/ss/lz4

#     ./gradlew pack
#     cp boot.img.signed ../boot.img
#     tar -cvf "Custom-Kernel.tar" ../boot.img
#     echo "Done!"
# else
#     echo "Build failed; skipping packaging."
#     exit 1
# fi