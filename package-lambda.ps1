# bundle-layers.ps1
# Bundles multiple Lambda layers as ZIPs using AWS-compatible structure

$layers = @(
    @{ Name = "opencv"; Packages = "opencv-python-headless" },
    @{ Name = "numpy"; Packages = "numpy" },
    @{ Name = "image_ocr"; Packages = "pytesseract pillow pyzbar" },
    @{ Name = "pymupdf"; Packages = "pymupdf" },
    @{ Name = "textract"; Packages = "textract" },
    @{ Name = "utils_web"; Packages = "beautifulsoup4 requests" }
)

foreach ($layer in $layers) {
    $path = "layers\$($layer.Name)"
    $pythonPath = "$path\python"
    $zipPath = "layers\$($layer.Name).zip"

    Write-Host "==== Building layer: $($layer.Name) ===="

    # Clean target dir first (optional, for fresh builds)
    if (Test-Path $path) { Remove-Item $path -Recurse -Force }

    # Create target folder structure
    New-Item -ItemType Directory -Path $pythonPath -Force | Out-Null

    # Install dependencies
    Write-Host "Installing: $($layer.Packages)"
    pip install --default-timeout=3000 $layer.Packages.Split(" ") -t $pythonPath

    # Cleanup unnecessary files
    Write-Host "Cleaning up .dist-info, .egg-info, tests, __pycache__..."
    Get-ChildItem -Path $pythonPath -Recurse -Include "*.dist-info","*.egg-info","tests","__pycache__" |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    # Remove old zip if exists
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

    # Zip the layer (must have 'python/' as root!)
    Write-Host "Zipping to $zipPath ..."
    Compress-Archive -Path "$pythonPath" -DestinationPath $zipPath

    Write-Host "Layer $($layer.Name) complete!`n"
}

Write-Host "All layers built!"
