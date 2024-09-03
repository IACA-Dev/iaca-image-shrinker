#!/bin/bash
# ============================================
# Description: Data extractor from file script.
#
# Requirements :
#   - losetup
#
# Error : From 20 to 29
#   - 20 : Image file not found
#   - 21 : Bad Image file extension
#   - 22 : Missing requirements
#   - 23 : Missing source file
#   - 24 : Extraction issue
#   - 28 : Disposing error
# ============================================

if [ -z "$UTILS_SOURCED" ]; then
  source ./utils.sh || { echo "ERROR : utils.sh not found."; exit 23; }
fi

# ============================================

function check_requirements() {
  if ! command -v losetup &> /dev/null; then
    error "The required command 'losetup' is not installed or not found in PATH."
    exit 22
  fi
}

# ============================================

function check_image_file_exists() {
  if [ ! -f "$IMAGE_FILE" ]; then
    error "Image file '$IMAGE_FILE' not found."
    exit 20
  fi
}

# ============================================

function check_image_file_extension() {
  if [[ "${IMAGE_FILE##*.}" != "img" ]]; then
    error "The file '$IMAGE_FILE' does not have a .img extension."
    exit 21
  fi
}

# ============================================

function check_data_dir() {
  if [ ! -d "$DATA_DIR" ]; then
    error "Data directory '$DATA_DIR' doesn't exist."
    exit 22
  fi
}

# ============================================

function get_partition_names_from_device(){
    local fdisk_output="$(fdisk -l $1)"
    local partition_info="$(echo "$fdisk_output" | grep "^$1" | sed 's/\*//g')"
    echo "$partition_info" | awk '{print $1}'
}


# ============================================
# Function: get_fs_type
# Description: Determines the filesystem type of a given device.
# Parameters:
#   - device: The device whose filesystem type needs to be determined.
# Returns:
#   - The filesystem type of the device if found.
#   - Error messages and appropriate exit codes otherwise.
#     - 1 : Device not found
#     - 2 : No filesystem found
# Notes:
#   - Requires the 'lsblk' command to be available in PATH.
# ============================================
function get_device_fs_type() {
  local device=$1

  if [ ! -b "$device" ]; then
    return 1
  fi

  fs_type=$(lsblk -no FSTYPE "$device")

  if [ -z "$fs_type" ]; then
    return 2
  else
    echo "$fs_type"
    return 0
  fi
}

# ============================================

function get_device_label() {
  local device=$1

  if [ ! -b "$device" ]; then
    return 1
  fi

  echo "$(lsblk -no LABEL "$device")"
}

# ============================================

function extract_data_from_file {
  IMAGE_FILE=$1
  DATA_DIR=$2

  [ -z "$IMAGE_FILE" ] && { error "$0 <image> <data_directory>"; exit 1; }
  [ -z "$DATA_DIR" ] && { error "$0 <image> <data_directory>"; exit 1; }

  check_is_root
  check_requirements
  check_image_file_exists
  check_image_file_extension
  check_data_dir

  LOOP_DEVICE=$(losetup -fPr --show "$IMAGE_FILE")

  sleep 1

  local devices=$(get_partition_names_from_device "$LOOP_DEVICE")


  for device in $devices; do
    local device_dir=${DATA_DIR}/$(basename $device)
    mkdir "$device_dir"

    local fs_type=$(get_device_fs_type "$device")
    if [ $? -ne 0 ]; then
      error "Unable to detect filesystem type for device '$device'."
      exit 24
    fi

    local label=$(get_device_label "$device")

    local device_tmp_dir=$(mktemp -d)
    mount -o ro "$device" "$device_tmp_dir"

    local size=$(du -s $device_tmp_dir | awk '{print $1}')

    echo -e "{\"type\":\"$fs_type\",\"size\":$size,\"label\":\"$label}" > "${device_dir}/info.json"

    local src=$(pwd)
    cd "$device_tmp_dir"
    tar -czvf "${device_dir}/data.tar.gz" * > /dev/null
    cd "$src"

    umount "$device_tmp_dir"
    rm -d "$device_tmp_dir"
  done
  
  
  losetup -d "$LOOP_DEVICE" || { error "Unable to umount loop device '$LOOP_DEVICE'."; exit 28;}

}