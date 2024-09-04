#!/bin/bash
# ============================================
# Description: Main script to handle shrink process.
# ============================================

# --------------------------------------------------------------------------------------------------------------------- GLOBALES VARIABLES

source ./utils.sh || { echo "ERROR : utils.sh not found."; exit 1; }
UTILS_SOURCED=1

OUTPUT_IMAGE_PATH=a.img
TARGET=

# --------------------------------------------------------------------------------------------------------------------- FUNCTIONS

function show_usage() {
    echo "$0 [-o output.img] [-t target] <image file (.img)>"
    echo -e "\n\t-o <output_image_path> :  Specify output image path (default = a.img)."
    echo -e "\n\t-t <target> :  Specify image target (e.g. \"olimex-a20\")."
    echo -e "\t-h : Show this screen.\n"
}

function check() {
  [ -z "$INPUT_IMAGE_PATH" ] && { error "Bad usage"; show_usage; exit 1; }
  [ ! -f "$INPUT_IMAGE_PATH" ] && { error "Image '$INPUT_IMAGE_PATH' not found."; show_usage; exit 1; }
}

function check_target() {
  [ ! -f "$TARGET" ] && { error "${TARGET} not found."; exit 2; }
}

function load_target() {
  source "$TARGET" || { error "$TARGET not found."; exit 1; }
}

function main() {
    TMP_DIR=$(mktemp -d)
#    echo "$TMP_DIR"

    info "=========================================================================================== 1/4 CHECKS"
    source ./check-input-image.sh || { error "check-input-image.sh not found."; exit 1; }
    check_input_image "$INPUT_IMAGE_PATH"

    info "=========================================================================================== 2/4 EXTRACTION"
    source ./data-extractor-from-file.sh || { error "data-extractor-from-file.sh not found."; exit 1; }
    extract_data_from_file "$INPUT_IMAGE_PATH" "$TMP_DIR"

    info "=========================================================================================== 3/4 SKELETON"
    source ./build-image-skeleton.sh || { error "build-image-skeleton.sh not found."; exit 1; }
    build_image_skeleton "$TMP_DIR" "$OUTPUT_IMAGE_PATH" "$FIRST_SECTOR"

    info "=========================================================================================== 4/4 INFLATING"
    source ./inflate-image-with-data.sh || { error "inflate-image-with-data.sh not found."; exit 1; }
    inflate_image_with_data "$TMP_DIR" "$OUTPUT_IMAGE_PATH"

    if [ ! -z "$TARGET" ]; then
      info "=========================================================================================== TARGET CONFIG"
      load_target
      apply_target_configuration "$OUTPUT_IMAGE_PATH"
    fi

    info "===========================================================================================\n===========================================================================================\n"
    rm -dr "$TMP_DIR"
#      echo "$TMP_DIR"

    local output_img_size=$(du "$OUTPUT_IMAGE_PATH" | awk '{print $1}')
    local input_img_size=$(du "$INPUT_IMAGE_PATH" | awk '{print $1}')
    local space_saved=$((input_img_size - output_img_size))
    local space_saved_MB=$((space_saved / 1024))
    local space_saved_GB=$((space_saved_MB / 1024))

    echo -e "\n\n\t SOURCE IMAGE SIZE: $(du -sh "$INPUT_IMAGE_PATH" | awk '{print $1}')"
    echo -e "\t OUTPUT IMAGE SIZE : $(du -sh "$OUTPUT_IMAGE_PATH" | awk '{print $1}')\n"
    echo -e "\t SPACE SAVED : $space_saved_MB MB ($space_saved_GB GB)"
    echo -e "\t SPACE SAVED RATIO : $((100 - (output_img_size * 100 / input_img_size))) %\n"
    success "Image shrinked : $OUTPUT_IMAGE_PATH"
}

# --------------------------------------------------------------------------------------------------------------------- ARGS

while getopts ":o:t:h" opt; do
    case ${opt} in
        h)
            show_usage
            exit 0
            ;;
        o)
            OUTPUT_IMAGE_PATH=$OPTARG
            ;;
        t)
            TARGET="./targets/${OPTARG}.sh"
            check_target
            load_target
            ;;
        \?)
            show_usage
            exit 1
            ;;
        :)
            echo "Option -${OPTARG} requires an argument." >&2
            show_usage
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

INPUT_IMAGE_PATH=$1

# --------------------------------------------------------------------------------------------------------------------- CHECKS

FIRST_SECTOR="${TARGET_FIRST_SECTOR:-2048}"

check

show_logo

echo -e "\n\n\t SOURCE IMAGE : $INPUT_IMAGE_PATH"
echo -e "\t OUTPUT IMAGE : $OUTPUT_IMAGE_PATH\n"

echo -e "\t FIRST SECTOR : $FIRST_SECTOR"
[ -n "$TARGET" ] && echo -e "\t TARGET       : $TARGET\n"

request_confirmation


main

# --------------------------------------------------------------------------------------------------------------------- MAIN