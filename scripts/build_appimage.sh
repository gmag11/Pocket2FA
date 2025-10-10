#!/bin/bash

# Script to build the Pocket2FA AppImage
# Usage: ./scripts/build_appimage.sh

set -e

# Detect whether we are running in CI
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "🤖 Ejecutando en GitHub Actions"
    CI_MODE=true
else
    echo "🖥️ Ejecutando en modo local"
    CI_MODE=false
fi

# Colors for output (only in local mode)
if [ "$CI_MODE" = false ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Build start message
echo -e "${GREEN}🚀 Building Pocket2FA AppImage...${NC}"

# Get the version from pubspec.yaml
VERSION=$(grep "^version:" pubspec.yaml | cut -d' ' -f2)
echo -e "${YELLOW}📦 Versión: $VERSION${NC}"


# Detect current architecture
CURRENT_ARCH=$(uname -m)
case "$CURRENT_ARCH" in
    x86_64)
        TARGET_ARCH="x86_64"
        BUILD_DIR_ARCH="x64"
        ;;
    aarch64|arm64)
        TARGET_ARCH="arm64"
        BUILD_DIR_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}❌ Unsupported architecture: $CURRENT_ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}🔨 Building Flutter application for $TARGET_ARCH...${NC}"
flutter build linux --release

# Create directory structure for AppImage
echo -e "${YELLOW}📁 Preparing AppImage structure...${NC}"
mkdir -p build/appimage/Pocket2FA.AppDir/usr/bin
mkdir -p build/appimage/Pocket2FA.AppDir/usr/lib
mkdir -p build/appimage/Pocket2FA.AppDir/usr/share

# Copy application files
echo -e "${YELLOW}📋 Copying application files...${NC}"
cp -r build/linux/${BUILD_DIR_ARCH}/release/bundle/* build/appimage/Pocket2FA.AppDir/usr/bin/
cp -r build/linux/${BUILD_DIR_ARCH}/release/bundle/lib/* build/appimage/Pocket2FA.AppDir/usr/lib/
cp -r build/linux/${BUILD_DIR_ARCH}/release/bundle/share/* build/appimage/Pocket2FA.AppDir/usr/share/
cp -r build/linux/${BUILD_DIR_ARCH}/release/bundle/data build/appimage/Pocket2FA.AppDir/usr/bin/

# Copy icon
cp assets/icon.png build/appimage/Pocket2FA.AppDir/net.gmartin.pocket2fa.png

# Create the AppRun script if it does not exist
if [ ! -f build/appimage/Pocket2FA.AppDir/AppRun ]; then
    cat > build/appimage/Pocket2FA.AppDir/AppRun << 'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/usr/bin/Pocket2FA" "$@"
EOF
fi

# Copy the existing .desktop file and adapt it for AppImage
echo -e "${YELLOW}📋 Copying and adapting .desktop file...${NC}"
if [ -f "linux/net.gmartin.pocket2fa.desktop" ]; then
    cp linux/net.gmartin.pocket2fa.desktop build/appimage/Pocket2FA.AppDir/Pocket2FA.desktop
    # Fix .desktop file for AppImage compatibility
    # Version should be 1.0 for desktop entry specification
    sed -i "s/^Version=.*/Version=1.0/" build/appimage/Pocket2FA.AppDir/Pocket2FA.desktop
    # Ensure Security category has a main category (add System if needed)
    sed -i "s/^Categories=Utility;Security;$/Categories=Utility;System;/" build/appimage/Pocket2FA.AppDir/Pocket2FA.desktop
    echo "Using existing .desktop file from linux/ directory (adapted for AppImage)"
else
    # Fallback: create .desktop file if the original doesn't exist
    echo "Warning: linux/net.gmartin.pocket2fa.desktop not found, creating fallback"
    cat > build/appimage/Pocket2FA.AppDir/Pocket2FA.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Pocket 2FA
Comment=2FA manager based on 2FAuth web app
Exec=Pocket2FA
Icon=net.gmartin.pocket2fa
Categories=Utility;System;
Terminal=false
StartupWMClass=pocket2fa
EOF
fi

# Make necessary files executable
chmod +x build/appimage/Pocket2FA.AppDir/AppRun
chmod +x build/appimage/Pocket2FA.AppDir/usr/bin/Pocket2FA

# Download appropriate appimagetool for the current architecture
APPIMAGETOOL_ARCH=""
case "$TARGET_ARCH" in
    x86_64)
        APPIMAGETOOL_ARCH="x86_64"
        ;;
    arm64)
        APPIMAGETOOL_ARCH="aarch64"
        ;;
esac

if [ ! -f appimagetool-${APPIMAGETOOL_ARCH}.AppImage ] && [ "$USE_EXTRACTED_APPIMAGETOOL" != "true" ]; then
    echo -e "${YELLOW}⬇️  Downloading appimagetool for $APPIMAGETOOL_ARCH...${NC}"
    wget -q -O appimagetool-${APPIMAGETOOL_ARCH}.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${APPIMAGETOOL_ARCH}.AppImage
    chmod +x appimagetool-${APPIMAGETOOL_ARCH}.AppImage
elif [ "$USE_EXTRACTED_APPIMAGETOOL" = "true" ]; then
    echo -e "${YELLOW}📦 Using extracted appimagetool from system...${NC}"
fi

# Create AppImage
echo -e "${YELLOW}🏗️  Creating AppImage...${NC}"
mkdir -p build/linux/${BUILD_DIR_ARCH}/release/appimage

# Choose appimagetool command based on environment
APPIMAGETOOL_CMD=""
if [ "$USE_EXTRACTED_APPIMAGETOOL" = "true" ] && command -v appimagetool >/dev/null 2>&1; then
    APPIMAGETOOL_CMD="appimagetool"
else
    APPIMAGETOOL_CMD="./appimagetool-${APPIMAGETOOL_ARCH}.AppImage"
fi

# Suprimir warnings en CI para output más limpio
if [ "$CI_MODE" = true ]; then
    ARCH=${TARGET_ARCH} $APPIMAGETOOL_CMD build/appimage/Pocket2FA.AppDir build/linux/${BUILD_DIR_ARCH}/release/appimage/Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage 2>/dev/null || \
    ARCH=${TARGET_ARCH} $APPIMAGETOOL_CMD build/appimage/Pocket2FA.AppDir build/linux/${BUILD_DIR_ARCH}/release/appimage/Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage
else
    ARCH=${TARGET_ARCH} $APPIMAGETOOL_CMD build/appimage/Pocket2FA.AppDir build/linux/${BUILD_DIR_ARCH}/release/appimage/Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage
fi

# Generate checksum
echo -e "${YELLOW}🔐 Generating checksum...${NC}"
cd build/linux/${BUILD_DIR_ARCH}/release/appimage
sha256sum Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage > Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage.sha256
cd - > /dev/null

# Clean up temporary file
rm -f appimagetool-${APPIMAGETOOL_ARCH}.AppImage

echo -e "${GREEN}✅ AppImage successfully created: build/linux/${BUILD_DIR_ARCH}/release/appimage/Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage${NC}"
echo -e "${GREEN}📏 Size: $(du -h build/linux/${BUILD_DIR_ARCH}/release/appimage/Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage | cut -f1)${NC}"
echo -e "${GREEN}🔐 Checksum: $(cat build/linux/${BUILD_DIR_ARCH}/release/appimage/Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage.sha256 | cut -d' ' -f1)${NC}"
echo -e "${YELLOW}💡 For distribution: the file build/linux/${BUILD_DIR_ARCH}/release/appimage/Pocket2FA-$VERSION-${TARGET_ARCH}.AppImage is self-contained and portable${NC}"

