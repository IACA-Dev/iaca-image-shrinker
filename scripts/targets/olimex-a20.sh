#!/bin/bash
# ============================================
# Description: Configure image for OLIMEX-A20 board
#
# Requirements :
#   - losetup
#
# Error : From 40 to 49
#   - 100 : Bad usage or image not found
#   - 101 : U-boot file not found
#   - 102 : Loop issue
#   - 103 : U-boot write issue
# ============================================

# ---------------------------------------------- OVERRIDABLE VARIABLES
TARGET_FIRST_SECTOR=20480
# ----------------------------------------------

UBOOT_RAW_DATA=./targets/assets/u-boot-sunxi-with-spl.bin

# ----------------------------------------------


if [ -z "$UTILS_SOURCED" ]; then
  source ./utils.sh || { echo "ERROR : utils.sh not found."; exit 23; }
fi

function _check_permissions() {

    [ ! -f "$INPUT_IMAGE" ] && { error "Input image '$INPUT_IMAGE' not found"; exit 100; }
    [ ! -f "$UBOOT_RAW_DATA" ] && { error "U-boot file '$UBOOT_RAW_DATA' not found"; exit 101; }

}


function apply_target_configuration(){
  INPUT_IMAGE=$1

  _check_permissions

  LOOP_DEVICE=$(losetup -fP --show "$IMAGE_FILE")
  if [ $? -ne 0 ]; then
    error "Unable to load image in loop."
    exit 102
  fi

  echo "Writing U-BOOT binary.."
  dd if="$UBOOT_RAW_DATA" of="$LOOP_DEVICE" bs=1k seek=8 conv=notrunc > /dev/null
  if [ $? -ne 0 ]; then
    error "U-boot write issue."
    exit 103
  fi

  info "Image configured for Olimex A20 board."

  losetup -d "$LOOP_DEVICE"
}