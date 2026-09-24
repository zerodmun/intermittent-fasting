#!/bin/bash

set -e

echo "=========================================="
echo " Fomo IF - Release APK Build"
echo "=========================================="

# Pastikan script dijalankan dari root project
cd "$(dirname "$0")"

echo ""
echo "[1/3] Cleaning project..."
flutter clean

echo ""
echo "[2/3] Getting dependencies..."
flutter pub get

echo ""
echo "[3/3] Building release APK..."
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
RELEASE_DIR="app-release"
OUTPUT_PATH="$RELEASE_DIR/Fomo IF.apk"

if [ ! -f "$APK_PATH" ]; then
    echo ""
    echo "ERROR: APK tidak ditemukan:"
    echo "$APK_PATH"
    exit 1
fi

echo ""
echo "Copying APK..."

mkdir -p "$RELEASE_DIR"

rm -f "$OUTPUT_PATH"

cp "$APK_PATH" "$OUTPUT_PATH"

echo ""
echo "=========================================="
echo " BUILD SUCCESSFUL"
echo "=========================================="
echo "Release APK:"
echo "$OUTPUT_PATH"
echo "=========================================="