#!/bin/sh -x
set -e # stop script on errors
set -u # stop script on undefined var
set -o # stop script on pipe failure


# Build the binaries necessary for recent iPhone and iOS
# GODOT 4.3xx
echo "============================="
echo "BUILDING IPHONE EXECUTABLES"
echo "============================="

./build_ios_executable.sh
cd godot

echo "=========================="
echo "PREPARING IPHONE TEMPLATES"
echo "=========================="

# Change access and copy to dist folder
chmod +x bin/libgodot*
cp bin/libgodot.ios.template_release.arm64.a misc/dist/ios_xcode/libgodot.ios.release.xcframework/ios-arm64/libgodot.a
cp bin/libgodot.ios.template_debug.arm64.a misc/dist/ios_xcode/libgodot.ios.debug.xcframework/ios-arm64/libgodot.debug.a


echo "=========================="
echo "PACKAGING IPHONE TEMPLATES"
echo "=========================="

# Zip up the iPhone template
rm -fr ../templates/iphone.zip
mkdir ../templates
cd misc/dist/ios_xcode/

# Manually copy zipped template to relevant template directory for Godot exporting
zip -9 -r ../../../../templates/iphone.zip *
cd ../../../..
