#!/bin/bash
# Download image from URL to /tmp directory
# Usage: download_image.sh <image_url> [output_dir]
# Output: Prints the local file path

set -e

IMAGE_URL="$1"
OUTPUT_DIR="${2:-/tmp}"

if [ -z "$IMAGE_URL" ]; then
    echo "Usage: download_image.sh <image_url> [output_dir]" >&2
    exit 1
fi

# Generate hash from URL for unique filename.
# POSIX `cksum`, not `md5sum`: md5sum does not exist on stock macOS, and because
# it sat mid-pipeline the substitution still exited 0 (the status came from
# `head`), so `set -e` never fired and every URL collapsed to `img_.png` —
# multi-image articles silently overwrote one file and reported success.
URL_HASH=$(printf '%s' "$IMAGE_URL" | cksum | cut -d' ' -f1)
if [ -z "$URL_HASH" ]; then
    echo "Error: failed to hash image URL" >&2
    exit 1
fi

# Extract extension from URL (default to png)
EXT=$(echo "$IMAGE_URL" | grep -oE '\.(png|jpg|jpeg|gif|webp|svg)' | tail -1 || echo ".png")
if [ -z "$EXT" ]; then
    EXT=".png"
fi

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Generate output filename
OUTPUT_FILE="${OUTPUT_DIR}/img_${URL_HASH}${EXT}"

# Download image
if curl -sL -o "$OUTPUT_FILE" "$IMAGE_URL"; then
    # Verify file is not empty
    if [ -s "$OUTPUT_FILE" ]; then
        echo "$OUTPUT_FILE"
        exit 0
    else
        echo "Error: Downloaded file is empty" >&2
        rm -f "$OUTPUT_FILE"
        exit 1
    fi
else
    echo "Error: Failed to download image from $IMAGE_URL" >&2
    exit 1
fi
