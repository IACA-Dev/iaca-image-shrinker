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
  [ -z "$SRC_DIR" ] && { error "build_image_skeleton <SRC_DIR> <IMAGE_FILE> <FIRST_SECTOR>"; exit 30; }
  [ -z "$IMAGE_FILE" ] && { error "build_image_skeleton <SRC_DIR> <IMAGE_FILE> <FIRST_SECTOR>"; exit 30; }
  [ -z "$FIRST_SECTOR" ] && { error "build_image_skeleton <SRC_DIR> <IMAGE_FILE> <FIRST_SECTOR>"; exit 30; }
  [ ! -d "$SRC_DIR" ] && { error "Source directory '$SRC_DIR' not found"; exit 31; }
}

function get_size_with_offset() {
  local info_file=${1}/info.json
  [ ! -f "$info_file" ] && { error "Missing 'info.json' file in '$1'."; exit 32; }

  local size=$(cat "$info_file" | jq '.size')
  if [ $? -ne 0 ]; then
   error "No attribut 'size' found in '$info_file'."
   exit 33
  fi

  local size_with_offset=$((size + (size * OFFSET_PERCENT / 100)))

  if [ $MINIMUM_SIZE -gt $size_with_offset ]; then
    echo $MINIMUM_SIZE
  else
    echo $size_with_offset
  fi
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

function get_uuid() {
  local info_file=${1}/info.json
  [ ! -f "$info_file" ] && { error "Missing 'info.json' file in '$1'."; exit 32; }

  cat "$info_file" | jq -r '.uuid' || { error "No attribut 'uuid' found in '$info_file'."; exit 33; }
}

function get_disk_identifier() {
  local info_file=${1}/info.json
  [ ! -f "$info_file" ] && { error "Missing 'info.json' file in '$1'."; exit 32; }

  cat "$info_file" | jq -r '.disk_id' || { error "No attribut 'disk_id' found in '$info_file'."; exit 33; }
}

function get_total_size() {
  local total=0
  while IFS= read -r subdir; do
    local size=$(get_size_with_offset "$subdir")
    total=$((total + size))
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d)
  echo $total
}

function generate_new_image() {
  local size=$1
  dd if=/dev/zero of="$IMAGE_FILE" bs=$(((size * 1024 + (FIRST_SECTOR * 512)) / 512)) count=512
}

function generate_partition_table() {
  local last_sector_index=$FIRST_SECTOR
  local i=0
    while IFS= read -r subdir; do
      local size=$(get_size_with_offset "$subdir")

      echo "Creating $size bytes partition."

      local sector_count=$((size * 1024 / 512))

      if [ $i -lt 3 ]; then
        (
        echo n                                            # Add a new partition
        echo                                              # Default - Primary partition
        echo                                              # Default - Partition number
        echo $last_sector_index                           # Default - First sector
        echo $((last_sector_index + sector_count - 1))    # Last sector (e.g., +100M for 100MB)
        echo w                                            # Write changes
        ) | fdisk "$LOOP_DEVICE" > /dev/null
      else
        (
        echo n                                            # Add a new partition
        echo p                                            # Default - Primary partition
        echo $last_sector_index                           # Default - First sector
        echo $((last_sector_index + sector_count - 1))    # Last sector (e.g., +100M for 100MB)
        echo w                                            # Write changes
        ) | fdisk "$LOOP_DEVICE" > /dev/null
      fi

      last_sector_index=$((last_sector_index + sector_count))
      i=$((i+1))
    done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
}

function format_partitions() {
  local i=1
  while IFS= read -r subdir; do
    local fs_device=${LOOP_DEVICE}p${i}
    local type=$(get_fs_type "$subdir")
    local cmd=

    if [ "$type" == "ext4" ]; then
      echo "ext4 fs detected"
      cmd="mkfs.ext4 $fs_device"
    elif [ "$type" == "vfat" ]; then
      echo "fat fs detected"
      cmd="mkfs.fat $fs_device"
    else
      error "Filesystem type '$type' is not supported ($fs_device)."
    fi

    if [ ! -z "$cmd" ]; then
      $cmd > /dev/null && info "Device '$fs_device' formatted." || { error "Unable to format '$fs_device'."; }
    fi

    i=$((i+1))
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
}

function update_partition_table_with_no_ext4_fs() {
  local i=1
  while IFS= read -r subdir; do
    local fs_device=${LOOP_DEVICE}p${i}
    local type=$(get_fs_type "$subdir")
    local fdisk_param=

    if [ "$type" == "vfat" ]; then
      echo "fat fs detected"
      fdisk_param=b
    fi

    if [ ! -z "$fdisk_param" ]; then
      (
      echo t
      echo $i
      echo b
      echo w
      ) | fdisk "$LOOP_DEVICE" > /dev/null && info "Partition $i updated to type '$type' (fdisk=$fdisk_param)." || { error "Unable to update partition $i to type '$type' (fdisk=$fdisk_param)."; }
    fi

    i=$((i+1))
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
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
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
}

function write_uuid() {
  local i=1
  while IFS= read -r subdir; do
    local uuid=$(get_uuid $subdir)

    if [ ! -z "$uuid" ]; then
      fs_device=${LOOP_DEVICE}p${i}


      local cmd="tune2fs -U $uuid $fs_device"


      $cmd > /dev/null && info "UUID '$uuid' set to '$fs_device'." || { warn "Unable to set uuid '$uuid' to device '$fs_device'"; }
    fi

    i=$((i+1))
  done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
}

function set_disk_identifier() {
  local disk_id=$(get_disk_identifier "$SRC_DIR")
  (
  echo x
  echo i
  echo $disk_id
  echo r
  echo w
  ) | fdisk "$LOOP_DEVICE" > /dev/null && info "Disk identifier set to '$disk_id'." || { error "Unable to set disk identifier to '$disk_id'."; }
}


function build_image_skeleton() {
  SRC_DIR=$1
  IMAGE_FILE=$2
  OFFSET_PERCENT=10
  MINIMUM_SIZE=$((64*1024))
  FIRST_SECTOR=$3

  check_is_root
  check_requirements
  local total=$(get_total_size)

  echo "Generating $total kilo bytes image."
  generate_new_image $total

  LOOP_DEVICE=$(losetup -fP --show "$IMAGE_FILE")

  generate_partition_table
  update_partition_table_with_no_ext4_fs
  format_partitions
  write_labels
  write_uuid
  set_disk_identifier

  losetup -d "$LOOP_DEVICE"
}
