get_factorio_version() {
    local basePath=$1
    
    # Ensure a base path was provided
    if [ -z "$basePath" ]; then
        echo "Please provide the base path to the Factorio binary."
        return 1
    fi
    
    # Construct the full path to the Factorio binary
    local binary_path="$basePath/bin/x64/factorio"
    
    # Check if the binary exists at the specified path
    if [ ! -f "$binary_path" ]; then
        echo "Factorio binary not found at $binary_path."
        return 1
    fi
    
    # Run the Factorio binary with --version and capture the output
    local output=$("$binary_path" --version)
    
    # Parse the output to extract the Factorio version
    local version=$(echo "$output" | grep -oP 'Version: \K.*?(?= \()')
    
    # Output the version
    echo "$version"
}

compare_versions() {
    local baseVersion=$1
    local currentGameVersion=$2

    if [ "$(printf '%s\n' "$baseVersion" "$currentGameVersion" | sort -V | head -n1)" != "$baseVersion" ]; then
        echo true  # baseVersion is greater than currentGameVersion
    else
        echo false  # baseVersion is not greater than currentGameVersion
    fi
}

join_by_comma() {
    # Save the current IFS value.
    local oldIFS=$IFS

    # Temporarily change the IFS value to a comma.
    IFS=','

    # Use "${@}" to join the arguments into a string.
    local result="$*"

    # Restore the original IFS value.
    IFS=$oldIFS

    echo $result
}