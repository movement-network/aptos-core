#!/bin/bash

# Fix Move.toml files that use external framework dependencies
# Replace external GitHub dependencies with local framework paths

echo "Fixing Move framework dependencies..."

find aptos-move/move-examples -name "Move.toml" | while read file; do
    if grep -q "github.com/aptos-labs/aptos-framework" "$file"; then
        echo "Fixing $file"

        # Calculate relative path from the Move.toml to the framework
        dir=$(dirname "$file")
        rel_path=$(realpath --relative-to="$dir" "aptos-move/framework" 2>/dev/null || python3 -c "
import os
print(os.path.relpath('aptos-move/framework', '$dir'))
")

        # Replace external framework dependencies with local ones
        sed -i.bak \
            -e "s|AptosFramework = { git = \"https://github.com/aptos-labs/aptos-framework.git\", subdir = \"aptos-framework\", rev = \"mainnet\" }|AptosFramework = { local = \"$rel_path/aptos-framework\" }|g" \
            -e "s|AptosTokenObjects = { git = \"https://github.com/aptos-labs/aptos-framework.git\", subdir = \"aptos-token-objects\", rev = \"mainnet\" }|AptosTokenObjects = { local = \"$rel_path/aptos-token-objects\" }|g" \
            -e "s|AptosStdlib = { git = \"https://github.com/aptos-labs/aptos-framework.git\", subdir = \"aptos-stdlib\", rev = \"mainnet\" }|AptosStdlib = { local = \"$rel_path/aptos-stdlib\" }|g" \
            "$file"

        # Remove backup file
        rm -f "$file.bak"
    fi
done

echo "Done fixing Move framework dependencies."