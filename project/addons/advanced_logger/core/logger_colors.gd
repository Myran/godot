@tool
class_name LoggerColors
extends RefCounted
## Centralized color definitions for the logger system using Gruvbox Material palette

# Gruvbox Material palette
const DEBUG_COLOR: Color = Color("#bdae93")     # Lighter Gray for better visibility
const INFO_COLOR: Color = Color("#7daea3")      # Blue
const WARNING_COLOR: Color = Color("#d8a657")   # Yellow
const ERROR_COLOR: Color = Color("#ea6962")     # Red
const CRITICAL_COLOR: Color = Color("#e78a4e")  # Orange
const TIMESTAMP_COLOR: Color = Color("#928374") # Gray
const TAG_COLOR: Color = Color("#a9b665")       # Green
const SUCCESS_COLOR: Color = Color("#a9b665")   # Green (same as tag)

# HTML versions for print_rich (without the # prefix)
const DEBUG_HTML: String = "bdae93"
const INFO_HTML: String = "7daea3"
const WARNING_HTML: String = "d8a657"
const ERROR_HTML: String = "ea6962"
const CRITICAL_HTML: String = "e78a4e"
const TIMESTAMP_HTML: String = "928374"
const TAG_HTML: String = "a9b665"
const SUCCESS_HTML: String = "a9b665"
