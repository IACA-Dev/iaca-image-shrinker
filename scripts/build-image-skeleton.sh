#!/bin/bash
# ============================================
# Description: Build image skeleton (MBR, partition table and prepare partitions)
#
# Requirements :
#   - losetup
#   - jq
#   - e2label
#   - dosfslabel
#
# Error : From 30 to 39
#   - 30 : Bad usage
#   - 31 : Source directory not found
#   - 32 : Missing info file
#   - 33 : Malformed info file
# ============================================


if [ -z "$UTILS_SOURCED" ]; then
  source ./utils.sh || { echo "ERROR : utils.sh not found."; exit 23; }
fi


function check_requirements() {
  [ -z "$SRC_DIR" ] && { error "$0 <SRC_DIR> <IMAGE_FILE>"; exit 30; }
  [ -z "$IMAGE_FILE" ] && { error "$0 <SRC_DIR> <IMAGE_FILE>"; exit 30; }
  [ ! -d "$SRC_DIR" ] && { error "Source directory '$SRC_DIR' not found"; exit 31; }
}

function get_size() {
  local info_file=${1}/info.json
  [ ! -f "$info_file" ] && { error "Missing 'info.json' file in '$1'."; exit 32; }

  cat "$info_file" | jq '.size' || { error "No attribut 'size' found in '$info_file'."; exit 33; }
}

function get_label() {
  local info_file=${1}/info.json
  [ ! -f "$info_file" ] && { error "Missing 'info.json' file in '$1'."; exit 32; }

  cat "$info_file" | jq -r '.label' || { error "No attribut 'label' found in '$info_file'."; exit 33; }
}

function get_fs_type() {
  local info_file=${1}/info.json
  [ ! -f "$info_file" ] && { error "Missing 'info.json' file in '$1'."; exit 32; }

  cat "$info_file" | jq -r '.type' || { error "No attribut 'type' found in '$info_file'."; exit 33; }
}

function get_total_size() {
  local total=0
  while IFS= read -r subdir; do
    local size=$(get_size "$subdir")
    total=$((total + size))
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d)
  echo $total
}

function generate_new_image() {
  local size=$1
  dd if=/dev/zero of="$IMAGE_FILE" bs=$((size * 1024 + (2048 * 512))) count=1 status=progress
}

function generate_partition_table() {
  local last_sector_index=2048
    while IFS= read -r subdir; do
      local size=$(get_size "$subdir")

      echo "Creating $size bytes partition."

      local sector_count=$((size * 1024 / 512))

      (
      echo n                                            # Add a new partition
      echo                                              # Default - Primary partition
      echo                                              # Default - Partition number
      echo $last_sector_index                           # Default - First sector
      echo $((last_sector_index + sector_count - 1))    # Last sector (e.g., +100M for 100MB)
      echo w                                            # Write changes
      ) | fdisk "$LOOP_DEVICE" > /dev/null

      last_sector_index=$((last_sector_index + sector_count))
      echo "last : $last_sector_index"

    done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d)
}

function format_partitions() {
  local i=1
  while IFS= read -r subdir; do
    local fs_device=${LOOP_DEVICE}p${i}
    local type=$(get_fs_type "$subdir")
    local cmd=

    if [ "$type" == "ext4" ]; then
      cmd="mkfs.ext4 $fs_device"
    elif [ "$type" == "vfat" ]; then
      cmd="mkfs.fat $fs_device"
    else
      error "Filesystem type '$type' is not supported ($fs_device)."
    fi

    if [ ! -z "$cmd" ]; then
      $cmd > /dev/null && info "Device '$fs_device' formatted." || { error "Unable to format '$fs_device'."; }
    fi

    i=$((i+1))
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d)
}

function write_labels() {
  local i=1
  while IFS= read -r subdir; do
    local label=$(get_label $subdir)

    if [ ! -z "$label" ]; then
      fs_device=${LOOP_DEVICE}p${i}

      local type=$(get_fs_type "$subdir")

      local cmd="e2label $fs_device $label"

      if [ "$type" == "vfat" ]; then
        cmd="dosfslabel $fs_device $label"
      fi

      $cmd > /dev/null && info "Label '$label' set to '$fs_device'." || { warn "Unable to set label '$label' to device '$fs_device'"; }
    fi

    i=$((i+1))
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d)
}

function build_image_skeleton {
  SRC_DIR=$1
  IMAGE_FILE=$2

  check_is_root
  check_requirements
  local total=$(get_total_size)

  echo "Generating $total bytes image."
  generate_new_image $total

  LOOP_DEVICE=$(losetup -fP --show "$IMAGE_FILE")

  generate_partition_table
  format_partitions
  write_labels

  losetup -d "$LOOP_DEVICE"
}