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

# Generate hash from URL for unique filename
URL_HASH=$(echo -n "$IMAGE_URL" | md5sum | cut -d' ' -f1 | head -c 12)

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
