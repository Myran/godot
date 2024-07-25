#!/bin/sh -x
set -e # stop script on errors
set -u # stop script on undefined var
set -o # stop script on pipe failure
cd godot
# Build the binaries necessary for recent iPhone and iOS


echo "============================="
echo "BUILDING IPHONE RELEASE ARM64"
echo "============================="
scons p=ios tools=no target=template_release arch=arm64 --jobs=$(sysctl -n hw.logicalcpu) module_bmp_enabled=no module_bullet_enabled=no module_csg_enabled=no module_dds_enabled=no module_enet_enabled=no module_etc_enabled=no module_gdnative_enabled=no module_gridmap_enabled=no module_hdr_enabled=no module_mbedtls_enabled=yes module_mobile_vr_enabled=no module_opus_enabled=no module_pvr_enabled=no module_recast_enabled=no module_regex_enabled=no module_squish_enabled=no module_tga_enabled=no module_thekla_unwrap_enabled=no module_theora_enabled=no module_tinyexr_enabled=no module_vorbis_enabled=no module_webm_enabled=no module_websocket_enabled=no disable_advanced_gui=no disable_3d=yes optimize=size use_lto=yes

#echo "Stripping"
#strip bin/libgodot.iphone.opt.arm64.a

echo "============================="
echo "BUILDING IPHONE DEBUG ARM64"
echo "============================="
scons p=ios tools=no target=template_debug arch=arm64 --jobs=$(sysctl -n hw.logicalcpu) 
cd ..
