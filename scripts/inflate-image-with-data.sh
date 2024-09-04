#!/bin/bash
# ============================================
# Description: Inflate generated image with original data image.
#
# Requirements :
#   - losetup
#
# Error : From 40 to 49
#   - 40 : Bad usage
#   - 41 : Source directory not found
#   - 42 : Source image not found
#   - 43 : Mount issue
#   - 44 : Missing data file
#   - 45 : Inflating error
# ============================================

if [ -z "$UTILS_SOURCED" ]; then
  source ./utils.sh || { echo "ERROR : utils.sh not found."; exit 23; }
fi

function check_requirements() {
  [ -z "$SRC_DIR" ] && { error "inflate_image_with_data <SRC_DIR> <IMAGE_FILE>"; exit 40; }
  [ -z "$IMAGE_FILE" ] && { error "inflate_image_with_data <SRC_DIR> <IMAGE_FILE>"; exit 40; }
  [ ! -d "$SRC_DIR" ] && { error "Source directory '$SRC_DIR' not found"; exit 41; }
  [ ! -f "$IMAGE_FILE" ] && { error "Source image '$IMAGE_FILE' not found"; exit 42; }
}

function inflate_image_with_data() {
    SRC_DIR=$1
    IMAGE_FILE=$2

    check_is_root
    check_requirements

    LOOP_DEVICE=$(losetup -fP --show "$IMAGE_FILE")

    i=1
    while IFS= read -r subdir; do
      data_path=${subdir}/data.tar.gz

      [ ! -f "$data_path" ] && { error "Unable to found '$data_path'."; exit 44; }

      local fs_device=${LOOP_DEVICE}p${i}
      local tmp_dir=$(mktemp -d)

      mount "$fs_device" "$tmp_dir" || { error "Unable to mount '$fs_device'."; exit 43; }
      echo "Inflating '$fs_device' ($tmp_dir).."
      tar -xzf "$data_path" -C "$tmp_dir" || { error "Unable to inflate '$fs_device'."; exit 45; }

      umount "$tmp_dir"
      rm -d "$tmp_dir"
      i=$((i+1))
    done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

    losetup -d "$LOOP_DEVICE"
}

