#!/bin/bash
# ============================================
# Description: Configure image for OLIMEX-A20 board
#
# Requirements :
#   - losetup
#
# Error : From 40 to 49
#   - 100 : Bad usage or image not found
#   - 101 : Boot copy issue.
# ============================================

# ---------------------------------------------- OVERRIDABLE VARIABLES

TARGET_FIRST_SECTOR=2048

# ----------------------------------------------

if [ -z "$UTILS_SOURCED" ]; then
  source ./utils.sh || { echo "ERROR : utils.sh not found."; exit 23; }
fi

# ----------------------------------------------

function _check_permissions() {
    [ ! -f "$INPUT_IMAGE" ] && { error "Input image '$INPUT_IMAGE' not found"; exit 100; }
    [ ! -f "$OUTPUT_IMAGE" ] && { error "Output image '$OUTPUT_IMAGE' not found"; exit 100; }
}

# ----------------------------------------------

function apply_target_configuration(){
  INPUT_IMAGE=$1
  OUTPUT_IMAGE=$2

  _check_permissions

  echo "Copying BOOT to new image.."
  dd if="$INPUT_IMAGE" of="$OUTPUT_IMAGE" bs=1 count=128 conv=notrunc > /dev/null
  if [ $? -ne 0 ]; then
    error "Boot copy issue."
    exit 101
  fi

  info "Image configured for Raspberry."
}