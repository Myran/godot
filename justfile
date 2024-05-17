#!/usr/bin/env just --justfile
# ^ A shebang isn't required, but allows a justfile to be executed
#   like a script, with `./justfile test`, for example.

export exec := if arch() != "aarch64" { "godot.osx.tools.64" } else { "godot.osx.tools.arm64" }
export editor_folder := "editor"
export godot_folder := "godot"
export ios_folder := "export/ios"
export arch := "arm64"
export jobs := `sysctl -n hw.logicalcpu`
export uid_iphone :="00008110-000E04D83E51801E"
export uid_ipad :="7fb6c66bb671ed19676ad6ec794ab8a2d255180c"

ip :="192.168.1.110"
port :="5555"

_default:
    @just --list --unsorted

# Start editor
edit: 
    ./$editor_folder/$exec --path project --editor

#build editor
_build_editor:
    cd $godot_folder && scons platform=osx arch=$arch --jobs=$jobs
    mv $godot_folder/bin/$exec $editor_folder/$exec
