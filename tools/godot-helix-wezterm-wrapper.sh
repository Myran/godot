#!/usr/bin/env sh

# Enable debug mode
DEBUG=true

# Debug function
debug() {
    [ "$DEBUG" = true ] && echo "[DEBUG] $1" >&2
}

# Parse the input argument
if [ $# -eq 0 ]; then
    echo "Error: Missing input argument" >&2
    exit 1
fi

INPUT="$1"
FILE=$(echo "$INPUT" | cut -d':' -f1)
LINE=$(echo "$INPUT" | cut -d':' -f2)
COL=$(echo "$INPUT" | cut -d':' -f3)

debug "Input: $INPUT"
debug "File: $FILE"
debug "Line: $LINE"
debug "Column: $COL"

tty=$(tty)
hostname=$(hostname | tr '[:upper:]' '[:lower:]')
pwd=$(pwd)
file_path="$FILE"

debug "TTY: $tty"
debug "Hostname: $hostname"
debug "PWD: $pwd"
debug "File path: $file_path"
get_helix_pane_id() {
    wezterm_output=$(wezterm cli list)
    debug "WezTerm output: $wezterm_output"
    
    if [ -z "$wezterm_output" ]; then
        debug "WezTerm output is empty"
        return 1
    fi
    
    pane_id=$(echo "$wezterm_output" | awk '$6 == "hx" {print $3}' | head -n 1)
    
    if [ -z "$pane_id" ]; then
        debug "No Helix pane ID found"
        return 1
    fi
    
    echo "$pane_id"
    return 0
}

pane_id=$(get_helix_pane_id)

debug "Detected Helix pane ID: $pane_id"

if [ -z "$pane_id" ]; then
    debug "No existing Helix instance found, creating new one"
    wezterm cli spawn --cwd "$pwd" -- hx "$FILE:$LINE:$COL"
else
    debug "Existing Helix instance found (Pane ID: $pane_id)"
    # Enter normal mode, then command mode
    wezterm cli send-text --pane-id "$pane_id" --no-paste $'\x1b'
    #wezterm cli send-text --pane-id "$pane_id" --no-paste ":"
    # Send the open command
    wezterm cli send-text --pane-id "$pane_id" --no-paste ":open $FILE:$LINE:$COL"
    wezterm cli send-text --pane-id "$pane_id" --no-paste $'\x0d'  # Enter key
    # Send the goto line command
#    wezterm cli send-text --pane-id "$pane_id" --no-paste ":$LINE"
#   wezterm cli send-text --pane-id "$pane_id" --no-paste $'\x0d'  # Enter key
    wezterm cli activate-pane --pane-id "$pane_id"
fi
debug "Script execution completed"
