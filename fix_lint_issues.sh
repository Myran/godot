#!/bin/bash
# Fix GDScript linting issues

cd project

echo "Fixing no-else-return violations..."

# Pattern 1: Simple else: return after if return
# From:
#   if condition:
#       return value
#   else:
#       return other_value
# To:
#   if condition:
#       return value
#   return other_value

rg -l "return.*\n.*else:" --glob '*.gd' | xargs sed -i '' -E '
/return.*/{
    N
    s/return([^\n]*)\n(\s*)else:\s*return/return\1\n\2return/
}
'

echo "Fixing no-elif-return violations..."

# Pattern 2: elif after return
# From:
#   if condition:
#       return value
#   elif other_condition:
#       return other_value
# To:
#   if condition:
#       return value
#   if other_condition:
#       return other_value

rg -l "return.*\n.*elif" --glob '*.gd' | xargs sed -i '' -E '
/return.*/{
    N
    s/return([^\n]*)\n(\s*)elif/return\1\n\2if/
}
'

echo "Done fixing return-based violations"