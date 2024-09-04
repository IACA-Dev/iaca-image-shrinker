# Description: Check if input image can be process by the script
#   Checks :
#     - Have a partition table
#     - Have at least one partition
#     - Have a maximum of 4 partitions
# Requirements :
#   - fdisk
# Error : From 50 to 59
#   - 50 : Bad usage
#   - 51 : Image doesn't exists
#   - 52 : Loop error
#   - 53 : Bad image
# ============================================

if [ -z "$UTILS_SOURCED" ]; then
  source ./utils.sh || { echo "ERROR : utils.sh not found."; exit 23; }
fi

# --------------------------------------------------------------------------------------------------------------------

function _checkRequirements(){
  [ -z "$INPUT_IMAGE" ] && { error "check_input_image <input_image>"; exit 50; }
  [ ! -f "$INPUT_IMAGE" ] && { error "$INPUT_IMAGE not found."; exit 51; }
}

function _get_partition_count() {
    local partition_count=$(lsblk "$1" | tail -n +3 | wc -l)
    echo $partition_count
}

function check_input_image(){
  INPUT_IMAGE=$1
  
  _checkRequirements

  LOOP_DEVICE=$(losetup -fP --show "$INPUT_IMAGE")
  if [ $? -ne 0 ]; then
    error "Unable to load image in loop."
    exit 52
  fi
  
  local partition_count=$(_get_partition_count $LOOP_DEVICE)
  
  
  if [ "$partition_count" -lt 1 ] || [ "$partition_count" -gt 4 ]; then
    error "Partition count ($partition_count) is not within the valid range (1-4)."
    exit 53
  fi
  
  losetup -d "$LOOP_DEVICE"
}