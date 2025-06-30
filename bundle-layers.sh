#!/bin/bash
# Bundles multiple Lambda layers as ZIPs using AWS-compatible structure

set -e

# Define layers and their packages
declare -A layers
layers["opencv"]="opencv-python-headless"
layers["numpy"]="numpy"
layers["image_ocr"]="pytesseract pillow pyzbar"
layers["pymupdf"]="pymupdf"
layers["textract"]="textract"
layers["utils_web"]="beautifulsoup4 requests"

mkdir -p layers

for name in "${!layers[@]}"; do
    path="layers/$name"
    python_path="$path/python"
    zip_path="layers/$name.zip"

    echo "==== Building layer: $name ===="

    # Clean target dir first (optional, for fresh builds)
    rm -rf "$path"

    # Create target folder structure
    mkdir -p "$python_path"

    # Install dependencies
    echo "Installing: ${layers[$name]}"
    pip install --default-timeout=3000 ${layers[$name]} -t "$python_path"

    # Cleanup unnecessary files
    echo "Cleaning up .dist-info, .egg-info, tests, __pycache__..."
    find "$python_path" -type d \( \
        -name "*.dist-info" -o \
        -name "*.egg-info" -o \
        -name "tests" -o \
        -name "__pycache__" \
    \) -exec rm -rf {} + 2>/dev/null

    # Remove old zip if exists
    rm -f "$zip_path"

    # Zip the layer (must have 'python/' as root!)
    echo "Zipping to $zip_path ..."
    (cd "$path" && zip -r "../$(basename "$zip_path")" python > /dev/null)

    echo "Layer $name complete!"
    echo
done

echo "All layers built!"
