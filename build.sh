#!/bin/bash

# Build script for Clipboard AI app distribution
# This script builds, archives, exports, and packages the app for distribution

set -e  # Exit on any error

# Configuration
PROJECT_NAME="clipboardapp"
SCHEME_NAME="clipboardapp"
APP_NAME="The Clipboard App"
BUNDLE_ID="us.hervalicio.theclipboardapp"
BUILD_DIR="./build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_NAME="TheClipboardApp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}📄 Loading environment variables from .env...${NC}"
    export $(grep -v '^#' .env | xargs)
fi

echo -e "${BLUE}🚀 Starting build process for $APP_NAME${NC}"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build and archive
echo -e "${YELLOW}🏗️  Building and archiving...${NC}"
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$SCHEME_NAME" \
           -configuration Release \
           -archivePath "$ARCHIVE_PATH" \
           archive

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Archive failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive completed successfully${NC}"

# Export the app
echo -e "${YELLOW}📦 Exporting app...${NC}"
xcodebuild -exportArchive \
           -archivePath "$ARCHIVE_PATH" \
           -exportPath "$EXPORT_PATH" \
           -exportOptionsPlist "./ExportOptions.plist"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Export failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Export completed successfully${NC}"

# Create zip for notarization
echo -e "${YELLOW}📦 Creating zip for notarization...${NC}"
NOTARIZATION_ZIP="$BUILD_DIR/notarization.zip"
cd "$EXPORT_PATH"
zip -r "../$(basename "$NOTARIZATION_ZIP")" "$APP_NAME.app"
cd - > /dev/null

# Notarize the app
echo -e "${YELLOW}🔐 Notarizing app (this may take a few minutes)...${NC}"
xcrun notarytool submit "$NOTARIZATION_ZIP" \
                       --keychain-profile "notarytool-password" \
                       --wait

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Notarization completed successfully${NC}"
    
    # Staple the notarization to the original app
    echo -e "${YELLOW}📎 Stapling notarization...${NC}"
    xcrun stapler staple "$EXPORT_PATH/$APP_NAME.app"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Notarization stapled successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Stapling failed, but app is still notarized${NC}"
    fi
    
    # Clean up notarization zip
    rm -f "$NOTARIZATION_ZIP"
else
    echo -e "${YELLOW}⚠️  Notarization failed or not configured. App will show security warnings.${NC}"
    echo -e "${YELLOW}   Users will need to right-click → Open to bypass Gatekeeper.${NC}"
    rm -f "$NOTARIZATION_ZIP"
fi

# Check if the app was exported
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ App not found at expected path: $APP_PATH${NC}"
    exit 1
fi

# Create DMG
echo -e "${YELLOW}💿 Creating DMG...${NC}"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"

# Create a temporary directory for DMG contents
DMG_TEMP_DIR="$BUILD_DIR/dmg_temp"
mkdir -p "$DMG_TEMP_DIR"

# Copy the app to DMG temp directory
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Create the DMG
hdiutil create -volname "$DMG_NAME" \
               -srcfolder "$DMG_TEMP_DIR" \
               -ov \
               -format UDZO \
               "$DMG_PATH"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ DMG creation failed${NC}"
    exit 1
fi

# Clean up temp directory
rm -rf "$DMG_TEMP_DIR"

echo -e "${GREEN}✅ DMG created successfully${NC}"

# Create ZIP archive as well
echo -e "${YELLOW}📁 Creating ZIP archive...${NC}"
ZIP_PATH="$BUILD_DIR/$DMG_NAME.zip"
cd "$EXPORT_PATH"
zip -r "../$(basename "$ZIP_PATH")" "$APP_NAME.app"
cd - > /dev/null

echo -e "${GREEN}✅ ZIP archive created successfully${NC}"

# Show results
echo -e "${BLUE}🎉 Build process completed successfully!${NC}"
echo -e "${GREEN}📍 Build artifacts:${NC}"
echo -e "   📱 App: $APP_PATH"
echo -e "   💿 DMG: $DMG_PATH"
echo -e "   📁 ZIP: $ZIP_PATH"

# Show file sizes
echo -e "${BLUE}📊 File sizes:${NC}"
if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo -e "   💿 DMG: $DMG_SIZE"
fi

if [ -f "$ZIP_PATH" ]; then
    ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
    echo -e "   📁 ZIP: $ZIP_SIZE"
fi

echo -e "${YELLOW}💡 Next steps:${NC}"
echo -e "   1. Test the exported app: open '$APP_PATH'"
echo -e "   2. Upload DMG or ZIP to your distribution platform"
echo -e "   3. For GitHub releases: gh release create v1.0.0 '$DMG_PATH' '$ZIP_PATH'"